#!/bin/sh
#
# Create sdcard image
#
if [ $# -eq 0 ] ; then
  echo "Usage: $0 [options] /dev/disk"
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

tag=""
reserved=8192

default_part() {
  local i
  local v="$1" ; shift
  eval p${v}_fs= p${v}_size= p${v}_label= p${v}_src=
  for i in fs size label src
  do
    [ $# -eq 0 ] && return ; eval p${v}_${i}='"$1"' ; shift
  done
}
opts_part() {
  local v=${1#--p} ; v=$(expr substr "$v" 1 1)
  case "$1" in
  --p?_fs=*)
    eval p${v}_fs='${1#--p?_fs=}'
    ;;
  --p?_size=*)
    eval p${v}_size='${1#--p?_size=}'
    ;;
  --p?_src=*)
    eval p${v}_src='${1#--p?_src=}'
    ;;
  --p?_label=*)
    eval p${v}_label='${1#--p?_label=}'
    ;;
  *)
    return 1
    ;;
  esac
  return 0
}
parttype() {
  case "$1" in
  ext3)
    echo "L"
    ;;
  swap)
    echo "S"
    ;;
  vfat)
    echo "b"
    ;;
  esac
}

default_part 1 ext3 256000 rootfs 
default_part 2 swap 256000
default_part 3 vfat 256000 game
default_part 4 vfat 2097152 roms


while [ "$#" -gt 0 ]
do
  case "$1" in
  --tag=*)
    tag=${1#--tag=}
    ;;
  --reserve=*)
    reserved=${1#--reserve=}
    ;;
  --p?_*)
    opts_part "$1" || break
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

disc="$1"
if [ -b "$disc" ] ; then
  dosu true
  disc_size=$(dosu sfdisk -s "$disc")

  [ -z "$disc_size" ] && die 2 "$disc: Unknown size"
  info "$disc: $disc_size blocks"
  if [ $disc_size -lt $(expr $reserved + $p1_size + $p2_size + $p3_size + $p4_size) ] ; then
    die 4 "$disc is too small!"
  fi
  echo "ALL DATA WILL BE ERASED ON THE FOLLOWING DISK"
  dosu sfdisk -u B -l "$disc"
  read -p "Press ENTER to continue: " wait

  dosu dd if=/dev/zero of="$disc" bs=512 count=2
  dosu=dosu
  force=""
elif [ -e "$disc" ] ; then
  die 4 "$disc: Already exists"
else
  disc_size=$(expr $reserved + $p1_size + $p2_size + $p3_size + $p4_size + 1)
  truncate -s "${disc_size}K" "$disc"
  dosu=""
  force="--force"
fi

$dosu sfdisk $force -u B "$disc" <<-EOF
	$reserved,$p1_size,$(parttype $p1_fs)
	$(expr $reserved + $p1_size),$p2_size,$(parttype $p2_fs)
	$(expr $reserved + $p1_size + $p2_size),$p3_size,$(parttype $p3_fs)
	$(expr $reserved + $p1_size + $p2_size + $p3_size),,$(parttype $p4_fs)
	EOF

maploopdev() {
  local v
  for v in $(seq 1 4)
  do
    eval p${v}_part=/dev/mapper/\$$v
  done
}

# Re-read partition table
if [ -b "$disc" ] ; then
  dosu kpartx "$disc"
  for v in $(seq 1 4)
  do
    eval p${v}_part='${disc}'$v
  done
else
  dosu true
  mountdevs=$(dosu kpartx -v -a "$disc" | awk '$1 == "add" && $2 == "map" { print $3}')
  [ -z "$mountdevs" ] && die 4 "Unable to map loop device"
  maploopdev $mountdevs
  trap "dosu kpartx -v -d $disc ; dosu_cleanup" EXIT
fi

genfs=$(cd "$(dirname $0)" && pwd)/genfs
for v in $(seq 1 4)
do
  eval '$genfs --label="$p'$v'_label$tag" --type="$p'$v'_fs" --src="$p'$v'_src" --no-prompt "$p'$v'_part"'
done
