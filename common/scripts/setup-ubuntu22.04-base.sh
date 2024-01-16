#! /bin/sh

# This script is designed to be sourced by other scripts, not run directly.

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
