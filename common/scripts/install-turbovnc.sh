#!/bin/sh

# Download and install TurboVNC
# Configure with the following environment variables:
# 	TURBOVNC_VERSION: The version of TurboVNC to download (default: 3.1)
# 	TURBOVNC_DOWNLOAD_URL: The URL to download TurboVNC from (default: https://sourceforge.net/projects/turbovnc/files/${TURBOVNC_VERSION}/turbovnc_${TURBOVNC_VERSION}_amd64.deb)
# 	TURBOVNC_DOWNLOAD_FILENAME: The filename of the TurboVNC package (default: turbovnc_${TURBOVNC_VERSION}_amd64.deb)
# 	DOWNLOAD_DIR: The directory to download the TurboVNC package to (default: .)
# 	TURBOVNC_DOWNLOAD_PATH: The path to download the TurboVNC package to (default: ${DOWNLOAD_DIR}/${TURBOVNC_DOWNLOAD_FILENAME})
# 	FORCE_REDOWNLOAD: Set to 1 to force re-downloading the package (default: 0)
# 	KEEP_SETUP_DOWNLOADS: Set to 1 to keep the downloaded package (default: 0)
install_turbovnc() {
	[ "${XTRACE:-0}" = 1 ] && set -x

	command -v curl >/dev/null 2>&1 || { echo "ERROR: curl not found!" >&2; exit 1; }
	DOWNLOAD_DIR="${DOWNLOAD_DIR:-.}"
	TURBOVNC_VERSION="${TURBOVNC_VERSION:-3.1}"
	TURBOVNC_VERSION_SHORT="${TURBOVNC_VERSION%% *}"
	TURBOVNC_DOWNLOAD_ROOT="${TURBOVNC_DOWNLOAD_ROOT:-"https://sourceforge.net/projects/turbovnc/files"}"

	if [ -z "${TURBOVNC_DOWNLOAD_RELEASE_DIR:-}" ]; then
		# url-encode the files root:
		TURBOVNC_DOWNLOAD_RELEASE_DIR="$(echo "${TURBOVNC_VERSION}" | curl -Gs -w '%{url_effective}' --data-urlencode @- ./ | sed "s/%0[aA]$//;s/^[^?]*?\(.*\)/\1/;s/[+]/%20/g")" || { echo "ERROR: curl failed!" >&2; exit 1; }
	fi

	[ -n "${TURBOVNC_DOWNLOAD_RELEASE_DIR:-}" ] || { echo "ERROR: TURBOVNC_DOWNLOAD_RELEASE_DIR not set!" >&2; exit 1; }

	if [ -z "${TURBOVNC_DOWNLOAD_URL:-}" ]; then
		if [ -z "${TURBOVNC_DOWNLOAD_FILENAME:-}" ]; then
			if command -v dpkg >/dev/null 2>&1; then
				# Is Debian/Ubuntu. Package filename looks like turbovnc_3.0.91_arm64.deb
				__turbovnc_arch="$(dpkg --print-architecture)" || { echo "ERROR: dpkg failed!" >&2; exit 1; }
				TURBOVNC_DOWNLOAD_FILENAME="turbovnc_${TURBOVNC_VERSION_SHORT}_${__turbovnc_arch}.deb"
			elif command -v yum >/dev/null 2>&1; then
				# Is RHEL/CentOS/Rocky. Package filename looks like turbovnc-3.0.91.x86_64.rpm
				__turbovnc_arch="$(uname -m)" || { echo "ERROR: uname failed!" >&2; exit 1; }
				TURBOVNC_DOWNLOAD_FILENAME="turbovnc-${TURBOVNC_VERSION_SHORT}.${__turbovnc_arch}.rpm"
			else
				echo >&2 "ERROR: cannot determine architecture and package extension for this OS"
				exit 1
			fi
		fi
		TURBOVNC_DOWNLOAD_URL="${TURBOVNC_DOWNLOAD_ROOT}/${TURBOVNC_DOWNLOAD_RELEASE_DIR}/${TURBOVNC_DOWNLOAD_FILENAME}"
	fi

	[ -n "${TURBOVNC_DOWNLOAD_FILENAME:-}" ] || TURBOVNC_DOWNLOAD_FILENAME="${TURBOVNC_DOWNLOAD_URL##*/}"

	TURBOVNC_DOWNLOAD_PATH="${TURBOVNC_DOWNLOAD_PATH:-${DOWNLOAD_DIR}/${TURBOVNC_DOWNLOAD_FILENAME}}"

	if [ -r "${TURBOVNC_DOWNLOAD_PATH}" ]; then
		echo "Found existing download at \"${TURBOVNC_DOWNLOAD_PATH}\"" >&2
		if [ "${FORCE_REDOWNLOAD:-0}" -ne 0 ]; then
			echo "Forcing re-download..." >&2
		else
			echo "Skipping download." >&2
		fi
	fi

	if [ "${FORCE_REDOWNLOAD:-0}" -ne 0 ] || [ ! -r "${TURBOVNC_DOWNLOAD_PATH}" ]; then
		echo "Downloading \"${TURBOVNC_DOWNLOAD_FILENAME}\" from \"${TURBOVNC_DOWNLOAD_URL}\"..." >&2
		curl --fail --fail-early --compressed --location \
			--output "${TURBOVNC_DOWNLOAD_PATH}" \
			"${TURBOVNC_DOWNLOAD_URL}" || { echo "ERROR: curl failed!" >&2; rm -fv "${TURBOVNC_DOWNLOAD_PATH}" >&2; exit 1; }
		echo "Downloaded \"${TURBOVNC_DOWNLOAD_FILENAME}\" from \"${TURBOVNC_DOWNLOAD_URL}\"." >&2
		__turbovnc_did_download=1
	fi
	[ -r "${TURBOVNC_DOWNLOAD_PATH}" ] || { echo "ERROR: Could not find \"${TURBOVNC_DOWNLOAD_PATH}\"" >&2; exit 1; }

	if command -v dpkg >/dev/null 2>&1; then
		# Is Debian/Ubuntu
		dpkg --install --force-depends "${TURBOVNC_DOWNLOAD_PATH}" && apt-get install --fix-broken --yes --quiet && __turbovnc_did_install=1 || echo >&2 "ERROR: failed to install \"${TURBOVNC_DOWNLOAD_PATH}\""
	elif command -v yum >/dev/null 2>&1; then
		# Is RHEL/CentOS/Rocky
		yum install -y -q "${TURBOVNC_DOWNLOAD_PATH}" && __turbovnc_did_install=1 || echo >&2 "WARN: failed to install \"${TURBOVNC_DOWNLOAD_PATH}\""
	else
		echo >&2 "Cannot determine package manager for this OS"
	fi

	[ "${__turbovnc_did_download:-0}" -eq 1 ] && [ "${KEEP_SETUP_DOWNLOADS:-0}" -eq 0 ] && rm -f "${TURBOVNC_DOWNLOAD_PATH}" # Remove the package if KEEP_SETUP_DOWNLOADS is not set
	if [ "${__turbovnc_did_install:-0}" -eq 1 ]; then
		echo "Successfully installed \"${TURBOVNC_DOWNLOAD_FILENAME}\"." >&2
		# Save /opt/TurboVNC/bin to PATH if in an apptainer build:
		[ -d "/opt/TurboVNC/bin" ] && [ -d "/.singularity.d/env" ] && echo "PATH=/opt/TurboVNC/bin:\${PATH}" >>"/.singularity.d/env/100-turbovnc.sh"
		exit 0
	else
		echo "ERROR: failed to install \"${TURBOVNC_DOWNLOAD_FILENAME}\"." >&2
	fi
	export PATH="/opt/local/bin:/opt/TurboVNC/bin:${PATH}"

}

if [ -n "${BASH_VERSION:-}" ]; then
	(return 0 2>/dev/null) || install_turbovnc "$@"
else
	install_turbovnc "$@"
fi
