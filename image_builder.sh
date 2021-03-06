#!/usr/bin/env sh

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
TOOLS=

configure_system () {
	if [ -d "/home/build" ] ; then return 0; fi

	mount -o remount,rw ${TOOLS}
	setup-interfaces -i <<EOF
auto lo
auto eth0

iface lo inet loopback
iface eth0 inet dhcp
	hostname portalbuilder
EOF

	ifup eth0

	echo "Preparing repositories"
	cat > /etc/apk/repositories <<-EOF
		http://dl-cdn.alpinelinux.org/alpine/edge/main
		http://dl-cdn.alpinelinux.org/alpine/edge/community
		EOF

	apk -q update
	apk -q upgrade

	echo "Downloading packages"
	apk -q add alpine-sdk build-base apk-tools alpine-conf busybox fakeroot mkinitfs xorriso squashfs-tools

	echo "Preparing build user"
	adduser --disabled-password -G abuild build
	addgroup build wheel
	sed -ie 's|# %wheel ALL=(ALL) N|%wheel ALL=(ALL) N|' /etc/sudoers
	}

build_image () {
	if [ -e "${TOOLS}/alpine-portal-edge-${ARCH}.tar.gz" ] ; then return 0; fi

		if [ -d "/home/build/.abuild" ] ; then
			echo "Signing keys already created; skipping"
		else
			echo "Creating signing keys"
			su -l build -c "abuild-keygen -i -a -n"
		fi

	su -l build -c "cd ${TOOLS}/aports/scripts && BOARD=${BOARD} ./mkimage.sh \
		--arch ${ARCH} \
		--tag edge \
		--profile portal \
		--outdir ${TOOLS} \
		--repository http://dl-cdn.alpinelinux.org/alpine/edge/main \
		--extra-repository http://dl-cdn.alpinelinux.org/alpine/edge/community"

	if [ -e "${TOOLS}/alpine-portal-edge-${ARCH}.tar.gz" ] ; then
		echo "Build complete; exiting image builder"
	else
		echo "There was an issue building the image; exiting image builder"
	fi
	}

set -e
set -u

configure_system
build_image
poweroff
