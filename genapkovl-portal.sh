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

CONFIGS=
tmp="$(mktemp -d)"

HOSTNAME="$1"
if [ -z "$HOSTNAME" ]; then
	echo "usage: $0 hostname"
	exit 1
fi

cleanup() {
	rm -rf "$tmp"
	}

makefile() {
	OWNER="$1"
	PERMS="$2"
	FILENAME="$3"
	cat > "$FILENAME"
	chown "$OWNER" "$FILENAME"
	chmod "$PERMS" "$FILENAME"
	}

rc_add() {
	mkdir -p "$tmp"/etc/runlevels/"$2"
	ln -sf /etc/init.d/"$1" "$tmp"/etc/runlevels/"$2"/"$1"
	}

trap cleanup EXIT

mkdir -p "$tmp"/etc
makefile root:root 0644 "$tmp"/etc/hostname <<EOF
$HOSTNAME
EOF

cat "${CONFIGS}/dnsmasq.conf" | makefile root:root 0644 "$tmp"/etc/dnsmasq.conf

cat "${CONFIGS}/firewall.nft" | makefile root:root 0644 "$tmp"/etc/firewall.nft

mkdir -p "$tmp"/etc/apk
cat "${CONFIGS}/portal-world.conf" | makefile root:root 0644 "$tmp"/etc/apk/world

mkdir -p "$tmp"/etc/conf.d
cat "${CONFIGS}/nftables.conf" | makefile root:root 0644 "$tmp"/etc/conf.d/nftables

mkdir -p "$tmp"/etc/network
cat "${CONFIGS}/interfaces.conf" | makefile root:root 0644 "$tmp"/etc/network/interfaces

mkdir -p "$tmp"/etc/sysctl.d
cat "${CONFIGS}/sysctl.conf" | makefile root:root 0644 "$tmp"/etc/sysctl.d/01-portal.conf

mkdir -p "$tmp"/etc/tor
cat "${CONFIGS}/torrc" | makefile root:root 0644 "$tmp"/etc/tor/torrc

if [ -e "${CONFIGS}/wireless.conf" ] ; then
	mkdir -p "$tmp"/etc/wpa_supplicant
	cat "${CONFIGS}/wireless.conf" | makefile root:root 0644 "$tmp"/etc/wpa_supplicant/wpa_supplicant.conf
	rc_add wpa_supplicant boot
fi

rc_add devfs sysinit
rc_add dmesg sysinit
rc_add mdev sysinit
rc_add hwdrivers sysinit
rc_add modloop sysinit

rc_add swclock boot
rc_add modules boot
rc_add sysctl boot
rc_add hostname boot
rc_add bootmisc boot
rc_add syslog boot
rc_add networking boot

rc_add nftables default
rc_add ntpd default
rc_add dnsmasq default
rc_add tor default

rc_add mount-ro shutdown
rc_add killprocs shutdown
rc_add savecache shutdown

tar -c -C "$tmp" etc | gzip -9n > $HOSTNAME.apkovl.tar.gz
