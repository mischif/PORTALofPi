```
  ___  ___  ___ _____ _   _
 | _ \/ _ \| _ \_   _/_\ | | of ._ o  
 |  _/ (_) |   / | |/ _ \| |__  |_)|  
 |_|  \___/|_|_\ |_/_/ \_\____| |
```

PORTAL of Pi - Raspberry Pi-based isolating Tor proxy

Credits
=======

Inspiration: the grugq
Implementation: Mischif

Overview
=========

PORTAL - Personal Onion Router To Avoid LEO

From the [original post](https://grugq.github.io/blog/2013/10/05/thru-a-portal-darkly/) on the concept, a PORTAL should:

> [...] create a compartmented network segment that can *only* send data to the Tor network. To accomplish this the PORTAL
> device itself is physically isolated and locked down to prevent malicious tampering originating from the protected network.
> So if the user’s computer is compromised by malware, the malware is unable to modify the Tor software or configuration,
> nor can it directly access the Internet (completely preventing IP address leakage).
> Additionally, the PORTAL is configured to fail close – if the connection to Tor drops, the user loses their Internet access.
> Finally, the PORTAL is "idiot proof", simply turn it on and it works.

The purpose of the PORTAL of Pi project is to create a PORTAL from a Raspberry Pi.

Architecture
============

Again, from the original post:

> The PORTAL requires a minimum of two network interfaces: one for the Internet uplink, and one for the isolated network segment.
> In order to protect the PORTAL from tampering from malware (or malicious users), it also requires a third administration interface.
> This can be either a serial console, or physical connection.

The architecture of the PORTAL of Pi is as follows:

```
                                ____________
                                |          |
((Internet))-------[WiFi]-------|  PORTAL  |-------[Ethernet]-------((Client Computer))
                                |__________|                                ^
                                     |                                      |
                                     |____________[TTL Serial]______________|
```

WAN:
* Exposed to the Internet
* Uses WiFi, either built-in on Pi 3+/0W boards or using a dongle on Pi 1/2 boards
* No exposed services

LAN:
* Exposed to the client computer
* Uses Ethernet, either using a dongle on Pi 0W boards or built-in on all other boards
* SOCKS proxy at port 9150
* DNS server at port 53
* DHCP server on port 137

Administration:
* Exposed to the client computer or some other airgapped computer
* Uses Pi serial console, only connected to another computer during active administration
* Requires USB/TTL cable, [purchased separately](https://www.adafruit.com/product/954)

Build Steps
===========

While every attempt was made to automate the PORTAL build process, there is an unfortunate amount of necessary prep work.

* These steps assume you will be using VirtualBox as your hypervisor; substituting another hypervisor is allowed, but not tested.
* These steps assume you downloaded the project zip; cloning the project makes no difference.
* These steps assume you have a folder on your host at \~/portal where this project is stored.

1. Add the networks you will want the PORTAL to connect to in WPA supplicant format to \~/portal/wireless.conf
2. Set up a new VM guest (Other Linux, 64-bit) with a 2G hard drive and at least 2G RAM
3. Create a shared folder named portal mapping to \~/portal on your host
4. [Download a copy](https://alpinelinux.org/downloads/) of the virtual build of Alpine
5. Insert the Alpine ISO into your guest and boot
6. Run `setup-alpine` and make a sys install to disk (root password doesn't matter as this VM is meant to be disposable)
7. Power down the guest, remove the Alpine ISO and reboot
8. Create the directory /media/portal and edit the file /etc/apk/repositories so only the edge repositories are uncommented
9. Run `apk update && apk upgrade && apk add virtualbox-guest-additions virtualbox-guest-modules-virt` and reboot
10. Mount the shared folder with `mount -t vboxsf portal /media/portal`
11. Extract the project using `unzip /media/portal/PORTALofPi-master.zip -d ~`
12. Copy the wireless config into place with `cp /media/portal/wireless.conf PORTALofPi-master/configs/`
13. Start the build process with `sh PORTALofPi-master/portal.sh`
14. After about 10 minutes you will boot to another console; log in as root and run `/media/sda1/image_builder.sh` if building an aarch64 image, `/media/mmcblk0p1/image_builder.sh` otherwise
15. If all goes well, no further interaction is necessary; after about 30 minutes you should be automatically returned to your original console with portal-${BOARD_NAME}.tar.gz in your home directory
16. Move the tarball to your host with `mv portal-${BOARD_NAME}.tar.gz /media/portal`
17. Extract the tarball onto a MicroSD card and you should be good to go

Drawbacks
=========
* This PORTAL currently does not handle captive portals; if using a hotspot like your phone or [the ones provided by the Calyx institute](https://www.calyxinstitute.org/member/wireless-data-equipment) is untenable, the current best workaround is to use macchanger to associate to the base station before using the PORTAL of Pi

User Notes
==========
* The root user on the PORTAL of Pi has no password; you may wish to rectify this before becoming operational (don't forget to [commit your changes](https://wiki.alpinelinux.org/wiki/Alpine_local_backup#Committing_your_changes))
* DNS requests made for example.com are not routed through Tor; this is for planned captive portal support in the future
* DNS requests made for pool.ntp.org are not routed through Tor; this is because the current time is necessary for Tor certificates to be accepted
* As the admin interface is meant to be connected for active administration only, you should minimize the amount of time spent connected to it, ideally to just enough to confirm everything is functional

Stay safe out there.
