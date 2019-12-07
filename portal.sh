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
LOOP_MNT="${PORTALDIR}/mnt"

ARCH=""
BOARD=""
LATEST_VERSION=""
MODEL=0
QEMU_EMULATOR=""
TARBALL=""

cleanup() {
	set +e

	if [ -d ${LOOP_MNT} ] ; then
		umount -qd ${LOOP_MNT}
		rm -rf ${LOOP_MNT}
	fi

	rm -rf ${SQUASH_TMP}
	rm -rf ${INITRAM_TMP}
	rm -f "${PORTALDIR}/initramfs-vanilla-orig"
	rm -f "${PORTALDIR}/${BOARD}_stage_3_success"
	rm -f "${PORTALDIR}/${BOARD}_system.img"

	if [ -e "portal-${BOARD}.tar.gz" ] ; then
		rm -rf "${PORTALDIR}/aports"
		rm -f "${PORTALDIR}/u-boot.bin"
		rm -f "${PORTALDIR}/${TARBALL}"
		rm -f "${PORTALDIR}/${BOARD}_stage_2_success"
	fi

}

stage_0() {
################################################################################
##                                                                            ##
##                 Which board is being turned into a PORTAL?                 ##
##                                                                            ##
################################################################################

echo "Supported boards:"
echo "1) Raspberry Pi Zero W	2) Raspberry Pi 1"
echo "3) Raspberry Pi 2			4) Raspberry Pi 2 V1.2"
echo "5) Raspberry Pi 3			6) Raspberry Pi 4"
while true; do
	read -p "Build PORTALofPi for which board [1-6]? " MODEL
	case ${MODEL} in
		1 )	ARCH="armhf"
			BOARD="rpi0w"
			break
			;;

		2 )	ARCH="armhf"
			BOARD="rpi1"
			break
			;;

		3 )	ARCH="armv7"
			BOARD="rpi2"
			break
			;;

		4 )	ARCH="aarch64"
			BOARD="rpi2"
			break
			;;

		5 )	ARCH="aarch64"
			BOARD="rpi3"
			break
			;;

		6 )	ARCH="aarch64"
			BOARD="rpi4"
			break
			;;

		* ) echo "Please choose a supported model"
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

	if [ ${ARCH} == "aarch64" ] ; then
		QEMU_EMULATOR="aarch64"
	else
		QEMU_EMULATOR="arm"
	fi

	mkdir ${LOOP_MNT}

	LATEST_VERSION=$(curl -s "http://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/${ARCH}/" | sed -n "s|.*>alpine-uboot-\([0-9\.]*\)-${ARCH}.tar.gz<.*|\1|p" | sort -rn | head -n 1)
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

apk add squashfs-tools sudo util-linux coreutils qemu-img parted qemu-system-${QEMU_EMULATOR}


if [ -d "${PORTALDIR}/aports" ] ; then
	echo "aports already downloaded; skipping"
else
	echo "Downloading aports"
	git clone --depth 1 --single-branch -b master git://github.com/alpinelinux/aports "${PORTALDIR}/aports"
fi

if [ -e "${PORTALDIR}/${TARBALL}" ] ; then
	echo "Tarball already downloaded; skipping"

else
	echo "Downloading ${ARCH} tarball"
	wget -P ${PORTALDIR} "http://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/${ARCH}/${TARBALL}"
fi

if [ -e "${PORTALDIR}/u-boot.bin" ] ; then
	echo "U-Boot already extracted; skipping"
