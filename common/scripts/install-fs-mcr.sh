#!/usr/bin/env bash
# shellcheck shell=bash

# Download and install MCR for Freesurfer
# Configure with the following environment variables:
# 	MCR_VERSION: The version of MCR to download (default: R2014b)
# 	MCR_TARGET_DIR: Where to install MCR (default: "${MCR_TARGET_DIR:-${FREESURFER_HOME}/MCR${MCR_NAME}}")
# 	DOWNLOAD_URL: The URL to download from (default: <auto>)
# 	DOWNLOAD_FILENAME: The output file of the dowmload (default: DOWNLOAD_FILENAME="fsmcr-${MCR_VERSION}-installer.zip")
# 	DOWNLOAD_DIR: The directory to download to (default: .)
# 	DOWNLOAD_PATH: The path to download to (default: ${DOWNLOAD_DIR}/${DOWNLOAD_FILENAME})
# 	FORCE_REDOWNLOAD: Set to 1 to force re-downloading the package (default: 0)
# 	KEEP_SETUP_DOWNLOADS: Set to 1 to keep the downloaded package (default: 0)

set -o errtrace -o pipefail -o errexit
shopt -qs lastpipe


[[ -n "${FREESURFER_HOME:-}" ]] || { echo "ERROR: FREESURFER_HOME not set!" >&2; exit 1; }

command -v curl >/dev/null 2>&1 || { echo "ERROR: curl not found!" >&2; exit 1; }
command -v unzip >/dev/null 2>&1 || { echo "ERROR: unzip not found!" >&2; exit 1; }

DOWNLOAD_DIR="${DOWNLOAD_DIR:-.}"
FORCE_REDOWNLOAD="${FORCE_REDOWNLOAD:-0}"
KEEP_SETUP_DOWNLOADS="${KEEP_SETUP_DOWNLOADS:-0}"

# Set the MCR version
MCR_VERSION="${MCR_VERSION:-R2014b}"

# Set the MCR download URL
if [[ -n "${DOWNLOAD_URL:-}" ]]; then
	OS_TAG=glnxa64
	case "${MCR_VERSION}" in
		R1024a | R2014b)
			DOWNLOAD_URL="https://ssd.mathworks.com/supportfiles/downloads/${MCR_VERSION}/deployment_files/${MCR_VERSION}/installers/${OS_TAG}/MCR_${MCR_VERSION}_${OS_TAG}_installer.zip"
			;;
		R2019b)
			DOWNLOAD_URL="https://ssd.mathworks.com/supportfiles/downloads/${MCR_VERSION}/Release/9/deployment_files/installer/complete/${OS_TAG}/MATLAB_Runtime_${MCR_VERSION}_Update_9_${OS_TAG}.zip"
			;;
		R2012a | R2012b | R2013a)
			DOWNLOAD_URL="https://ssd.mathworks.com/supportfiles/MCR_Runtime/${MCR_VERSION}/MCR_${MCR_VERSION}_${OS_TAG}_installer.zip"
			;;
		*)
			echo >&2 "ERROR: unsupported MCR version \"${MCR_VERSION}\""
			exit 1
			;;
	esac
fi

# Set the MCR download filename and path
DOWNLOAD_FILENAME="fsmcr-${MCR_VERSION}-installer.zip"
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

# Create a temporary directory for extracting the MCR installer
TMP_EXTRACT_DIR="$(mktemp -d)" || { echo "ERROR: mktemp failed!" >&2; exit 1; }

# Clean up on exit
trap 'rm -rf "${TMP_EXTRACT_DIR}"; [[ "${DID_INSTALL:-0}" -eq 1 ]] && "${KEEP_SETUP_DOWNLOADS:-0}" -eq 0 ]] && rm -f "${DOWNLOAD_PATH}"; [[ "${DID_INSTALL:-1}" -eq 1 ]] && { echo "Successfully installed \"${DOWNLOAD_FILENAME}\"" >&2; exit 0; } || { echo "Could not install \"${DOWNLOAD_FILENAME}\"" >&2; exit 1; }' EXIT

# Download the installer
if [[ "${FORCE_REDOWNLOAD:-0}" -ne 0 ]] || [[ ! -r "${DOWNLOAD_PATH}" ]]; then
	echo "Downloading \"${DOWNLOAD_URL}\"..." >&2
	curl --fail --fail-early --compressed --location \
		--output "${DOWNLOAD_PATH}" \
		"${DOWNLOAD_URL}" || { echo "ERROR: curl failed!" >&2; rm -fv "${DOWNLOAD_PATH}" >&2; exit 1; }
	echo "Downloaded \"${DOWNLOAD_FILENAME}\" from \"${DOWNLOAD_URL}\"" >&2
fi

# Extract the MCR installer
unzip -d "${TMP_EXTRACT_DIR}" "${DOWNLOAD_PATH}" || { echo "ERROR: unzip failed!" >&2; rm -rf "${TMP_EXTRACT_DIR}" >&2; exit 1; }

# Install the MCR to a temporary directory
TMP_INSTALL_TARGET="$(realpath "${TMP_EXTRACT_DIR}/tmp-install-target")" || { echo "ERROR: realpath failed!" >&2; exit 1; }
cd "${TMP_EXTRACT_DIR}" || { echo "ERROR: cd failed!" >&2; exit 1; }
./install -mode silent -agreeToLicense yes -destinationFolder "${TMP_INSTALL_TARGET}" || { echo "ERROR: MCR install failed!" >&2; exit 1; } 

# Move the MCR to the target directory
MCR_DIR="$(printf '%s' "${TMP_INSTALL_TARGET}"/v*)"
[[ -n "${MCR_DIR}" ]] || { echo "ERROR: Could not determine MCR directory!" >&2; exit 1; }
MCR_NAME="$(basename "${MCR_DIR}")"
[[ -n "${MCR_NAME}" ]] || { echo "ERROR: Could not determine MCR name!" >&2; exit 1; }
MCR_TARGET_DIR="${MCR_TARGET_DIR:-${FREESURFER_HOME}/MCR${MCR_NAME}}"
mv "${MCR_DIR}" "${MCR_TARGET_DIR}" && DID_INSTALL=1
