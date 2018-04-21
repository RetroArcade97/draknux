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
mydir=$(dirname "$(readlink -f "$0")")
. "$mydir/scripts/general.sh"

main() {
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
  cksubmodules
  op="$1" ; shift
  op_"$op" "$@"
}

cksubmodules() {
  # Check if submodules are all there...
  grep -E '^\s*path\s*=\s*' "$mydir"/.gitmodules | sed 's/^\s*path\s*=\s*//' | while read subpath
  do
    if [ ! -e "$mydir/$subpath/.git" ] ; then
      (cd "$mydir" && git submodule update --init --recursive)
      return
    fi
  done
}

# Define commands...
. "$mydir/scripts/buildroot.sh"
. "$mydir/scripts/genfs.sh"

main "$@"

