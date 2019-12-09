#!/usr/bin/env -S sh -eu

# Major thanks to Milan for the initial steps to build the emulator
# http://arvanta.net/mps/install-aarch64-under-qemu.txt

if [ $(whoami) != "root" ] ; then
	echo "You must be root to run this script"
	exit 1
fi

clear
echo '
################################################################################
##                     ___  ___  ___ _____ _   _                              ##
##                    | _ \/ _ \| _ \_   _/_\ | | of ._ o                     ##
##                    |  _/ (_) |   / | |/ _ \| |__  |_)|                     ##
##                    |_|  \___/|_|_\ |_/_/ \_\____| |                        ##
##                                                                            ##
##                       Original Concept by: the grugq                       ##
##                         Implementation by: Mischif                         ##
################################################################################
'
PORTALDIR="$( cd "$( dirname "$0" )" && pwd)"
INITRAM_TMP="${PORTALDIR}/initramfs-tmp"
SQUASH_TMP="${PORTALDIR}/squashfs-root"
BOOT_FILES="${PORTALDIR}/boot"
LOOP_MNT="${PORTALDIR}/mnt"

ARCH=""
BOARD=""
LATEST_VERSION=""
MODEL=0
IMAGE_TOOLS=""
TARBALL=""

cleanup() {
	set +e

	if [ -d ${LOOP_MNT} ] ; then
		umount -qd ${LOOP_MNT}
		rm -rf ${LOOP_MNT}
	fi

	rm -rf ${SQUASH_TMP}
	rm -rf ${BOOT_FILES}
	rm -rf ${INITRAM_TMP}
	rm -f "${PORTALDIR}/initramfs-vanilla-orig"
	rm -f "${PORTALDIR}/${BOARD}_stage_3_success"
	rm -f "${PORTALDIR}/${BOARD}_system.img"

	if [ -e "portal-${BOARD}.tar.gz" ] ; then
		rm -rf "${PORTALDIR}/aports"
		rm -f "${PORTALDIR}/u-boot-${ARCH}.bin"
		rm -f "${PORTALDIR}/${TARBALL}"
		rm -f "${PORTALDIR}/${BOARD}_stage_2_success"
	fi

	exit
	}

stage_0() {
################################################################################
##                                                                            ##
##                 Which board is being turned into a PORTAL?                 ##
##                                                                            ##
################################################################################

	echo "Supported boards:"
	echo "1) Raspberry Pi Zero W	2) Raspberry Pi 1"
	echo "3) Raspberry Pi 2		4) Raspberry Pi 2 V1.2"
	echo "5) Raspberry Pi 3		6) Raspberry Pi 4"
	while true; do
		read -p "Build PORTALofPi for which board [1-6]? " MODEL
		case ${MODEL} in
			1 )
				ARCH="armhf"
				BOARD="rpi0w"
				break
				;;

			2 )
				ARCH="armhf"
				BOARD="rpi1"
				break
				;;

			3 )
				ARCH="armv7"
				BOARD="rpi2"
				break
				;;

			4 )
				ARCH="aarch64"
				BOARD="rpi2"
				break
				;;

			5 )
				ARCH="aarch64"
				BOARD="rpi3"
				break
				;;

			6 )
				ARCH="aarch64"
				BOARD="rpi4"
				break
				;;

			* )
				echo "Please choose a supported model"
				;;
		esac
	done

	if [ ${ARCH} != "" -a ${BOARD} != "" ] ; then
		return 0
	else
		echo "There was an issue getting the configuration"
		return 1
	fi
	}

stage_1() {
################################################################################
##                                                                            ##
##                           Set assorted constants                           ##
##                                                                            ##
################################################################################

	mkdir ${LOOP_MNT}

	LATEST_VERSION=$(wget -q -O - "http://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/${ARCH}/" | sed -n "s|.*>alpine-uboot-\([0-9\.]*\)-${ARCH}.tar.gz<.*|\1|p" | sort -rn | head -n 1)
	TARBALL="alpine-uboot-${LATEST_VERSION}-${ARCH}.tar.gz"

	if [ -d ${LOOP_MNT} -a ${LATEST_VERSION} != "" ] ; then
		return 0
	else
		echo "There was an issue setting constants"
		return 1
	fi
	}

