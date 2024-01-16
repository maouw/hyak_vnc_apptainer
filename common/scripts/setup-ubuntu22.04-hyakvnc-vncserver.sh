#! /bin/sh

# This script is designed to be sourced by other scripts, not run directly.
export DEBIAN_FRONTEND=noninteractive

# Don't generate these locales:
mkdir -p /var/lib/locales/supported.d
for localename in fr de zh-hant ja es it zh-hans pt ru ar; do
	touch "/var/lib/locales/supported.d/${localename}" && chmod a-r "/var/lib/locales/supported.d/${localename}"
done

# Limit the English locales to en_US.UTF-8:
echo "en_US.UTF-8 UTF-8" >/var/lib/locales/supported.d/en && chmod a-r /var/lib/locales/supported.d/en

apt-get install -yq locales
locale-gen en_US.UTF-8
update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 LC_COLLATE=C

# Set the locale environment variables permanently:
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"
export LC_COLLATE="C"

# Install basic packages:
apt-get install -yq --no-install-recommends \
	bash-completion \
	bc \
	binutils \
	bzip2 \
	curl \
	dash \
	ed \
	file \
	git \
	less \
	make \
	nano \
	netcat-openbsd \
	openssh-client \
	patch \
	procps \
	psmisc \
	python3 \
	rsync \
	unzip \
	vim-tiny \
	xz-utils \
	zip

# Stop apt from installing audio packages (they don't work on VNC):
apt-mark hold xfce4-pulseaudio-plugin pavucontrol pulseaudio pipewire pipewire-bin pipewire-pulse

# Install XFCE and some apps:
apt-get install -yq --no-install-recommends \
	dbus-x11 \
	elementary-xfce-icon-theme \
	fonts-dejavu-core \
	fonts-ubuntu \
	gettext \
	libfile-mimeinfo-perl \
	libnet-dbus-perl \
	libnotify-bin \
	libx11-protocol-perl \
	libxfce4ui-utils \
	mousepad \
	ristretto \
	thunar \
	thunar-archive-plugin \
	thunar-volman \
	x11-utils \
	x11-xserver-utils \
	xauth \
	xclip \
	xdg-user-dirs \
	xdg-utils \
	xfce4-appfinder \
	xfce4-datetime-plugin \
	xfce4-indicator-plugin \
	xfce4-notifyd \
	xfce4-panel \
	xfce4-session \
	xfce4-settings \
	xfce4-taskmanager \
	xfce4-terminal \
	xfce4-whiskermenu-plugin \
	xfconf \
	xfdesktop4 \
	xfonts-base \
	xfwm4 \
	xterm

# Set xfce4-terminal as default terminal emulator:
update-alternatives --set x-terminal-emulator /usr/bin/xfce4-terminal.wrapper

# Install TurboVNC:
/opt/setup/scripts/install-turbovnc.sh || { echo "warning: install-turbovnc.sh failed!" >&2; exit 1; }
echo "PATH=/opt/TurboVNC/bin:\${PATH}" >>"/.singularity.d/env/100-turbovnc.sh"

# shellcheck disable=SC2016
echo '$vncUserDir = "$ENV{VNC_USER_DIR}";' >>/etc/turbovncserver.conf

cp /opt/setup/scripts/hyakvnc-vncserver.sh /usr/local/bin/hyakvnc-vncserver && chmod a+x /usr/local/bin/hyakvnc-vncserver

# Copy configs:
( cd /opt/setup/configs/ubuntu && cp -rd --parents etc /etc && cp -rd --parents usr /usr ) || { echo "warning: copying configs failed!" >&2; exit 1; }

