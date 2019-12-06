#!/usr/bin/env -S sh -eu

ARCH=
BOARD=

configure_system () {
	if [ -d "/home/build" ] ; then return 0; fi

	mount -o remount,rw /media/sda1
	setup-interfaces
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

build_iso () {
if [ -e "/media/sda1/alpine-portal-edge-${ARCH}.iso" ] ; then return 0; fi

	if [ -d "/home/build/.abuild" ] ; then
		echo "Signing keys already created; skipping"
	else
		echo "Creating signing keys"
		su -l build -c "abuild-keygen -i -a -n"
	fi

su -l build -c "cd /media/sda1/aports/scripts && BOARD=${BOARD} ./mkimage.sh \
	--tag edge \
	--profile portal \
	--outdir /media/sda1 \
	--repository http://dl-cdn.alpinelinux.org/alpine/edge/main \
	--extra-repository http://dl-cdn.alpinelinux.org/alpine/edge/community"

if [ -e "/media/sda1/alpine-portal-edge-${ARCH}.iso" ] ; then
	echo "Build complete"
else
	echo "There was an issue building the image"
fi
}

configure_system
build_iso
poweroff