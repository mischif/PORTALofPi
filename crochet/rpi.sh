################################################################################
##                     ___  ___  ___ _____ _   _                              ##
##                    | _ \/ _ \| _ \_   _/_\ | | of ._ o                     ##
##                    |  _/ (_) |   / | |/ _ \| |__  |_)|                     ##
##                    |_|  \___/|_|_\ |_/_/ \_\____| |                        ##
##                                                                            ##
##                       Original Concept by: the grugq                       ##
##                         Implementation by: Mischif                         ##
##                                                                            ##
##               Raspberry Pi 1 Model B/B+ Crochet Build Script               ##
################################################################################

board_setup RaspberryPi

KERNCONF=PORTAL

RPI_GPU_MEM=16

option ImageSize 500mb

IMG=${TOPDIR}/PORTAL.img

#option AutoSize

option User portal

customize_freebsd_partition ( ) {
	NEWROOT=$(pwd)

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
	chroot . service ldconfig start

	echo "Installing pkg"
	env PATH=/usr/obj/arm.armv6/usr/src/tmp/bin:${PATH} make -C /usr/ports/ports-mgmt/pkg DESTDIR=${NEWROOT} install clean

	echo "Installing Tor"
	time -a -o ${TOPDIR}/tor_install_native.log env PATH=/usr/obj/arm.armv6/usr/src/tmp/usr/bin:${PATH} make -j 4 -C /usr/ports/security/tor DESTDIR=${NEWROOT} install | tee ${TOPDIR}/tor_install_native.log

	make -C /usr/ports/security/tor DESTDIR=${NEWROOT} clean

	echo "Installing dnsmasq"
	time -a -o ${TOPDIR}/dnsmasq_install_native.log env PATH=/usr/obj/arm.armv6/usr/src/tmp/usr/bin:${PATH} make -C /usr/ports/dns/dnsmasq DESTDIR=${NEWROOT} install | tee ${TOPDIR}/dnsmasq_install_native.log

	make -C /usr/ports/dns/dnsmasq DESTDIR=${NEWROOT} clean

	echo "Installing vim"
	time -a -o ${TOPDIR}/vim_install_native.log env PATH=/usr/obj/arm.armv6/usr/src/tmp/usr/bin:${PATH} make -C /usr/ports/editors/vim-lite DESTDIR=${NEWROOT} install | tee ${TOPDIR}/vim_install_native.log

	make -C /usr/ports/editors/vim-lite DESTDIR=${NEWROOT} clean

	echo "Cleanup: removing build dependencies"
	chroot . pkg autoremove --yes --quiet

	echo "Cleanup: removing emulator"
	rm ./usr/local/bin/qemu-arm-static

	echo "Cleanup: removing ports configs"
	rm -r ./var/db/ports/*

	echo "Cleanup: removing native toolchain support"
	rm ./usr/obj/arm.armv6/usr/src/tmp/usr/include
	umount ./usr/obj
}