stage_2() {
################################################################################
##                                                                            ##
##                Collect files and tools to run image builder                ##
##                                                                            ##
################################################################################

	if [ -e "${PORTALDIR}/${BOARD}_stage_2_success" ] ; then return 0; fi

	echo "Installing image builder packages"
	apk -q add squashfs-tools git util-linux coreutils qemu-img parted qemu-system-aarch64


	if [ -d "${PORTALDIR}/aports" ] ; then
		echo "aports already downloaded; skipping"
	else
		echo "Downloading aports"
		git clone -q --depth 1 --single-branch -b master git://github.com/alpinelinux/aports "${PORTALDIR}/aports"
	fi

	if [ -e "${PORTALDIR}/${TARBALL}" ] ; then
		echo "Tarball already downloaded; skipping"

	else
		echo "Downloading ${ARCH} tarball"
		wget -P ${PORTALDIR} "http://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/${ARCH}/${TARBALL}"
	fi

	if [ -e "${PORTALDIR}/u-boot-${ARCH}.bin" ] ; then
		echo "U-Boot already extracted; skipping"
	else
		if [ ${ARCH} == "aarch64" ] ; then
			local UBOOT_DIR="./u-boot/qemu_arm64"
		else
			local UBOOT_DIR="./u-boot/qemu_arm"
		fi

		echo "Extracting U-Boot from tarball"
		tar --strip-components=3  -C ${PORTALDIR} -xzf "${PORTALDIR}/${TARBALL}" "${UBOOT_DIR}/u-boot.bin"
		mv "${PORTALDIR}/u-boot.bin" "${PORTALDIR}/u-boot-${ARCH}.bin"
	fi

	if [ $? == 0 ] ; then
		touch "${PORTALDIR}/${BOARD}_stage_2_success"
		return 0
	else
		echo "There was an issue downloading the necessary packages"
		return 1
	fi
	}

