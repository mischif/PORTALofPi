# REQUIRED: 
# Uncomment one to choose the default configuration for your board.
#
# THIS MUST BE THE FIRST LINE IN YOUR CONFIG.SH FILE!
#
# Don't see your board here?  board/NewBoardExample has details for
# how to add a new board definition.  If you need help, ask.  If you
# get it working, please consider contributing it.
#
# Read board/<board-name>/README for more details
# about configuring for your particular board.

board_setup RaspberryPi

RPI_GPU_MEM=16

# Size of the disk image that will be built.  This is usually the same
# size as your memory card or disk drive, but it can be smaller.
# Each board setup above defines a default value, but it's deliberately
# chosen to be very small.

option ImageSize 400mb

# "AutoSize" adds a startup item that will use "growfs" to grow the
# UFS partition as large as it can.  This can be used to construct
# small (e.g., 1GB) images that can be copied onto larger (e.g., 32GB)
# media.  At boot, such images will automatically resize to fully
# utilize the larger media.  This should be considered experimental:
# FreeBSD's resize logic sometimes doesn't take effect until after a
# couple of extra reboots, which can make this occasionally perplexing
# to use.

#option AutoSize

# Create a user account with the specified username.
# Password will be the same as the user name.
#
#option User portal

# Each board picks a default KERNCONF but you can override it.
#
KERNCONF=PORTAL

# The name of the final disk image.
# This file will be as large as IMAGE_SIZE above, so make
# sure it's located somewhere with enough space.
#
IMG=${WORKDIR}/PORTAL.img

# Runs after FreeBSD partition is built and populated.
# The current working directory is at the root of the mounted
# freebsd partition.
customize_freebsd_partition ( ) {
	NEWROOT=`pwd`

	echo "Copying armv6 emulator to image"
	mkdir -p ./usr/local/bin
	cp /usr/local/bin/qemu-arm-static ./usr/local/bin/

	echo "Setting up native toolchain support"
	if [ -d /usr/obj/arm.armv6/usr/src/tmp/usr/include ]; then
		rm -r /usr/obj/arm.armv6/usr/src/tmp/usr/include
		fi

	mount -t nullfs /usr/obj/ ./usr/obj/
	chroot . ln -s /usr/include /usr/obj/arm.armv6/usr/src/tmp/usr/include

	echo "Making final tweaks"
	cp /etc/resolv.conf ./etc/resolv.conf
	chroot . service ldconfig start

	echo "Installing Tor"
	time -a -o ${TOPDIR}/tor_install_native.log env PATH=/usr/obj/arm.armv6/usr/src/tmp/usr/bin:${PATH} make -C /usr/ports/security/tor-devel DESTDIR=${NEWROOT} install | tee ${TOPDIR}/tor_install_native.log

	make -C /usr/ports/security/tor-devel DESTDIR=${NEWROOT} clean

	echo "Installing DHCP 4.3"
	time -a -o ${TOPDIR}/dhcp43_install_native.log env PATH=/usr/obj/arm.armv6/usr/src/tmp/usr/bin:${PATH} make -C /usr/ports/net/isc-dhcp43-server DESTDIR=${NEWROOT} install | tee ${TOPDIR}/dhcp43_install_native.log

	make -C /usr/ports/net/isc-dhcp43-server DESTDIR=${NEWROOT} clean

	echo "Installing vim"
	time -a -o ${TOPDIR}/vim_install_native.log env PATH=/usr/obj/arm.armv6/usr/src/tmp/usr/bin:${PATH} make -C /usr/ports/editors/vim-lite DESTDIR=${NEWROOT} install | tee ${TOPDIR}/vim_install_native.log

	make -C /usr/ports/editors/vim-lite DESTDIR=${NEWROOT} clean

	echo "Removing emulator"
	rm ./usr/local/bin/qemu-arm-static

	echo "Removing ports configs"
	rm -r ./var/db/ports/*

	echo "Removing native toolchain support"
	rm ./usr/obj/arm.armv6/usr/src/tmp/usr/include
	umount ./usr/obj

	echo "Cleaning up other odds/ends"
	rm ./etc/resolv.conf
}
