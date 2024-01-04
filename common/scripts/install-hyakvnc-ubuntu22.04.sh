#! /bin/sh
set -x
export DEBIAN_FRONTEND=noninteractive
# Don't generate these locales"
mkdir -p /var/lib/locales/supported.d
for localename in fr de zh-hant ja es it zh-hans pt ru ar; do
	touch "/var/lib/locales/supported.d/${localename}" && chmod a-r "/var/lib/locales/supported.d/${localename}"
done

# Limit the English locales to en_US.UTF-8:
echo "en_US.UTF-8 UTF-8" > /var/lib/locales/supported.d/en && chmod a-r /var/lib/locales/supported.d/en

# Generate the locales
apt-get install -y locales
localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.utf8

# Set the locale environment variables permanently:
export LANG=en_US.utf8 && echo "LANG=\"${LANG}\"" >>/etc/environment
export LC_ALL=en_US.utf8 && echo "LC_ALL=\"${LC_ALL}\"" >>/etc/environment
export LC_COLLATE=C && echo "LC_COLLATE=\"${LC_COLLATE}\"" >>/etc/environment

# Stop apt from installing audio packages (they don't work on VNC):
apt-mark hold xfce4-pulseaudio-plugin pavucontrol pulseaudio pipewire pipewire-bin pipewire-pulse

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

# Install XFCE and some apps:
apt-get install -yq --no-install-recommends \
	at-spi2-core \
	dbus-x11 \
	elementary-xfce-icon-theme \
	fonts-dejavu-core \
	fonts-ubuntu \
	gettext \
	greybird-gtk-theme \
	libfile-mimeinfo-perl \
	libnet-dbus-perl \
	libnotify-bin \
	libx11-protocol-perl \
	libxfce4ui-utils \
	mousepad \
	novnc \
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
	xfce4-notes-plugin \
	xfce4-notifyd \
	xfce4-panel \
	xfce4-screenshooter \
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
# shellcheck disable=SC2016
echo '$vncUserDir = "$ENV{VNC_USER_DIR}";' >>/etc/turbovncserver.conf

cp /opt/setup/scripts/hyakvnc-vncserver.sh /usr/local/bin/hyakvnc-vncserver && chmod a+x /usr/local/bin/hyakvnc-vncserver

# Copy configs:
rsync -avi --no-p --no-g --chmod=ugo=rwX /opt/setup/configs/ubuntu/ / || { echo "warning: rsync failed!" >&2; exit 1; }
