#!/bin/sh
#
# Buildroot related operations...
#
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


