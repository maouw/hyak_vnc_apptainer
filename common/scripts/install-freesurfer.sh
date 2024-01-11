#!/usr/bin/env bash
# shellcheck shell=bash

# Download and install FreeSurfer
# Configure with the following environment variables:
# 	FREESURFER_VERSION: The version of FreeSurfer to download (default: 7.4.1)
#	DOWNLOAD_URL_ROOT: The root URL to download FreeSurfer from (default: https://surfer.nmr.mgh.harvard.edu/pub/dist/freesurfer/${FREESURFER_VERSION})
# 	DOWNLOAD_URL: The URL to download from (default: <auto>)
# 	DOWNLOAD_FILENAME: The output file of the dowmload (default: <auto>)
# 	DOWNLOAD_DIR: The directory to download to (default: .)
# 	DOWNLOAD_PATH: The path to download to (default: ${DOWNLOAD_DIR}/${DOWNLOAD_FILENAME})
# 	FORCE_REDOWNLOAD: Set to 1 to force re-downloading the package (default: 0)
# 	KEEP_SETUP_DOWNLOADS: Set to 1 to keep the downloaded package (default: 0)
[[ "${XDEBUG:-0}" =~ ^[1yYtT] ]] && set -x

set -o errtrace -o pipefail -o errexit
shopt -qs lastpipe

command -v curl >/dev/null 2>&1 || { echo "ERROR: curl not found!" >&2; exit 1; }

DOWNLOAD_DIR="${DOWNLOAD_DIR:-.}"
FREESURFER_VERSION="${FREESURFER_VERSION:-7.4.1}"
DOWNLOAD_URL_ROOT="${DOWNLOAD_URL_ROOT:-"https://surfer.nmr.mgh.harvard.edu/pub/dist/freesurfer/${FREESURFER_VERSION}"}"
FORCE_REDOWNLOAD="${FORCE_REDOWNLOAD:-0}"
KEEP_SETUP_DOWNLOADS="${KEEP_SETUP_DOWNLOADS:-0}"

if [[ -r /etc/os-release ]]; then
	source /etc/os-release
elif [[ -r /usr/lib/os-release ]]; then
	source /usr/lib/os-release
else
	echo >&2 "ERROR: cannot determine OS release"
	exit 1
fi

if [[ -z "${DOWNLOAD_URL:-}" ]]; then
	if [[ -z "${DOWNLOAD_FILENAME:-}" ]]; then
		if command -v dpkg >/dev/null 2>&1; then
			# Is Debian/Ubuntu. Package filename looks like freesurfer_3.0.91_arm64.deb
			DL_ARCH="$(dpkg --print-architecture)" || { echo "ERROR: dpkg failed!" >&2; exit 1; }

			case "${ID:-} ${ID_LIKE:-}" in
				*ubuntu*) echo "Running on an Ubuntu-like platform, using Ubuntu .deb packages" ;;
				*)
					echo >&2 "Error: Must be Ubuntu-like"
					exit 1
					;;
			esac

			[[ -n "${VERSION_ID:-}" ]] && DL_OS_MAJOR_VERSION="${VERSION_ID%%.*}"
			[[ -z "${DL_OS_MAJOR_VERSION:-}" ]] && {
				echo >&2 "error: cannot determine Ubuntu major version"
				exit 1
			}

			DOWNLOAD_FILENAME="freesurfer_ubuntu${DL_OS_MAJOR_VERSION}-${FREESURFER_VERSION}_${DL_ARCH}.deb"

		elif
			command -v yum >/dev/null 2>&1; then
			# Is RHEL/CentOS/Rocky. Package filename looks like freesurfer-3.0.91.x86_64.rpm
			DL_ARCH="$(uname -m)" || { echo "ERROR: uname failed!" >&2; exit 1; }
			case "${ID:-} ${ID_LIKE:-}" in
				*rhel* | *centos* | *fedora* | *rocky*) echo "Running on an CentOS-like platform, using CentOS .rpm packages" ;;
				*)
					echo >&2 "Error: Must be CentOS-like"
					exit 1
					;;
			esac
			[[ -n "${VERSION_ID:-}" ]] && DL_OS_MAJOR_VERSION="${VERSION_ID%%.*}"
			[[ -z "${DL_OS_MAJOR_VERSION:-}" ]] && {
				echo >&2 "error: cannot determine CentOS major version"
				exit 1
			}
			DOWNLOAD_FILENAME="freesurfer_CentOS${DL_OS_MAJOR_VERSION}-${FREESURFER_VERSION}.${DL_ARCH}.rpm"
		else
			echo >&2 "ERROR: cannot determine architecture and package extension for this OS"
			exit 1
		fi
	fi
	DOWNLOAD_URL="${DOWNLOAD_URL_ROOT}/${DOWNLOAD_FILENAME}"
fi

[[ -n "${DOWNLOAD_FILENAME:-}" ]] || DOWNLOAD_FILENAME="$(basename "${DOWNLOAD_URL}")"

DOWNLOAD_PATH="${DOWNLOAD_PATH:-${DOWNLOAD_DIR}/${DOWNLOAD_FILENAME}}"

# Check if installer already exists
if [[ -r "${DOWNLOAD_PATH}" ]]; then
	echo "Found existing download at \"${DOWNLOAD_PATH}\"" >&2
	if [[ "${FORCE_REDOWNLOAD:-0}" -ne 0 ]]; then
		echo "Forcing re-download..." >&2
	else
		echo "Skipping download." >&2
	fi
fi

# Clean up on exit
trap '[[ "${DID_INSTALL:-0}" -eq 1 ]] && "${KEEP_SETUP_DOWNLOADS:-0}" -eq 0 ]] && rm -f "${DOWNLOAD_PATH}"; [[ "${DID_INSTALL:-1}" -eq 1 ]] && { echo "Successfully installed \"${DOWNLOAD_FILENAME}\"" >&2; exit 0; } || { echo "Could not install \"${DOWNLOAD_FILENAME}\"" >&2; exit 1; }' EXIT

# Download the installer
if [[ "${FORCE_REDOWNLOAD:-0}" -ne 0 ]] || [[ ! -r "${DOWNLOAD_PATH}" ]]; then
	echo "Downloading \"${DOWNLOAD_URL}\"..." >&2
	curl --fail --fail-early --compressed --location \
		--output "${DOWNLOAD_PATH}" \
		"${DOWNLOAD_URL}" || { echo "ERROR: curl failed!" >&2; rm -fv "${DOWNLOAD_PATH}" >&2; exit 1; }
	echo "Downloaded \"${DOWNLOAD_FILENAME}\" from \"${DOWNLOAD_URL}\"" >&2
fi

# Install the package
if command -v dpkg >/dev/null 2>&1; then
	# Is Debian/Ubuntu
	dpkg --install --force-depends "${DOWNLOAD_PATH}" && apt-get install --fix-broken --yes --quiet || exit 1
	DID_INSTALL=1
elif command -v yum >/dev/null 2>&1; then
	# Is RHEL/CentOS/Rocky
	yum install -y -q "${DOWNLOAD_PATH}" || exit 1
	DID_INSTALL=1
else
	echo >&2 "Cannot determine package manager for this OS" && exit 1
fi
