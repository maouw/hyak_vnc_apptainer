#!/usr/bin/env bash
# shellcheck shell=bash

[[ "${XDEBUG:-0}" =~ ^[1yYtT] ]] && set -x
set -o errexit -o errtrace -o nounset -o pipefail

PROGNAME="${0##*/}"
VERBOSE="${VERBOSE:-0}"
PROG_VERSION="0.0.1"

USER="${USER:-$(id -un || true)}"
HOME="${HOME:-/home/${USER}}"
HOST="${HOST:-$(uname -n || true)}"
HOSTNAME="${HOSTNAME:-${HOST}}"
HOSTTYPE="${HOSTTYPE:-$(uname -m || true)}"
OSTYPE="${OSTYPE:-$(uname -s || true)}"
PLATFORM="${PLATFORM:-${OSTYPE}-${HOSTTYPE}}"

export TVNC_WM="${TVNC_WM:-xfce}"

export VNC_PASSWORD="${HYAKVNC_PASSWORD:-${VNC_PASSWORD:-password}}"
export VNC_DISPLAY="${HYAKVNC_DISPLAY:-${VNC_DISPLAY:-10}}"
export VNC_USER_DIR="${VNC_USER_DIR:-/vnc}"
export VNC_FG="${VNC_FG:-1}"
export VNC_LOG="${VNC_LOG:-${VNC_USER_DIR}/vnc.log}"
export VNC_SOCKET="${VNC_SOCKET:-${VNC_USER_DIR}/socket.uds}"
export VNC_PORT="${VNC_PORT:-}"

function _errecho() {
	local timestamp
	timestamp=$(date +"%Y-%m-%d %H:%M:%S")
	printf "%s %b\n" "${timestamp}" "$*" >&2 || true
	return 0
}

function _verrecho() {
	_errecho "$*"
	return 0
}

function _errexit() {
	_errecho "ERROR: $*"
	exit 1
}

