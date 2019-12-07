################################################################################
##                     ___  ___  ___ _____ _   _                              ##
##                    | _ \/ _ \| _ \_   _/_\ | | of ._ o                     ##
##                    |  _/ (_) |   / | |/ _ \| |__  |_)|                     ##
##                    |_|  \___/|_|_\ |_/_/ \_\____| |                        ##
##                                                                            ##
##                       Original Concept by: the grugq                       ##
##                         Implementation by: Mischif                         ##
################################################################################

portal_gen_cmdline() {
	echo "modules=loop,squashfs,sd-mod,usb-storage quiet ${kernel_cmdline}"
}

portal_gen_config() {
	case "${ARCH}" in
	armhf )
		cat <<-ARMHF
			initramfs boot/initramfs-rpi
			kernel=boot/vmlinuz-rpi
			include usercfg.txt
			ARMHF
		;;

	armv7 )
		cat <<-ARMV7
			initramfs boot/initramfs-rpi2
			kernel=boot/vmlinuz-rpi2
			include usercfg.txt
			ARMV7
		;;

	# Using RPi4 initramfs/kernel for all boards b/c nftables kernel
	# modules are solely missing from aarch64 package of linux-rpi;
	# they're available in armhf/armv7 versions of package, as well
	# as aarch64 package of linux-rpi4
	aarch64 )
		if [ ${BOARD} == "rpi2" -o ${BOARD} == "rpi3" ] ; then
			cat <<-RPI23
				arm_control=0x200
				RPI23
		else
			cat <<-RPI4
				arm_64bit=1
				enable_gic=1
				RPI4
		fi

		cat <<-AARCH64
			initramfs boot/initramfs-rpi4
			kernel=boot/vmlinuz-rpi4
			include usercfg.txt
			AARCH64
		;;
	esac
}

portal_gen_usercfg() {
	cat <<-USERCFG
		dtoverlay=disable-bt
		dtparam=audio=off
		gpu_mem=16
		USERCFG
}

build_portal_config() {
	portal_gen_cmdline > "${DESTDIR}"/cmdline.txt
	portal_gen_config > "${DESTDIR}"/config.txt
	portal_gen_usercfg > "${DESTDIR}"/usercfg.txt
}

build_portal_blobs() {
	apk fetch --quiet --stdout raspberrypi-bootloader | tar -C "${DESTDIR}" -zx --strip=1 boot/
}

section_portal_config() {
	build_section portal_config $( (portal_gen_cmdline ; portal_gen_config ; portal_gen_usercfg) | checksum )
	build_section portal_blobs
}

profile_portal() {
	profile_base
	title="PORTALofPi"
	desc="Raspberry Pi-based Tor isolating proxy"
	apkovl="genapkovl-portal.sh"
	apks="${apks} dnsmasq nftables tor tor-openrc wpa_supplicant"
	hostname="portal"
	image_ext="tar.gz"
	initfs_features="base squashfs mmc usb kms dhcp https"
	kernel_cmdline="console=ttyAMA0,115200"
	case "${ARCH}" in
	armhf )
		arch="armhf"
		kernel_flavors="rpi"
		;;

	armv7 )
		arch="armv7"
		kernel_flavors="rpi2"
		;;

	aarch64 )
		arch="aarch64"
		kernel_flavors="rpi4"
		;;
	esac
	unset grub_mod
}
