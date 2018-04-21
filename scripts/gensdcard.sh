#!/bin/sh
#
# Create sdcard image
#
hlp_gensdcard() {
  echo "  Generate a sdcard"
  echo "  Usage: $0 gensdcard [--label=genfs --type=ext3 --size=256000 --src= --no-prompt] target"
}

maploopdev() {
  local v
  for v in $(seq 1 4)
  do
    eval p${v}_part=/dev/mapper/\$$v
  done
}

default_part() {
  local i
  local v="$1" ; shift
  eval p${v}_fs= p${v}_size= p${v}_label= p${v}_src=
  for i in fs size label src
  do
    if [ $# -eq 0 ] ; then
      eval p${v}_${i}='"$1"' ; shift
    else
      eval p${v}_${i}='""'
    fi
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

op_gensdcard() {
  tag=""
  reserved=8192

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

  disc="$1"
  if [ -b "$disc" ] ; then
    root true
    disc_size=$(root sfdisk -s "$disc")

    [ -z "$disc_size" ] && die 2 "$disc: Unknown size"
    info "$disc: $disc_size blocks"
    if [ $disc_size -lt $(expr $reserved + $p1_size + $p2_size + $p3_size + $p4_size) ] ; then
      die 4 "$disc is too small!"
    fi
    echo "ALL DATA WILL BE ERASED ON THE FOLLOWING DISK"
    root sfdisk -u B -l "$disc"
    read -p "Press ENTER to continue: " wait

    root dd if=/dev/zero of="$disc" bs=512 count=2
  elif [ -e "$disc" ] ; then
    die 4 "$disc: Already exists"
  else
    disc_size=$(expr $reserved + $p1_size + $p2_size + $p3_size + $p4_size + 1)
    truncate -s "${disc_size}K" "$disc"
  fi

  $([ -b "$disc" ] && echo root) sfdisk $([ -b "$disc" ] && --force) -u B "$disc" <<-EOF
	$reserved,$p1_size,$(parttype $p1_fs)
	$(expr $reserved + $p1_size),$p2_size,$(parttype $p2_fs)
	$(expr $reserved + $p1_size + $p2_size),$p3_size,$(parttype $p3_fs)
	$(expr $reserved + $p1_size + $p2_size + $p3_size),,$(parttype $p4_fs)
	EOF


  # Re-read partition table
  if [ -b "$disc" ] ; then
    root kpartx "$disc"
    for v in $(seq 1 4)
    do
      eval p${v}_part='${disc}'$v
    done
  else
    root true
    mountdevs=$(root kpartx -v -a "$disc" | awk '$1 == "add" && $2 == "map" { print $3}')
    [ -z "$mountdevs" ] && die 4 "Unable to map loop device"
    maploopdev $mountdevs
    cleanup_kpartx() {
      sudo kpartx -v -d "$disc"
    }
  fi

  for v in $(seq 1 4)
  do
    [ -z "$(eval echo \${p${v}_type})" ] && continue
    eval 'op_genfs --label="$p'$v'_label$tag" --type="$p'$v'_fs" --src="$p'$v'_src" --no-prompt "$p'$v'_part"'
  done
}
