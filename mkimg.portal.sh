portal_gen_cmdline() {
	echo "modules=loop,squashfs,sd-mod,usb-storage quiet ${kernel_cmdline}"
}

portal_gen_config() {

	case "${BOARD}" in
	RPI3 )
		cat <<-RPI3
			arm_control=0x200
			RPI3
		;;

	RPI4 )
		cat <<-RPI4
			arm_64bit=1
			enable_gic=1
			RPI4
		;;
		
	* )
		pass
		;;
	esac

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

	aarch64 )
		cat <<-AARCH64
			initramfs boot/initramfs-rpi
			kernel=boot/vmlinuz-rpi
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
	arch="aarch64 armhf armv7"
	hostname="portal"
	image_ext="iso"
	initfs_features="base squashfs mmc usb kms dhcp https"
	kernel_cmdline="console=ttyAMA0,115200"
	case "$ARCH" in
		armhf) kernel_flavors="rpi";;
		armv7) kernel_flavors="rpi2";;
		aarch64) kernel_flavors="rpi";;
	esac
	grub_mod=
}