stage_3() {
################################################################################
##                                                                            ##
##                       Create image for image builder                       ##
##                                                                            ##
################################################################################

	if [ -e "${PORTALDIR}/${BOARD}_stage_3_success" ] ; then return 0; fi

	if [ -e "${PORTALDIR}/${BOARD}_system.img" ] ; then
		echo "${BOARD} system image already exists; skipping"
	else
		echo "Creating ${BOARD} system image"
		qemu-img create -q "${PORTALDIR}/${BOARD}_system.img" 384M

		echo "Partitioning ${BOARD} system image"
		parted -s "${PORTALDIR}/${BOARD}_system.img" mktable msdos
		parted -s "${PORTALDIR}/${BOARD}_system.img" unit s -- mkpart primary ext4 2048 -1

		echo "Formatting ${BOARD} system image"
		losetup -o 1048576 /dev/loop1 "${PORTALDIR}/${BOARD}_system.img"
		mkfs.ext4 -L install /dev/loop1

		echo "Preparing tarball for qemu boot"
		mount /dev/loop1 ${LOOP_MNT}
		tar -xzf "${PORTALDIR}/${TARBALL}" -C ${LOOP_MNT}
		local IMAGE_TOOLS=""

		if [ ${ARCH} == "aarch64" ] ; then
			IMAGE_TOOLS="/media/sda1"
			local BOOT_MODULES="loop,squashfs,usb-storage,ahci,sd_mod,scsi_mod,ext4,ahci"
			sed -ie "s|APPEND modules=.*|APPEND modules=${BOOT_MODULES} console=ttyAMA0 console=tty1|" "${LOOP_MNT}/extlinux/extlinux.conf"

			# Initramfs tweaks
			cp "${LOOP_MNT}/boot/initramfs-vanilla" "${PORTALDIR}/initramfs-vanilla-orig"
			mkdir ${INITRAM_TMP}
			( cd ${INITRAM_TMP} && gunzip -c ../initramfs-vanilla-orig  | cpio -i )

			unsquashfs -q -d ${SQUASH_TMP} "${LOOP_MNT}/boot/modloop-vanilla"
			# Get kernel version; a bit overkill but it doesn't hurt to protect against multiple version in tarball
			local KERNEL_VERSION=$(ls -1 ${SQUASH_TMP}/modules/ | grep '^[0-9]' | sort -rn | head -n 1)
			local SQUASH_DRIVERS="${SQUASH_TMP}/modules/${KERNEL_VERSION}/kernel/drivers"
			local INITRD_DRIVERS="${INITRAM_TMP}/lib/modules/${KERNEL_VERSION}/kernel/drivers"

			cp ${SQUASH_DRIVERS}/ata/ahci.ko "${INITRD_DRIVERS}/ata/"
			cp ${SQUASH_DRIVERS}/ata/libahci* "${INITRD_DRIVERS}/ata/"

			depmod -b ${INITRAM_TMP} -F ${SQUASH_TMP}/modules/${KERNEL_VERSION}/modules.symbols ${KERNEL_VERSION}
			( cd ${INITRAM_TMP} && find . | cpio -H newc -o | gzip -9 > ../mnt/boot/initramfs-vanilla )
		else
			IMAGE_TOOLS="/media/mmcblk0p1"
			mkdir ${BOOT_FILES}
			cp "${LOOP_MNT}/boot/initramfs-vanilla" ${BOOT_FILES}
			cp "${LOOP_MNT}/boot/vmlinuz-vanilla" ${BOOT_FILES}
			cp "${LOOP_MNT}/boot/dtbs/vexpress-v2p-ca15-tc1.dtb" ${BOOT_FILES}
		fi

		echo "Copying tools to ${BOARD} system image"
		cp -r "${PORTALDIR}/configs" ${LOOP_MNT}
		cp -r "${PORTALDIR}/aports" ${LOOP_MNT}
		cp "${PORTALDIR}/mkimg.portal.sh" "${LOOP_MNT}/aports/scripts"

		cat "${PORTALDIR}/genapkovl-portal.sh" \
			| sed -e "s|^CONFIGS=|CONFIGS=\"${IMAGE_TOOLS}/configs\"|" \
			> "${LOOP_MNT}/aports/scripts/genapkovl-portal.sh"

		cat "${PORTALDIR}/image_builder.sh" \
			| sed -e "s|^ARCH=|ARCH=${ARCH}|" \
			| sed -e "s|^BOARD=|BOARD=${BOARD}|" \
			| sed -e "s|^TOOLS=|TOOLS=\"${IMAGE_TOOLS}\"|" \
			> "${LOOP_MNT}/image_builder.sh"

		chmod 755 ${LOOP_MNT}/aports/scripts/*.sh
		chmod 755 "${LOOP_MNT}/image_builder.sh"

		# Clean up
		sync
		umount -d ${LOOP_MNT}
	fi

	if [ $? == 0 ] ; then
		touch "${PORTALDIR}/${BOARD}_stage_3_success"
		return 0
	else
		echo "There was an issue building the cross-toolchain"
		return 1
	fi
	}

stage_4() {
################################################################################
##                                                                            ##
##            Boot image builder and collect finished PORTAL image            ##
##                                                                            ##
################################################################################

	if [ -e "portal-${BOARD}.tar.gz" ] ; then return 0; fi

	echo "Booting image builder"

	if [ ${ARCH} == "aarch64" ] ; then
		qemu-system-aarch64 \
			-nographic \
			-machine virt \
			-cpu cortex-a72 \
			-machine accel=tcg \
			-m 2048 \
			-bios "${PORTALDIR}/u-boot-${ARCH}.bin" \
			-rtc base=utc,clock=host \
			-drive if=none,file="${PORTALDIR}/${BOARD}_system.img",id=inst-disk,format=raw \
			-device ich9-ahci,id=ahci \
			-device ide-drive,drive=inst-disk,bus=ahci.0
	else
		qemu-system-aarch64 \
			-nographic \
			-machine vexpress-a15 \
			-cpu cortex-a15 \
			-m 2048 \
			-kernel "${BOOT_FILES}/vmlinuz-vanilla" \
			-initrd "${BOOT_FILES}/initramfs-vanilla" \
			-dtb "${BOOT_FILES}/vexpress-v2p-ca15-tc1.dtb" \
			-rtc base=utc,clock=host \
			-drive if=sd,file="${PORTALDIR}/${BOARD}_system.img",id=work-disk,format=raw \
			-netdev user,id=mynet \
			-device virtio-net-device,netdev=mynet \
			-append 'console=ttyAMA0'
	fi

	echo "Retrieving image"
	losetup -o 1048576 /dev/loop1 "${PORTALDIR}/${BOARD}_system.img"
	mount /dev/loop1 ${LOOP_MNT}

	if [ -e "${LOOP_MNT}/alpine-portal-edge-${ARCH}.tar.gz" ] ; then
		cp "${LOOP_MNT}/alpine-portal-edge-${ARCH}.tar.gz" "portal-${BOARD}.tar.gz"
	fi

	if [ -e "portal-${BOARD}.tar.gz" ] ; then
		echo "Done"
		return 0
	else
		echo "There was an issue building the PORTAL image"
		return 1
	fi
	}


# The script should clean up after itself
trap cleanup 1 SIGINT SIGTERM EXIT

# Get basic details
stage_0

# Set additional constants based on basic details
if [ $? == 0 ] ; then
	stage_1
else
	exit
fi

# Download everything outside the image builder
if [ $? == 0 ] ; then
	stage_2
else
	exit
fi

# Prep the image builder image
if [ $? == 0 ] ; then
	stage_3
else
	exit
fi

# Boot the image builder and build the PORTAL image
if [ $? == 0 ] ; then
	stage_4
else
	exit
fi

# Confirm the PORTAL image built correctly
if [ $? == 0 ] ; then
	exit 0
else
	exit 1
fi
