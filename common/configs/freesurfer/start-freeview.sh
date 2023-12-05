#!/bin/bash
[[ "${XDEBUG:-0}" =~ ^[1yYtT] ]] && set -x

set -o pipefail

function check_fs_license() {
	local fsl="${1:-${FS_LICENSE:-}}"
	[[ -n "${fsl:-}" ]] || { echo "variable contents empty"; return 1; }
	[[ -f "${fsl:-}" ]] || { echo "not a file"; return 1; }
	[[ -r "${fsl:-}" ]] || { echo "not readable"; return 1; }
	local nlines=0
	nlines="$(wc -l "${fsl}" | cut -d' ' -f1 || true)"
	[[ "${nlines:-0}" -gt 1 ]] || { echo "not a valid license file"; return 1; }
	[[ "${nlines:-0}" -lt 50 ]] || { echo "not a valid license file"; return 1; }
	head -n 1 "${fsl}" | grep -q '[@]' || { echo "not a valid license file"; return 1; }
	return 0
}

if [[ -z "${FREESURFER_HOME:-}" ]]; then
	echo "FREESURFER_HOME is not set" >&2
	zenity --error --text "CRITICAL: FreeSurfer path FREESURFER_HOME is not set! Exiting."
	exit 1
fi

if [[ ! -d "${FREESURFER_HOME:-}" ]]; then
	echo "FREESURFER_HOME is not a directory" >&2
	zenity --error --text "CRITICAL: FreeSurfer path FREESURFER_HOME is not a directory! Exiting."
	exit 1
fi

if [[ ! -r "${FREESURFER_HOME:-}" ]]; then
	echo "FREESURFER_HOME is not readable" >&2
	zenity --error --text "CRITICAL: FreeSurfer path FREESURFER_HOME is not readable! Exiting."
	exit 1
fi

function choose_fs_license() {
	while true; do
		zenity --question --text "Would you like to select a license file to use for this session?" || break
		fsl="$(zenity --file-selection)" || { zenity --error --text "No file selected."; return 1; }
		if res_msg="$(check_fs_license "${fsl:-}")"; then
			echo "FreeSurfer license path FS_LICENSE=\"${fsl:-}\" is valid: ${res_msg:-}." >&2
			zenity --info --text "FreeSurfer license at \"${fsl:-}\" is valid."
			export FS_LICENSE="${fsl}"
			return 0
		else
			echo "FreeSurfer license at \"${fsl:-}\" is invalid: ${res_msg:-}." >&2
			zenity --error --text "FreeSurfer license at \"${fsl:-}\" is invalid: ${res_msg:-}."
		fi
	done
	return 1
}

function locate_fs_license() {
	[[ ! -v FS_LICENSE ]] && check_fs_license "${FREESURFER_HOME}/license.txt" && return 0
	res_msg="$(check_fs_license "${FS_LICENSE:-}")" && return 0
	zenity --error --text "FreeSurfer license path FS_LICENSE=\"${FS_LICENSE:-}\" is invalid: ${res_msg:-}."

	if res_msg="$(check_fs_license "${FREESURFER_HOME}/license.txt")"; then
		echo "FreeSurfer license path FREESURFER_HOME/license.txt is valid" >&2
		zenity --question --text "FreeSurfer license path \"${FREESURFER_HOME}/license.txt\" is valid. Would you like to use this file for this session?" || return 1
		export FS_LICENSE="${FREESURFER_HOME}/license.txt"
		return 0
	fi

	choose_fs_license || return 1
}

locate_fs_license || { echo "No valid FreeSurfer license found. Exiting." >&2; zenity --error --text "No valid FreeSurfer license found. FreeSurfer may not work properly."; }

exec freeview "$@"
