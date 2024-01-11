#! /bin/sh
set -ex

export DEBIAN_FRONTEND=noninteractive
# Don't generate these locales"
mkdir -p /var/lib/locales/supported.d
for localename in fr de zh-hant ja es it zh-hans pt ru ar; do
	touch "/var/lib/locales/supported.d/${localename}" && chmod a-r "/var/lib/locales/supported.d/${localename}"
done

# Limit the English locales to en_US.UTF-8:
echo "en_US.UTF-8 UTF-8" >/var/lib/locales/supported.d/en && chmod a-r /var/lib/locales/supported.d/en

# Generate the locales
apt-get install -y locales
localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.utf8

# Set the locale environment variables permanently:
export LANG="${LANG:-en_US.utf8}" && echo "LANG=\"${LANG}\"" >>/etc/environment
export LC_ALL="${LANG:-en_US.utf8}" && echo "LC_ALL=\"${LC_ALL}\"" >>/etc/environment
export LC_COLLATE="${LC_COLLATE:-C}" && echo "LC_COLLATE=\"${LC_COLLATE}\"" >>/etc/environment

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
