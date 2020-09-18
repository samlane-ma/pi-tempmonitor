## pi-temp-monitor

# CPU Temperature applet for Ubuntu Budgie on Raspberry Pi

# This is a Vala based rewrite of python Budgie Pi Temperature Monitor

Adds an applet to monitor the CPU temperature.
Temperature can be displayed in Celcius or Fahrenheit.

Temperature icon will be dim normally, and will brighten when temperature gets close to throttle limit.
The icon can be set to brighten from 55 to 85 degrees.
(Raspi throttles at 85 degrees.)

Popover shows the highest and lowest temperatures, and the time which they were recorded.

To install (for Debian/Ubuntu):

    mkdir build
    cd build
    meson --prefix=/usr --libdir=/usr/lib
    ninja -v
    sudo ninja install

* for other distros omit libdir or specify the location of the distro library folder

This will:
* install plugin files to the Budgie Desktop plugins folder
* copy the icons to the pixmaps folder
* compile the schema
