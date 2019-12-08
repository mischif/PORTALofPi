#!/usr/bin/env -S sh -eu

################################################################################
##                     ___  ___  ___ _____ _   _                              ##
##                    | _ \/ _ \| _ \_   _/_\ | | of ._ o                     ##
##                    |  _/ (_) |   / | |/ _ \| |__  |_)|                     ##
##                    |_|  \___/|_|_\ |_/_/ \_\____| |                        ##
##                                                                            ##
##                       Original Concept by: the grugq                       ##
##                         Implementation by: Mischif                         ##
################################################################################

ARCH=
BOARD=

configure_system () {
	if [ -d "/home/build" ] ; then return 0; fi

	mount -o remount,rw /media/sda1
	chmod +x /media/sda1/*.sh

	setup-interfaces -i <<EOF
auto lo
auto eth0

iface lo inet loopback
iface eth0 inet dhcp
	hostname portalbuilder
EOF

	ifup eth0

	echo "Preparing repositories"
	cat > /etc/apk/repositories <<EOF
http://dl-cdn.alpinelinux.org/alpine/edge/main
http://dl-cdn.alpinelinux.org/alpine/edge/community
EOF

	apk update
	apk upgrade

	echo "Downloading packages"
	apk add alpine-sdk build-base apk-tools alpine-conf busybox fakeroot mkinitfs xorriso squashfs-tools

	echo "Preparing build user"
	adduser --disabled-password -G abuild build
	addgroup build wheel
	sed -ie 's|# %wheel ALL=(ALL) N|%wheel ALL=(ALL) N|' /etc/sudoers
}

build_image () {
if [ -e "/media/sda1/alpine-portal-edge-${ARCH}.tar.gz" ] ; then return 0; fi

	if [ -d "/home/build/.abuild" ] ; then
		echo "Signing keys already created; skipping"
	else
		echo "Creating signing keys"
		su -l build -c "abuild-keygen -i -a -n"
	fi

su -l build -c "cd /media/sda1/aports/scripts && BOARD=${BOARD} ./mkimage.sh \
	--arch ${ARCH} \
	--tag edge \
	--profile portal \
	--outdir /media/sda1 \
	--repository http://dl-cdn.alpinelinux.org/alpine/edge/main \
	--extra-repository http://dl-cdn.alpinelinux.org/alpine/edge/community"

if [ -e "/media/sda1/alpine-portal-edge-${ARCH}.tar.gz" ] ; then
	echo "Build complete; exiting image builder"
else
	echo "There was an issue building the image; exiting image builder"
fi
}

configure_system
build_image
poweroff
