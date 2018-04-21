#!/bin/sh
#
# 	Main driver to deal with build operations...
#
if [ x"$1" = x"-s" ] ; then
  shift
  exec script -c "$0 $*" typescript.$(date +%F.%H.%M.%S)
elif [ x"$1" = x"-x" ] ; then
  shift
  set -x
fi

set -euf -o pipefail
die() {
  local rc="$1" ; shift
  echo "$@" 1>&2
  exit $rc
}

main() {
  mydir=$(dirname "$(readlink -f "$0")")
  if [ $# -eq 0 ] ; then
    echo "Usage: $0 [-s] [-x] <op> ...options..."
    echo "Available op's:"
    #declare -F | grep  '^declare -f op_' | sed 's/declare -f op_/	/'
    for op in $(declare -F | grep  '^declare -f op_' | sed 's/^declare -f op_//')
    do
      echo "- $op"
      if type hlp_$op >/dev/null 2>&1 ; then
	hlp_$op
      fi
    done
    exit
  fi
  op="$1" ; shift
  op_"$op" "$@"
}

hlp_buildroot() {
  echo "  Invoke buildroot make operations"
  echo "  Usage: $0 buildroot <make options>"
}
op_buildroot() {
  make -C "$mydir/buildroot" O="$mydir/br-output" BR2_EXTERNAL="$mydir" "$@"
}

hlp_brcfg() {
  echo "  Configure buildroot environment"
  echo "  Usage: $0 brcfg"
}
op_brcfg() {
  op_buildroot rs97_defconfig
}

main "$@"