else
	if [ ${ARCH} == "aarch64" ] ; then
		local UBOOT_DIR="./u-boot/qemu_arm64"
	else
		local UBOOT_DIR="./u-boot/qemu_arm"
	fi
	
	echo "Extracting U-Boot from tarball"
	tar --strip-components=3  -C ${PORTALDIR} -xzf "${PORTALDIR}/${TARBALL}" "${UBOOT_DIR}/u-boot.bin"
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
	qemu-img create "${PORTALDIR}/${BOARD}_system.img" 384M

	echo "Partitioning ${BOARD} system image"
	parted -s "${PORTALDIR}/${BOARD}_system.img" mktable msdos
	parted -s "${PORTALDIR}/${BOARD}_system.img" unit s -- mkpart primary ext4 2048 -1

	echo "Formatting ${BOARD} system image"
	losetup -o 1048576 /dev/loop1 "${PORTALDIR}/${BOARD}_system.img"
	mkfs.ext4 -L install /dev/loop1

	echo "Preparing tarball for qemu boot"
	mount /dev/loop1 ${LOOP_MNT}
	tar -xzf "${PORTALDIR}/${TARBALL}" -C ${LOOP_MNT}

	# Extlinux fixes
	sed -ie 's|APPEND modules=.*|APPEND modules=loop,squashfs,usb-storage,ahci,sd_mod,scsi_mod,ext4,ahci console=ttyAMA0 console=tty1|' "${LOOP_MNT}/extlinux/extlinux.conf"

	# Initramfs tweaks
	cp "${LOOP_MNT}/boot/initramfs-vanilla" "${PORTALDIR}/initramfs-vanilla-orig"
	mkdir ${INITRAM_TMP}
	( cd ${INITRAM_TMP} && gunzip -c ../initramfs-vanilla-orig  | cpio -i )

	unsquashfs -d ${SQUASH_TMP} "${LOOP_MNT}/boot/modloop-vanilla"
	# Get kernel version; a bit overkill but it doesn't hurt to protect against multiple version in tarball
	local KERNEL_VERSION=$(ls -1 ${SQUASH_TMP}/modules/ | grep '^[0-9]' | sort -rn | head -n 1)

	cp ${SQUASH_TMP}/modules/${KERNEL_VERSION}/kernel/drivers/ata/ahci.ko ${INITRAM_TMP}/lib/modules/${KERNEL_VERSION}/kernel/drivers/ata/
	cp ${SQUASH_TMP}/modules/${KERNEL_VERSION}/kernel/drivers/ata/libahci* ${INITRAM_TMP}/lib/modules/${KERNEL_VERSION}/kernel/drivers/ata/

	mkdir -p ${INITRAM_TMP}/lib/modules/${KERNEL_VERSION}/kernel/drivers/char/hw_random/char/hw_random/
	cp ${SQUASH_TMP}/modules/${KERNEL_VERSION}/kernel/drivers/char/hw_random/rng-core.ko ${INITRAM_TMP}/lib/modules/${KERNEL_VERSION}/kernel/drivers/char/hw_random/
	cp ${SQUASH_TMP}/modules/${KERNEL_VERSION}/kernel/drivers/char/hw_random/virtio-rng.ko ${INITRAM_TMP}/lib/modules/${KERNEL_VERSION}/kernel/drivers/char/hw_random/

	depmod -b ${INITRAM_TMP} -F ${SQUASH_TMP}/modules/${KERNEL_VERSION}/modules.symbols ${KERNEL_VERSION}
	( cd ${INITRAM_TMP} && find . | cpio -H newc -o | gzip -9 > ../mnt/boot/initramfs-vanilla )

	echo "Copying tools to ${BOARD} system image"
	cp -r "${PORTALDIR}/configs" ${LOOP_MNT}
	cp -r "${PORTALDIR}/aports" ${LOOP_MNT}
	cp "${PORTALDIR}/mkimg.portal.sh" "${LOOP_MNT}/aports/scripts"
	cp "${PORTALDIR}/genapkovl-portal.sh" "${LOOP_MNT}/aports/scripts"
	cat "${PORTALDIR}/image_builder.sh" | sed -e "s|^ARCH=|ARCH=${ARCH}|" | sed -e "s|^BOARD=|BOARD=${BOARD}|" > "${LOOP_MNT}/image_builder.sh"

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

local MACH_CPU=""

if [ ${ARCH} == "aarch64" ] ; then
	MACH_CPU="cortex-a72"
else
	MACH_CPU="cortex-a15"
fi

echo "Booting image builder"

qemu-system-${QEMU_EMULATOR} \
	-nographic \
	-machine virt \
	-cpu ${MACH_CPU} \
	-machine accel=tcg \
	-m 2048 \
	-bios "${PORTALDIR}/u-boot.bin" \
	-rtc base=utc,clock=host \
	-drive if=none,file="${PORTALDIR}/${BOARD}_system.img",id=inst-disk \
	-device ich9-ahci,id=ahci \
	-device ide-drive,drive=inst-disk,bus=ahci.0

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
