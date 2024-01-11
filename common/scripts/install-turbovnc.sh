#!/usr/bin/env bash
# shellcheck shell=bash

# Download and install TurboVNC
# Configure with the following environment variables:
# 	TURBOVNC_VERSION: The version of TurboVNC to download (default: 3.1)
#	DOWNLOAD_URL_ROOT: The root URL to download TurboVNC from (default: https://sourceforge.net/projects/turbovnc/files)
# 	DOWNLOAD_URL: The URL to download from (default: <auto>)
# 	DOWNLOAD_FILENAME: The output file of the dowmload (default: <auto>)
# 	DOWNLOAD_DIR: The directory to download to (default: .)
# 	DOWNLOAD_PATH: The path to download to (default: ${DOWNLOAD_DIR}/${DOWNLOAD_FILENAME})
# 	FORCE_REDOWNLOAD: Set to 1 to force re-downloading the package (default: 0)
# 	KEEP_SETUP_DOWNLOADS: Set to 1 to keep the downloaded package (default: 0)

set -o errtrace -o pipefail -o errexit
shopt -qs lastpipe
set -x

command -v curl >/dev/null 2>&1 || { echo "ERROR: curl not found!" >&2; exit 1; }

DOWNLOAD_DIR="${DOWNLOAD_DIR:-.}"
FORCE_REDOWNLOAD="${FORCE_REDOWNLOAD:-0}"
KEEP_SETUP_DOWNLOADS="${KEEP_SETUP_DOWNLOADS:-0}"

TURBOVNC_VERSION="${TURBOVNC_VERSION:-3.1}"
TURBOVNC_VERSION_SHORT="${TURBOVNC_VERSION%% *}"
DOWNLOAD_URL_ROOT="${DOWNLOAD_URL_ROOT:-"https://sourceforge.net/projects/turbovnc/files"}"

if [[ -z "${DOWNLOAD_URL:-}" ]]; then
	if [[ -z "${TURBOVNC_DOWNLOAD_RELEASE_DIR:-}" ]]; then
		# url-encode the files root:
		TURBOVNC_DOWNLOAD_RELEASE_DIR="$(echo "${TURBOVNC_VERSION}" | curl -Gs -w '%{url_effective}' --data-urlencode @- ./ | sed "s/%0[aA]$//;s/^[^?]*?\(.*\)/\1/;s/[[+]]/%20/g" || true)"
	fi

	[[ -n "${TURBOVNC_DOWNLOAD_RELEASE_DIR:-}" ]] || { echo "ERROR: TURBOVNC_DOWNLOAD_RELEASE_DIR not set!" >&2; exit 1; }

	if [[ -z "${DOWNLOAD_FILENAME:-}" ]]; then
		if command -v dpkg >/dev/null 2>&1; then
			# Is Debian/Ubuntu. Package filename looks like turbovnc_3.0.91_arm64.deb
			DL_ARCH="$(dpkg --print-architecture)" || { echo "ERROR: dpkg failed!" >&2; exit 1; }
			DOWNLOAD_FILENAME="turbovnc_${TURBOVNC_VERSION_SHORT}_${DL_ARCH}.deb"
		elif command -v yum >/dev/null 2>&1; then
			# Is RHEL/CentOS/Rocky. Package filename looks like turbovnc-3.0.91.x86_64.rpm
			DL_ARCH="$(uname -m)" || { echo "ERROR: uname failed!" >&2; exit 1; }
			DOWNLOAD_FILENAME="turbovnc-${TURBOVNC_VERSION_SHORT}.${DL_ARCH}.rpm"
		else
			echo >&2 "ERROR: cannot determine architecture and package extension for this OS"
			exit 1
		fi
	fi
	DOWNLOAD_URL="${DOWNLOAD_URL_ROOT}/${TURBOVNC_DOWNLOAD_RELEASE_DIR}/${DOWNLOAD_FILENAME}"
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
		"${DOWNLOAD_URL}" || { echo "ERROR: curl failed to download ${DOWNLOAD_URL}!" >&2; rm -fv "${DOWNLOAD_PATH}" >&2; exit 1; }
	echo "Downloaded \"${DOWNLOAD_FILENAME}\" from \"${DOWNLOAD_URL}\"" >&2
fi
if command -v dpkg >/dev/null 2>&1; then
	# Is Debian/Ubuntu
	dpkg --install --force-depends "${DOWNLOAD_PATH}" && apt-get install --fix-broken --yes --quiet && DID_INSTALL=1 || echo >&2 "ERROR: failed to install \"${DOWNLOAD_PATH}\""
elif command -v yum >/dev/null 2>&1; then
	# Is RHEL/CentOS/Rocky
	yum install -y -q "${DOWNLOAD_PATH}" && DID_INSTALL=1 || echo >&2 "WARN: failed to install \"${DOWNLOAD_PATH}\""
else
	echo >&2 "Cannot determine package manager for this OS"
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
