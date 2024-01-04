#!/bin/sh

# Download and install FreeSurfer
# Configure with the following environment variables:
# 	FREESURFER_VERSION: The version of FreeSurfer to download (default: 7.4.1)
# 	FREESURFER_DOWNLOAD_URL: The URL to download FreeSurfer from
# 	FREESURFER_DOWNLOAD_FILENAME: The filename of the FreeSurfer package
# 	DOWNLOAD_DIR: The directory to download the FreeSurfer package to (default: .)
# 	FREESURFER_DOWNLOAD_PATH: The path to download the FreeSurfer package to (default: ${DOWNLOAD_DIR}/${FREESURFER_DOWNLOAD_FILENAME})
# 	FORCE_REDOWNLOAD: Set to 1 to force re-downloading the package (default: 0)
# 	KEEP_SETUP_DOWNLOADS: Set to 1 to keep the downloaded package (default: 0)
install_freesurfer() {
	[ "${XTRACE:-0}" = 1 ] && set -x

	command -v curl >/dev/null 2>&1 || { echo "ERROR: curl not found!" >&2; exit 1; }
	DOWNLOAD_DIR="${DOWNLOAD_DIR:-.}"
	FREESURFER_VERSION="${FREESURFER_VERSION:-7.4.1}"
	FREESURFER_DOWNLOAD_ROOT="${FREESURFER_DOWNLOAD_ROOT:-"https://surfer.nmr.mgh.harvard.edu/pub/dist/freesurfer/${FREESURFER_VERSION}"}"

	if [ -r /etc/os-release ]; then
		. /etc/os-release
	elif [ -r /usr/lib/os-release ]; then
		. /usr/lib/os-release
	else
		echo >&2 "ERROR: cannot determine OS release"
		exit 1
	fi

	if [ -z "${FREESURFER_DOWNLOAD_URL:-}" ]; then
		if [ -z "${FREESURFER_DOWNLOAD_FILENAME:-}" ]; then
			if command -v dpkg >/dev/null 2>&1; then
				# Is Debian/Ubuntu. Package filename looks like freesurfer_3.0.91_arm64.deb
				__freesurfer_arch="$(dpkg --print-architecture)" || { echo "ERROR: dpkg failed!" >&2; exit 1; }

		case "${ID:-} ${ID_LIKE:-}" in
		*ubuntu*) echo "Running on an Ubuntu-like platform, using Ubuntu .deb packages" ;;
		*)
			echo >&2 "Error: Must be Ubuntu-like"
			exit 1
			;;
		esac

		[ -n "${VERSION_ID:-}" ] && __freesurfer_os_major_version="${VERSION_ID%%.*}"
		[ -z "${__freesurfer_os_major_version:-}" ] && {
			echo >&2 "error: cannot determine Ubuntu major version"
			exit 1
		}

		FREESURFER_DOWNLOAD_FILENAME="freesurfer_ubuntu${__freesurfer_os_major_version}-${FREESURFER_VERSION}_${__freesurfer_arch}.deb"


			elif command -v yum >/dev/null 2>&1; then
				# Is RHEL/CentOS/Rocky. Package filename looks like freesurfer-3.0.91.x86_64.rpm
				__freesurfer_arch="$(uname -m)" || { echo "ERROR: uname failed!" >&2; exit 1; }
				case "${ID:-} ${ID_LIKE:-}" in
		*rhel* | *centos* | *fedora* | *rocky*) echo "Running on an CentOS-like platform, using CentOS .rpm packages" ;;
		*)
			echo >&2 "Error: Must be CentOS-like"
			exit 1
			;;
		esac
		[ -n "${VERSION_ID:-}" ] && __freesurfer_os_major_version="${VERSION_ID%%.*}"
		[ -z "${__freesurfer_os_major_version:-}" ] && {
			echo >&2 "error: cannot determine CentOS major version"
			exit 1
		}
		FREESURFER_DOWNLOAD_FILENAME="freesurfer_CentOS${__freesurfer_os_major_version}-${FREESURFER_VERSION}.${__freesurfer_arch}.rpm"
			else
				echo >&2 "ERROR: cannot determine architecture and package extension for this OS"
				exit 1
			fi
		fi
		FREESURFER_DOWNLOAD_URL="${FREESURFER_DOWNLOAD_ROOT}/${FREESURFER_DOWNLOAD_FILENAME}"
	fi

	[ -n "${FREESURFER_DOWNLOAD_FILENAME:-}" ] || FREESURFER_DOWNLOAD_FILENAME="${FREESURFER_DOWNLOAD_URL##*/}"

	FREESURFER_DOWNLOAD_PATH="${FREESURFER_DOWNLOAD_PATH:-${DOWNLOAD_DIR}/${FREESURFER_DOWNLOAD_FILENAME}}"

	if [ -r "${FREESURFER_DOWNLOAD_PATH}" ]; then
		echo "Found existing download at \"${FREESURFER_DOWNLOAD_PATH}\"" >&2
		if [ "${FORCE_REDOWNLOAD:-0}" -ne 0 ]; then
			echo "Forcing re-download..." >&2
		else
			echo "Skipping download." >&2
		fi
	fi

	if [ "${FORCE_REDOWNLOAD:-0}" -ne 0 ] || [ ! -r "${FREESURFER_DOWNLOAD_PATH}" ]; then
		echo "Downloading \"${FREESURFER_DOWNLOAD_FILENAME}\" from \"${FREESURFER_DOWNLOAD_URL}\"..." >&2
		curl --fail --fail-early --compressed --location \
			--output "${FREESURFER_DOWNLOAD_PATH}" \
			"${FREESURFER_DOWNLOAD_URL}" || { echo "ERROR: curl failed!" >&2; rm -fv "${FREESURFER_DOWNLOAD_PATH}" >&2; exit 1; }
		echo "Downloaded \"${FREESURFER_DOWNLOAD_FILENAME}\" from \"${FREESURFER_DOWNLOAD_URL}\"." >&2
		__freesurfer_did_download=1
	fi
	[ -r "${FREESURFER_DOWNLOAD_PATH}" ] || { echo "ERROR: Could not find \"${FREESURFER_DOWNLOAD_PATH}\"" >&2; exit 1; }

	if command -v dpkg >/dev/null 2>&1; then
		# Is Debian/Ubuntu
		dpkg --install --force-depends "${FREESURFER_DOWNLOAD_PATH}" && apt-get install --fix-broken --yes --quiet && __freesurfer_did_install=1 || echo >&2 "ERROR: failed to install \"${FREESURFER_DOWNLOAD_PATH}\""
	elif command -v yum >/dev/null 2>&1; then
		# Is RHEL/CentOS/Rocky
		yum install -y -q "${FREESURFER_DOWNLOAD_PATH}" && __freesurfer_did_install=1 || echo >&2 "WARN: failed to install \"${FREESURFER_DOWNLOAD_PATH}\""
	else
		echo >&2 "Cannot determine package manager for this OS"
	fi

	[ "${__freesurfer_did_download:-0}" -eq 1 ] && [ "${KEEP_SETUP_DOWNLOADS:-0}" -eq 0 ] && rm -f "${FREESURFER_DOWNLOAD_PATH}" # Remove the package if KEEP_SETUP_DOWNLOADS is not set
	if [ "${__freesurfer_did_install:-0}" -eq 1 ]; then
		echo "Successfully installed \"${FREESURFER_DOWNLOAD_FILENAME}\"." >&2
		exit 0
	else
		echo "ERROR: failed to install \"${FREESURFER_DOWNLOAD_FILENAME}\"." >&2
	fi

	# Save /opt/TurboVNC/bin to PATH if in an apptainer build:
	[ -d  "/opt/TurboVNC/bin" ] && [ -d "/.singularity.d/env" ] && echo "PATH=/opt/TurboVNC/bin:\${PATH}" >> "/.singularity.d/env/100-turbovnc.sh"
}

if [ -n "${BASH_VERSION:-}" ]; then
	(return 0 2>/dev/null) || install_freesurfer "$@"
else
	install_freesurfer "$@"
fi
