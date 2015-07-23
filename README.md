pimatic-lirc
=======================

This is a plugin to send and receive IR commands using the LIRC utiltiy.
The plugin needs a working installation of lirc before it can be used [raspberry pi guide](http://alexba.in/blog/2013/01/06/setting-up-lirc-on-the-raspberrypi/).

Configuration Plugin
--------------------
You can load the plugin by editing your `config.json` to include:

    {
      "plugin": "lirc"
    }

Example:
--------

    if state of sonos-connect is equal to "play" then set lirc remote: AMP command: KEY_POWER


Receiving IR commands
---------------------

If you want to be able to receive IR commands in Pimatic create an device like this:
    {
      "id": "lirc",
      "class": "LircReceiver",
      "name": "Lirc"
    }

Example:
--------

    if remote of lirc is equal to "samsung" and command of lirc is equal to "KEY_TV2" send prowl message:"TV2 on Samsung TV"
    