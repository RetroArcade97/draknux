# Draknux

A remix of OpenDingux for the RS-97

# TODO

- try [dmenu](https://github.com/JackD83/dmenu)
- Integrate https://github.com/RetroArcade97/rs97extloader.git
- Event manager
  - Integrate [sdlfix](https://github.com/JackD83/sdlfix_rs-97)
    - show status: MHz Power
  - Hack https://github.com/RetroArcade97/evtest
  - test if we can detect "FG" process by checking who has opened
    /dev/fb0
  - ev:
    - double-click power: home
    - hold-power 3 seconds: power event 1 : shutdown
    - power+backlight : reboot
    - single-click : (down+<short delay>+up+no event after 2 seconds) power event 2 : suspend
    - backlight : down+<short delay>+up : switch backlight
    - backlight + left : clock down
    - backlight + right : clock up
- build int sdcard image
- build target sdcard image
  - autoexec.sh : boot vfat on ext-sd
  - installer.dge : Menu to select install option
  - blobs/
     - root.dat
     - swap.dat
     - gamemenu.dat
  - installer/
     - scripts to install extloader
     - scripts to install to int-sd/vfat
  - sd_data
     - p4 data
- boot scenarios:
  - vfat on ext-sd (using extloader)
  - vfat on int-sd (multiboot support)
  - int-sd image replacement
  - Just run it

