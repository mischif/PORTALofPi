#!/bin/sh

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
CROCHETCONFIG=""
KERNELCONFIG=""
WIFIDRIVER=""
MODEL=0
ARCH=""

confirm () {
################################################################################
##                                                                            ##
##                             Final confirmation                             ##
##                                                                            ##
################################################################################

if [ ${MODEL} == 1 ] ; then
	echo "Base: Raspberry Pi 1 model B/B+"
elif [ ${MODEL} == 2 ] ; then
	echo "Base: Raspberry Pi 2 model B"
fi

echo "WiFi drivers: ${WIFIDRIVER}"
read -ep "Is this correct [y/n]? " CONFIRM

if [ ${CONFIRM} == "y" -o ${CONFIRM} == "Y" ] ; then
	return 0
else
	echo "Aborting"
	return 1
fi
}

stage_0 () {
################################################################################
##                                                                            ##
##                    Which architecture should get built?                    ##
##                                                                            ##
################################################################################

echo "Supported boards:"
echo "1) Raspberry Pi 1 Model B/B+		2) Raspberry Pi 2 Model B"
while true; do
	read -ep "Build PORTALofPi for which board [1-2]? " MODEL
	case ${MODEL} in
		1 )	ARCH="armv6"
			KERNELCONFIG="RPI"
			CROCHETCONFIG="rpi.sh"
			break;;

		2 )	ARCH="armv7"
			KERNELCONFIG="RPI2"
			CROCHETCONFIG="rpi2.sh"
			break;;
		*) echo "Please choose a supported model"
	esac
done

################################################################################
##                                                                            ##
##                  Which WiFi drivers should we compile in?                  ##
##                                                                            ##
################################################################################

echo "PORTALofPi includes Realtek RTL8188CU/RTL8192CU WiFi drivers by default"
echo "(These are the drivers for the WiFi dongle in the Onion Pi)."
echo
echo "However, different ones can be included for alternate chipsets."
echo "To use the default Realtek drivers, enter nothing."
echo "Otherwise, enter the name of the alternate driver to support."
read -ep "WiFi driver [urtwn]? " WIFIDRIVER
if [ ! ${WIFIDRIVER} ] ; then
	WIFIDRIVER="urtwn"
fi

if [ ${WIFIDRIVER} != "" -a ${MODEL} != 0 ] ; then
	return 0
else
	echo "There was an issue getting the configuration"
	return 1
fi
}

################################################################################
##                                                                            ##
##            Stage 1: Collect all files necessary to build PORTAL            ##
##                                                                            ##
################################################################################
stage_1 () {

if [ -e "${PORTALDIR}/${ARCH}_stage_1_success" ] ; then return 0; fi

pkg install -y python git gmake arm-none-eabi-gcc qemu-user-static
git clone --depth 1 https://github.com/freebsd/crochet.git /root/crochet

LASTRELEASE=$(curl -s https://svnweb.freebsd.org/base/releng/ | awk -F '/' '{print $1}' | grep "^[[:digit:].]" | sort -n | tail -n 1)
git clone --depth 1 --branch "releng/${LASTRELEASE}" https://github.com/freebsd/freebsd.git /usr/src

portsnap fetch extract
make -C /usr/ports/security/tor fetch-recursive
make -C /usr/ports/dns/dnsmasq fetch-recursive
make -C /usr/ports/editors/vim-lite fetch-recursive
make -C /usr/ports/ports-mgmt/pkg fetch-recursive

if [ ${MODEL} == 1 ] ; then
	make -C /usr/ports/sysutils/u-boot-rpi install
elif [ ${MODEL} == 2 ] ; then
	make -C /usr/ports/sysutils/u-boot-rpi-2 install
fi

if [ $? == 0 ] ; then
	touch "${PORTALDIR}/${ARCH}_stage_1_success"
	return 0
else
	echo "There was an issue downloading the necessary packages"
	return 1
fi
}

################################################################################
##                                                                            ##
##                    Stage 2: Compile the cross-toolchain                    ##
##                                                                            ##
################################################################################
stage_2 () {

if [ -e "${PORTALDIR}/${ARCH}_stage_2_success" ] ; then return 0; fi

env TARGET=arm TARGET_ARCH=${ARCH} MAKEOBJDIRPREFIX=/usr/obj make -C /usr/src -j 4 toolchain

if [ $? == 0 ] ; then
	touch "${PORTALDIR}/${ARCH}_stage_2_success"
	return 0
else
	echo "There was an issue building the cross-toolchain"
	return 1
fi
}

################################################################################
##                                                                            ##
##                  Stage 3: Begin building the PORTAL image                  ##
##                                                                            ##
################################################################################
stage_3 () {

if [ -e /root/crochet/PORTAL.img ] ; then return 0; fi

# Copy things where they need to go
cp "${PORTALDIR}/kernel/${KERNELCONFIG}" /sys/arm/conf/PORTAL
cp -r "${PORTALDIR}/overlay" /root/crochet
cp "${PORTALDIR}/crochet/${CROCHETCONFIG}" /root/crochet

# Add WiFi drivers to kernel config
sed -i '' "s/driverhere/${WIFIDRIVER}/" /sys/arm/conf/PORTAL
if [ ${WIFIDRIVER} == "urtwn" ] ; then
	sed -i '' "s|WiFi d|Realtek RTL8188CU/8192CU d|" /sys/arm/conf/PORTAL
fi

# Use the magic string to make emulation work
binmiscctl add armv6 --interpreter "/usr/local/bin/qemu-arm-static" --magic "\x7f\x45\x4c\x46\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x28\x00" --mask "\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff" --size 20 --set-enabled

# Build the PORTAL
chmod +x /root/crochet/crochet.sh
/root/crochet/crochet.sh -c /root/crochet/${CROCHETCONFIG}

if [ $? == 0 ] ; then
	return 0
else
	if [ -e /root/crochet/PORTAL.img ] ; then
		rm  /root/crochet/PORTAL.img
	fi
	echo "There was an issue building the PORTAL image"
	return 1
fi

}

# Get basic details
stage_0

# Make sure we got them, then confirm them
if [ $? == 0 ] ; then
	confirm
else
	exit 1
fi

# Make sure everything was confirmed before we begin downloads
if [ $? == 0 ] ; then
	stage_1
else
	exit 1
fi

# Confirm everything downloaded correctly before building the cross-toolchain
if [ $? == 0 ] ; then
	stage_2
else
	exit 1
fi

# Confirm the cross-toolchain built right before building the PORTAL image
if [ $? == 0 ] ; then
	stage_3
else
	exit 1
fi

# Confirm the PORTAL image built correctly
if [ $? == 0 ] ; then
	exit 0
else
	exit 1
fi
