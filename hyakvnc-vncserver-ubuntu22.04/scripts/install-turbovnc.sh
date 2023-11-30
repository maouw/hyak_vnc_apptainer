#!/bin/sh
# Install TurboVNC:

TURBOVNC_VERSION=${TURBOVNC_VERSION:-3.1}
TURBOVNC_FILES_ROOT="${TURBOVNC_FILES_ROOT:-}"
TURBOVNC_DOWNLOAD_ROOT="${TURBOVNC_DOWNLOAD_ROOT:-https://sourceforge.net/projects/turbovnc/files}"
TURBOVNC_DOWNLOAD_URL="${TURBOVNC_DOWNLOAD_URL:-}"

if [ "${TURBOVNC_VERSION}" = "3.1" ] && [ -z "${TURBOVNC_FILES_ROOT:-}" ]; then
	TURBOVNC_FILES_ROOT="3.1"
fi

if ! command -v curl >/dev/null 2>&1; then
	echo "warning: curl not found!" >&2
	exit 1
fi

# url-encode the files root:
files_root_enc=$(echo "${TURBOVNC_FILES_ROOT}" | curl -Gs -w '%{url_effective}' --data-urlencode @- ./ | sed "s/%0[aA]$//;s/^[^?]*?\(.*\)/\1/;s/[+]/%20/g")

if [ -z "${TURBOVNC_DOWNLOAD_URL:-}" ]; then
	if command -v dpkg >/dev/null 2>&1; then
		# Is Debian/Ubuntu. Package filename looks like turbovnc_3.0.91_arm64.deb
		arch="$(dpkg --print-architecture)"
		filename="turbovnc_${TURBOVNC_VERSION}_${arch}.deb"
	elif command -v yum >/dev/null 2>&1; then
		# Is RHEL/CentOS/Rocky. Package filename looks like turbovnc-3.0.91.x86_64.rpm
		arch="$(uname -m)"
		filename="turbovnc-${TURBOVNC_VERSION}.${arch}.rpm"
	else
		echo >&2 "error: cannot determine architecture and package extension for this OS"
		exit 1
	fi
	TURBOVNC_DOWNLOAD_URL="${TURBOVNC_DOWNLOAD_ROOT}/${files_root_enc}/${filename}"
fi

echo "Downloading ${TURBOVNC_DOWNLOAD_URL}..."
dlpath=$(curl -w "%{filename_effective}" -fsSLO "${TURBOVNC_DOWNLOAD_URL}")
trap 'rm -f "${dlpath:-}"' INT QUIT TERM EXIT

if [ -r "${dlpath}" ]; then
	if command -v dpkg >/dev/null 2>&1; then
		# Is Debian/Ubuntu
		dpkg --install --force-depends "${dlpath:-}" && apt-get install --fix-broken --yes --quiet && success=1
	elif command -v yum >/dev/null 2>&1; then
		# Is RHEL/CentOS/Rocky
		yum install -y -q "${dlpath}" && success=1 || echo >&2 "warning: failed to install ${dlpath} via yum"
	else
		echo >&2 "Cannot determine package manager for this OS"
	fi
fi

# Making extra sure we remove the download file:
rm -rf "${dlpath:-}"

[ -n "${success:-}" ] && exit 0 || exit 1
