#!/bin/sh
#
# Generate a filesytem image
#
if [ $# -eq 0 ] ; then
  echo "Usage: $0 [--label=genfs --type=ext3 --size=256000 --src= --no-prompt] target"
  exit 1
fi
set -euf -o pipefail

die() {
  local rc="$1" ; shift
  [ "$#" -gt 0 ] && echo "$@" 1>&2
  exit $rc
}

info() {
  echo "$@"
}
warn() {
  echo "$@" 1>&2
}

label="genfs"
size="256000"
src=""
fstype="ext3"
prompt=:

while [ "$#" -gt 0 ]
do
  case "$1" in
  --label=*)
    label=${1#--label=}
    ;;
  --type=*)
    fstype=${1#--type=}
    ;;
  --size=*)
    size=${1#--size=}
    ;;
  --src=*)
    src=${1#--src=}
    ;;
  --no-prompt)
    prompt=false
    ;;
  *)
    break
    ;;
  esac
  shift
done


bgsudo=""
dosu() {
  if [ -z "$bgsudo" ] ; then
    sudo true
    ( set +x ; while : ; do sudo true ; sleep 30 ; done) &
    bgsudo=$!
    trap dosu_cleanup EXIT
  fi
  sudo "$@"
}
dosu_cleanup() {
  [ -z "$bgsudo" ] && return
  kill $bgsudo
}

part="$1"
if [ -b "$part" ] ; then
  echo "All data on $part will be erased!!!"
  $prompt && read -p "Press ENTER to continue: " wait
elif [ -e "$part" ] ; then
  die 1 "$part: already exists"
fi


setup_mntdir() {
  mntdir=$(mktemp -d -p "$(cd "$(dirname "$src")" && pwd)")
  trap "dosu umount $mntdir ; rmdir $mntdir ; dosu_cleanup" EXIT
  dosu mount "$part" "$mntdir"
}
setup_srcdir() {
  srcdir=$(mktemp -d -p "$(cd "$(dirname "$src")" && pwd)")
  trap "rm -rf $srcdir ; dosu_cleanup" EXIT
}
gene2fs() {
  local part="$1" src="$2"
  find "$src" -printf '%y %U %G %n %i %P\n' | (while read Y U G N I P
  do
    [ -z "$P" ] && continue
    case "$Y" in
    d)
      echo "mkdir \"/$P\""
      ;;
    f)
      if [ $N -gt 1 ] ; then
	# OK, this file has hardlinks...
	local inf=$(eval echo \${inode_${N}:-})
	if [ -n "$inf" ] ; then
	  # Already exists... hard link it...
	  echo "ln \"$inf\" \"$P\""
	  continue
	else
	  eval inode_${N}=\"\$P\"
	fi
      fi
      if [ "$(dirname "$P")" = "." ] ; then
	echo "write \"$src/$P\" \"$P\""
      else
	echo "cd \"/$(dirname $P)\""
	echo "write \"$src/$P\" \"$(basename "$P")\""
	echo "cd /"
      fi
      ;;
    l)
      echo "symlink \"/$P\" \"$(readlink "$src/$P")\""
      continue
      ;;
    c|b|p)
      if [ "$Y" = p ] ; then
	local nodopts="p"
      else
	local nodopts="$Y $(stat -c '0x%t 0x%T' "$src/$P")"
      fi
      if [ "$(dirname "$P")" = "." ] ; then
	echo "mknod \"$P\" $nodopts"
      else
	echo "cd \"/$(dirname $P)\""
	echo "mknod \"$(basename "$P")\" $nodopts"
	echo "cd /"
      fi
      ;;
    *)
      warn "$P: Ignoring, type $Y"
      continue
    esac
    # Change attributes
    echo "set_inode_field \"/$P\" mode 0$(printf "%o" 0x$(stat -c '%f' "$src/$P"))"
    echo "set_inode_field \"/$P\" uid $U"
    echo "set_inode_field \"/$P\" gid $G"
    local mtime=$(date -r "$src/$P" +%Y%m%d%H%M%S)
    for a in atime mtime ctime
    do
      echo "set_inode_field \"/$P\" $a $mtime"
    done    
  done) | debugfs -w "$part" >/dev/null #> $part.log
}

case "$fstype" in
ext3)
  if [ -b "$part" ] ; then
    dosu mkfs -t ext3 -L "$label" -m0 "$part"
    [ -z "$src" ] && exit
    setup_mntdir
    if [ -f "$src" ] ; then
      info "Unpacking: $src"
      dosu tar -C "$mntdir" -xf "$src"
    elif [ -d "$src" ] ; then
      info "Copying: $src"
      dosu cp -a "$src/." "$mntdir"
    else
      die 7 "$src: Invalid type"
    fi
  else
    truncate -s "${size}K" "$part"
    mkfs -t ext3 -L "$label" -m0 -F "$part"
    [ -z "$src" ] && exit

    if [ -f "$src" ] ; then
      setup_srcdir
      fakeroot <<-EOF
	$(declare -f gene2fs)
	tar -C "$srcdir" -xf "$src"
	gene2fs "$part" "$srcdir"
	EOF
    elif [ -d "$src" ] ; then
      gene2fs "$part" "$src"
    else
      die 7 "$src: Invalid type"
    fi
  fi
  ;;
vfat)
  if [ -b "$part" ] ; then
    dosu mkfs -t vfat -n "$label" "$part"
  else
    truncate -s "${size}K" "$part"
    mkfs -t vfat -n "$label" "$part"
  fi
  [ -z "$src" ] && exit
  if [ -b "$part" ] ; then
    setup_mntdir
    if [ -f "$src" ] ; then
      info "Unpacking: $src"
      dosu tar -C "$mntdir" --no-same-owner --no-same-permissions -xf "$src"
    elif [ -d "$src" ] ; then
      info "Copying: $src"
      dosu cp -r --preserve=timestamps "$src/." "$mntdir"
    else
      die 7 "$src: Invalid type"
    fi
  else
    if [ -f "$src" ] ; then
      setup_srcdir
      fakeroot -- tar -C "$srcdir" -xf "$src"
    elif [ ! -d "$src" ] ; then
      die 7 "$src: Invalid type"
    fi
    find "$src" -printf '%P\n' | while read F
    do
      [ -z "$F" ] && continue
      if [ -d "$src/$F" ] ; then
	mmd -i "$part" "$F"
      elif [ -f "$src/$F" ] ; then
	mcopy -i "$part" "$src/$F" ::"$F"
      else
	warn "$F: skipped"
      fi
    done
  fi
  ;;
swap)
  if [ -b "$part" ] ; then
    dosu mkswap "$part"
  else
    truncate -s "${size}K" "$part"
    mkswap "$part"
  fi
  exit 0
  ;;
*)
  die 5 "Invalide fstype: $fstype"
esac




