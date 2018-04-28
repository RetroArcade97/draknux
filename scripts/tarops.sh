#!/bin/sh
#
# TAR manipulation functions
#

# - edit tar image
edit_tar() {
  local ifile="$1" ofile="$2"
  tmp_tar="$(mktemp -d -p "$(cd "$(dirname "$ifile")" && pwd)")"
  cleanup_tar_edit() {
    [ -z "${tmp_tar:-}" ] && return
    rm -rf "$tmp_tar"
  }
  (
    echo set -x
    dst="$tmp_tar" ; declare -p dst
    file="$(readlink -f "$ofile")" ; declare -p file
    ifile="$(readlink -f "$ifile")" ; declare -p ifile
    
    echo 'tar -C "$dst" -xf "$ifile"'
    cat
    echo 'tar -C "$dst" -cf "$file" $(cd "$dst" && find . -maxdepth 1 -mindepth 1 -printf "%P\n")'
  ) | fakeroot
  rm -rf "$tmp_tar"
  unset tmp_tar
}

g_unpack() {
  root=""
  if [ x"$1" == x"--root" ] ; then
    root=root
    shift
  fi
  local chdir="$1" archive="$2" ; shift 2

  [ ! -f "$archive" ] && return 1
  local srcfile="$(readlink -f "$archive")"
  if grep -E -q '\.zip$' <<<"$srcfile" ; then
    # This is a zip file...
    (
      cd "$chdir" || return 2
      $root unzip -q "$srcfile"
    )
  elif grep -E -q '\.tar\.gz$' ; then
    $root tar -C "$chdir" "$@" -zxf "$srcfile"
  elif grep -E -q '\.tar$' ; then
    $root tar -C "$chdir" "$@" -xf "$srcfile"
  else
    die 5 "Invalid file extension $archive"
  fi
}

    

#~ edit_tar "$@" <<_EOF_
#~ mkdir "\$dst"/mnt/{ext_sd,game,int_sd}
#~ _EOF_
