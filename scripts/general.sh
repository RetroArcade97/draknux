#!/bin/sh
#
# Generic functions...
#
set -euf -o pipefail

die() {
  local rc="$1" ; shift
  echo "$@" 1>&2
  exit $rc
}

info() {
  echo "$@"
}

warn() {
  echo "$@" 1>&2
}

trap "do_cleanup" EXIT
do_cleanup() {
  for f in $(declare -F | grep '^declare -f cleanup_' | sed 's/^declare -f //'|sort)
  do
    $f
  done
}


root() {
  if [ -z "${bgsudo:-}" ] ; then
    sudo true
    ( while : ; do sudo true ; sleep 30 ; done) &
    bgsudo=$!
    cleanup_root() {
      [ -z "${bgsudo:-}" ] && return
      kill $bgsudo
    }
  fi
  sudo "$@"
}
