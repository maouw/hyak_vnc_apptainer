#!/usr/bin/env bash
# shellcheck shell=bash

[[ "${XDEBUG:-}" = "1" ]] && set -o xtrace
set -o errtrace -o errexit -o nounset -o pipefail
shopt -qs lastpipe inherit_errexit

PROGNAME="${0##*/}"
VERBOSE="${VERBOSE:-0}"

function _errecho() {
	case "${1:-}" in
		--verbose)
			shift
			[[ "${VERBOSE:-0}" == 0 ]] && return 0
			;;
		*) ;;
	esac
	printf "[%s] %s\n" "${PROGNAME:-$0}" "$*" >&2 || true
	return 0
}

function _cleanup_vncserver() {
	[[ -n "${VNC_SOCKET:-}" ]] && [[ -S "${VNC_SOCKET}" ]] && { rm -rfv "${VNC_SOCKET}" 2>/dev/null || true; }
	[[ -n "${VNC_USER_DIR:-}" ]] && [[ -d "${VNC_USER_DIR}" ]] && { rm -rfv "${VNC_USER_DIR}"/*.{pid,udspath,uds} "${VNC_USER_DIR}"/passwd 2>/dev/null || true; }
	return 0
}

function _errexit() {
	local status
	status="${?:-1}"
	echo >&2 "[${0##*/}:L${BASH_LINENO[0]:-?}]  Command \"${BASH_COMMAND[*]:-}\" failed with status ${status:-?}. Exiting." || true
	[[ "${_ERR_WRITE_LOG:-0}" == 1 ]] && [[ -n "${VNC_LOG:-}" ]] && [[ -f "${VNC_LOG}" ]] && { tail -v "${VNC_LOG}" | sed -E "s/^/${PROGNAME}: /" >&2 && echo >&2 "${PROGNAME}: End of log"; }
	exit 1
}

function show_help() {
	cat <<EOF
Usage: ${0} [options] -- <vncserver args>
  --password <password>  Set the VNC password (default: password)
  --display <display>    Set the VNC display (default: :10)	
  --user-dir <dir>       Set the VNC directory (default: /tmp/${USER}-vnc)
  --log-file <file>      Set the VNC log file (default: "${VNC_USER_DIR}/vnc.log")
  --socket <socket>      Set the VNC Unix socket (default: ${VNC_USER_DIR}/socket.uds)
  --port <port>          Set the VNC port (default: unset, use Unix socket)
  --foreground | --fg    Run in the foreground (default)
  --background | --bg    Run in the background
  --wm <wm>              Set the window manager (default: xfce)
  --verbose	             Verbose output
  --debug                Debug output
  --help | -h            Print this help message
  -- <vncserver args>    Pass any additional arguments to vncserver
						 (e.g. -geometry 1920x1080)
EOF
}

function main() {
	local hostname="${HOST:-}"
	echo "$@"
	# Parse arguments:
	while (($# > 0)); do
		case ${1:-} in
			--?*=* | -?*=*) # Handle --flag=value args
				set -- "${1%%=*}" "${1#*=}" "${@:2}"
				continue
				;;
			--trace)
				set -o xtrace
				;;
			--verbose)
				export VERBOSE=1
				;;
			-h | --help)
				show_help
				return 0
				;;
			--password)
				shift || { log ERROR "$1 requires an argument"; return 1; }
				export VNC_PASSWORD="${1:-}"
				;;
			--display)
				shift || { log ERROR "$1 requires an argument"; return 1; }
				export VNC_DISPLAY="$1"
				;;
			--user-dir)
				shift || { log ERROR "$1 requires an argument"; return 1; }
				export VNC_USER_DIR="$1"
				;;
			--log-file)
				shift || { log ERROR "$1 requires an argument"; return 1; }
				export VNC_LOG="$1"
				;;
			--socket)
				shift || { log ERROR "$1 requires an argument"; return 1; }
				export VNC_SOCKET="$1"
				;;
			--port)
				shift || { log ERROR "$1 requires an argument"; return 1; }
				export VNC_PORT="$1"
				unset VNC_SOCKET
				;;
			--foreground | --fg)
				export VNC_FG=1
				;;
			--background | --bg)
				export VNC_FG=0
				;;
			--wm)
				shift || { log ERROR "$1 requires an argument"; return 1; }
				export TVNC_WM="$1"
				;;
			--)
				shift
				break
				;;
			*)
				break
				;;
		esac
		shift
	done
	export TVNC_WM=${TVNC_WM:-xfce}
	export VNC_PASSWORD="${VNC_PASSWORD:-password}"
	export VNC_DISPLAY="${VNC_DISPLAY:-:10}"
	export VNC_USER_DIR="${VNC_USER_DIR:-/tmp/${USER}-vnc}"
	export VNC_FG="${VNC_FG:-1}"
	export VNC_LOG="${VNC_LOG:-${VNC_USER_DIR}/vnc.log}"
	export VNC_SOCKET="${VNC_SOCKET:-${VNC_USER_DIR}/socket.uds}"

	trap _errexit ERR
	_errecho --verbose "Running as \"${USER:-$(id -un || true)}\" with UID \"${UID:-$(id -u || true)}\" and GID \"${GID:-$(id -g || true)}\""

	# Set up the VNC directory
	[[ -n "${VNC_USER_DIR:-}" ]] || _errexit "VNC directory \"${VNC_USER_DIR:-}\" is not set."
	[[ -d "${VNC_USER_DIR:-}" ]] || mkdir -p -m 700 "${VNC_USER_DIR}"
	[[ -w "${VNC_USER_DIR}" ]] || _errexit "VNC directory \"${VNC_USER_DIR}\" is not writable."
	_errecho --verbose "\$VNC_USER_DIR=\"${VNC_USER_DIR}\""

	echo "${VNC_PASSWORD:-}" | vncpasswd -f >"${VNC_USER_DIR}/passwd"
	chmod 600 "${VNC_USER_DIR}/passwd"
	_errecho --verbose "Set VNC password to \"${VNC_PASSWORD:-}\""

	[[ -n "${hostname:-}" ]] || hostname="$(uname -n)" || hostname="${HOST:-}" || _errecho "Could not determine hostname."
	[[ -n "${hostname:-}" ]] && echo "${hostname}" >"${VNC_USER_DIR}/hostname"
	_errecho --verbose "Set hostname to \"${hostname}\""
	printenv >"${VNC_USER_DIR}/environment"

	# Set up the vncserver arguments
	if [[ -n "${VNC_PORT:-}" ]]; then
		set -- -rfbport "${VNC_PORT}" "${@}"
		echo "${VNC_PORT}" >"${VNC_USER_DIR}/port"
	elif [[ -n "${VNC_SOCKET:-}" ]]; then
		set -- -rfbunixpath "${VNC_SOCKET}" "${@}"
	fi
	[[ -n "${VNC_FG:-}" ]] && set -- -fg "${@}"
	[[ -n "${VNC_LOG:-}" ]] && set -- -log "${VNC_LOG}" "${@}"
	[[ -n "${VNC_DISPLAY:-}" ]] && set -- "${VNC_DISPLAY}" "${@}" 

	_errecho --verbose "Starting vncserver with arguments \"${*}\""
	_ERR_WRITE_LOG=1
	trap 'trap - INT TSTP EXIT; _cleanup_vncserver' INT TSTP EXIT
	vncserver "${@}"
	_errecho "Exiting ${PROGNAME:-$0}"
	_cleanup_vncserver
	return 0
}

main "${@}"
