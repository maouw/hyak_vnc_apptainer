#!/bin/sh
# Install FreeSurfer:

export FREESURFER_VERSION="${FREESURFER_VERSION:-7.4.1}"
FREESURFER_DOWNLOAD_ROOT="https://surfer.nmr.mgh.harvard.edu/pub/dist/freesurfer/${FREESURFER_VERSION}"
export FREESURFER_HOME="${FREESURFER_HOME:-/usr/local/freesurfer/${FREESURFER_VERSION}}"
export FREESURFER_DOWNLOAD_URL="${FREESURFER_DOWNLOAD_URL:-}"

if ! command -v curl >/dev/null 2>&1; then
	echo "warning: curl not found!" >&2
	exit 1
fi

if [ -z "${FREESURFER_DOWNLOAD_URL:-}" ]; then
	if command -v dpkg >/dev/null 2>&1; then
		# Is Debian/Ubuntu.
		arch="$(dpkg --print-architecture)"
		if [ -r /etc/os-release ]; then
			. /etc/os-release
		elif [ -r /usr/lib/os-release ]; then
			. /usr/lib/os-release
		else
			echo >&2 "error: cannot determine OS release"
			exit 1
		fi

		case "${ID:-} ${ID_LIKE:-}" in
		*ubuntu*) echo "Running on an Ubuntu-like platform, using Ubuntu .deb packages" ;;
		*)
			echo >&2 "Error: Must be Ubuntu-like"
			exit 1
			;;
		esac
		ubuntu_major_version="${VERSION_ID%%.*}"
		[ -z "${ubuntu_major_version:-}" ] && {
			echo >&2 "error: cannot determine Ubuntu major version"
			exit 1
		}
		filename="freesurfer_ubuntu${ubuntu_major_version}-${FREESURFER_VERSION}_${arch}.deb"
	elif command -v yum >/dev/null 2>&1; then
		# Is RHEL/CentOS/Rocky
		arch="$(uname -m)"
		if [ -r /etc/os-release ]; then
			. /etc/os-release
		elif [ -r /usr/lib/os-release ]; then
			. /usr/lib/os-release
		else
			echo >&2 "error: cannot determine OS release"
			exit 1
		fi

		case "${ID:-} ${ID_LIKE:-}" in
		*rhel* | *centos* | *fedora* | *rocky*) echo "Running on an CentOS-like platform, using CentOS .rpm packages" ;;
		*)
			echo >&2 "Error: Must be CentOS-like"
			exit 1
			;;
		esac
		centos_major_version="${VERSION_ID%%.*}"
		[ -z "${centos_major_version:-}" ] && {
			echo >&2 "error: cannot determine CentOS major version"
			exit 1
		}
		filename="freesurfer_CentOS${centos_major_version}-${FREESURFER_VERSION}.${arch}.rpm"
	else
		echo >&2 "error: cannot determine architecture and package extension for this OS"
		exit 1
	fi
	FREESURFER_DOWNLOAD_URL="${FREESURFER_DOWNLOAD_ROOT}/${filename}"
fi

[ -z "${FREESURFER_DOWNLOAD_URL:-}" ] && {
	echo >&2 "error: cannot determine download URL"
	exit 1
}

echo "Downloading ${FREESURFER_DOWNLOAD_URL}..."
dlpath=$(curl -w "%{filename_effective}" -fsSLO "${FREESURFER_DOWNLOAD_URL}")
trap 'rm -f "${dlpath:-}"' INT QUIT TERM EXIT

if [ -r "${dlpath}" ]; then
	if command -v dpkg >/dev/null 2>&1; then
		# Is Debian/Ubuntu
		dpkg --install --force-depends "${dlpath:-}" && apt-get install --fix-broken --yes --quiet && export success=1 || echo >&2 "warning: failed to install ${dlpath} via yum"
	elif command -v yum >/dev/null 2>&1; then
		# Is RHEL/CentOS/Rocky
		yum install -y -q "${dlpath}" && export success=1 || echo >&2 "warning: failed to install ${dlpath} via yum"
	else
		echo >&2 "Cannot determine package manager for this OS"
	fi
fi

# Making extra sure we remove the download file (huge):
rm -rf "${dlpath:-}"

[ -n "${success:-}" ] && exit 0 || exit 1