function _trap_err() {
	# shellcheck disable=SC2319
	local _exit_code="$?"
	local _command="${BASH_COMMAND:-unknown}"

	(($# >= 1)) && [[ -n "${1:-}" ]] && _command="$1"
	(($# >= 2)) && [[ -n "${2:-}" ]] && _exit_code="$2"

	local -i start=$((${1:-0} + 1))
	local -i end=${#BASH_SOURCE[@]}
	local -i i=0
	local -i j=0
	_errecho "ERROR: ${_command} failed with exit code ${_exit_code}"
	for ((i = start; i < end; i++)); do
		j=$((i - 1))
		local indent=""
		for ((k = 0; k < i; k++)); do
			indent+="  "
		done
		local function="${FUNCNAME[${i}]}"
		local file="${BASH_SOURCE[${i}]}"
		local line="${BASH_LINENO[${j}]}"
		echo >&2 "${indent}${file}:${line}${function:+ in function ${function}()}"
	done
}

function _trap_exit() {
	local _exit_code="$?"
	local _command="${BASH_COMMAND:-unknown}"
	[[ "${_exit_code:-0}" != 0 ]] && _err_handler "${_command}" "${_exit_code}"
	exit "${_exit_code}"
}

trap _trap_err ERR

function _cleanup_vncserver() {
	[[ -n "${VNC_SOCKET:-}" ]] && [[ -S "${VNC_SOCKET}" ]] && { rm -rfv "${VNC_SOCKET}" 2>/dev/null || true; }
	[[ -n "${VNC_USER_DIR:-}" ]] && [[ -d "${VNC_USER_DIR}" ]] && { rm -rfv "${VNC_USER_DIR}"/*.{pid,udspath,uds} 2>/dev/null || true; }
	return 0
}

trap '_cleanup_vncserver; _trap_exit' EXIT

function show_help() {
	expand -t 4 <<EOF
Wrapper to run TurboVNC and XFCE in a container

Usage: ${PROGNAME} [options] -- <vncserver args>
	--password <password>	Set the VNC password (default: password)
	--display <display>		Set the VNC display (default: :10)	
	--user-dir <dir>		Set the VNC directory (default: /tmp/${USER}-vnc)
	--log <file>		Set the VNC _errecho file (default: "${VNC_USER_DIR}/vnc.log")
	--socket <socket>		Set the VNC Unix socket (default: ${VNC_USER_DIR}/socket.uds)
	--port <port>			Set the VNC port (default: unset, use Unix socket)
	--foreground | --fg		Run in the foreground (default)
	--wm <wm>				Set the window manager (default: xfce)
	--verbose				Verbose output
	--trace					Debug output
	--help | -h 			Print this help message
	-- <vncserver args>		Pass any additional arguments to vncserver
								(e.g. -geometry 1920x1080)

Description:
	This script is a wrapper to run TurboVNC and XFCE in a container.
	It is intended to be used in conjunction with the \`hyakvnc\` script.

	By default, it will run in the foreground and use a Unix socket in a
	predictable location. It will also set the VNC password to "password".
	Any arguments following \`--\` will be passed to \`vncserver\`.
	
	You can override these defaults with the options above.

Examples:
	# Run in the foreground on a TCP port with a custom password and geometry:
	\$ ${PROGNAME} --password hunter2 --port 5911 -- -geometry 1920x1080
EOF
}

function run_hyakvnc_vncserver() {
	# Parse arguments:
	while (($# > 0)); do
		case "${1:-}" in
			--?*=* | -?*=*) # Handle --flag=value args
				set -- "${1%%=*}" "${1#*=}" "${@:2}"
				continue
				;;
			--trace) set -o xtrace ;;
			--verbose) export VERBOSE=1 ;;
			-h | --help) show_help; return 0 ;;
			--version) echo "${PROGNAME} version ${PROG_VERSION:-}"; return 0 ;;
			--password | --display | --user-dir | --log | --socket | --port)
				local argcap="${1#--}"  # Remove leading "--"
				argcap="${argcap//-/_}" # Replace "-" with "_"
				argcap="${argcap^^}"    # Convert to uppercase
				shift || { _errecho ERROR "$1 requires an argument"; exit 1; }
				export "VNC_${argcap}"="$1"
				;;
			--foreground | --fg)
				export VNC_FG=1
				;;
			--wm)
				shift || { _errecho ERROR "$1 requires an argument"; exit 1; }
				export TVNC_WM="$1"
				;;
			-? | --?*) # Handle unrecognized options
				_errecho ERROR "Unknown option \"${1:-}\""
				break
				;;
			*)
				_errecho "Unknown argument \"${1:-}\""
				break
				;;
		esac
		shift
	done

	_verrecho "Running as \"${USER:-$(id -un || true)}\" with UID \"${UID:-$(id -u || true)}\" and GID \"${GID:-$(id -g || true)}\""

	# Set up the VNC directory
	[[ -n "${VNC_USER_DIR:-}" ]] || _errexit "VNC directory \"${VNC_USER_DIR:-}\" is not set."
	[[ -d "${VNC_USER_DIR:-}" ]] || { mkdir -p "${VNC_USER_DIR}"; chmod -R 700 "${VNC_USER_DIR}"; }
	[[ -w "${VNC_USER_DIR}" ]] || _errexit "VNC directory \"${VNC_USER_DIR}\" is not writable."
	_verrecho "\$VNC_USER_DIR=\"${VNC_USER_DIR}\""

	# Set up the VNC password
	if ! [[ -r "${VNC_USER_DIR}/passwd" ]]; then
		echo "${VNC_PASSWORD:-}" | vncpasswd -f >"${VNC_USER_DIR}/passwd" && chmod 600 "${VNC_USER_DIR}/passwd"
		_verrecho "Set VNC password to \"${VNC_PASSWORD:-}\""
	fi

	# Set up the hostname
	hostname="${hostname:-${HOST}}"
	echo "${hostname}" >"${VNC_USER_DIR}/hostname"
	_verrecho "Set hostname to \"${hostname}\""
	printenv >|"${VNC_USER_DIR}/environment"

	# Set port or socket:
	if [[ -n "${VNC_PORT:-}" ]]; then
		# Validate port:
		if ! { [[ "${VNC_PORT}" =~ ^[0-9]+$ ]] && [[ "${VNC_PORT}" -lt 1 ]] && [[ "${VNC_PORT}" -gt 65535 ]]; }; then
			_errexit "VNC port \"${VNC_PORT}\" is invalid."
		fi

		set -- -rfbport "${VNC_PORT}" "${@}"
		echo "${VNC_PORT}" >"${VNC_USER_DIR}/port"
		unset VNC_SOCKET
	elif [[ -n "${VNC_SOCKET:-}" ]]; then
		set -- -rfbunixpath "${VNC_SOCKET}" "${@}"
	fi

	# Set other arguments:
	[[ -n "${VNC_FG:-}" ]] && set -- -fg "${@}"
	[[ -n "${VNC_LOG:-}" ]] && set -- -log "${VNC_LOG}" "${@}"
	[[ -n "${VNC_DISPLAY:-}" ]] && set -- "${VNC_DISPLAY}" "${@}"

	[[ -n "${!VNC_@}" ]] && export "${!VNC_@}"
	[[ -n "${TVNC_WM:-}" ]] && export TVNC_WM="${TVNC_WM}"

	_verrecho "Starting vncserver with arguments \"${*}\""
	vncserver "${@}"
}

(return 0 2>/dev/null) || run_hyakvnc_vncserver "$@"
