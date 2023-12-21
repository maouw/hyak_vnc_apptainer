#!/usr/bin/env bash
# shellcheck shell=bash
[[ "${XDEBUG:-0}" =~ ^[1yYtT] ]] && set -x
set -o errtrace -o nounset -o pipefail
shopt -qs lastpipe inherit_errexit

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
export VNC_PASSWORD="${VNC_PASSWORD:-password}"
export VNC_DISPLAY="${VNC_DISPLAY:-:10}"
export VNC_USER_DIR="${VNC_USER_DIR:-/tmp/${USER}-vnc}"
export VNC_FG="${VNC_FG:-1}"
export VNC_LOG="${VNC_LOG:-${VNC_USER_DIR}/vnc.log}"
export VNC_SOCKET="${VNC_SOCKET:-${VNC_USER_DIR}/socket.uds}"
export VNC_PORT="${VNC_PORT:-}"

function _errecho() {
	[[ "${1:-}" == "--verbose" ]] && { shift; [[ "${VERBOSE:-0}" == 0 ]] && return 0; }
	printf >&2 "[%b] %b\n" "${PROGNAME}" "$*" || true
	return 0
}

function _errexit() {
	local status="${?:-}"
	_errecho "$@"
	exit "${status:-1}"
}

function _errhandler_() {
	local status="${?:-}"
	local msg=""
	[[ -n "${1:-}" ]] && msg=": $1"
	printf >&2 "[%s:L%s]  Command \"%b\" failed with status %b%b\n" "${PROGNAME}" "${BASH_LINENO[0]:-?}" "${BASH_COMMAND[0]:-}" "${status:-"?"}" "${msg:-}" || true
	exit "${status:-1}"
}

function _cleanup_vncserver() {
	[[ -n "${VNC_SOCKET:-}" ]] && [[ -S "${VNC_SOCKET}" ]] && { rm -rfv "${VNC_SOCKET}" 2>/dev/null || true; }
	[[ -n "${VNC_USER_DIR:-}" ]] && [[ -d "${VNC_USER_DIR}" ]] && { rm -rfv "${VNC_USER_DIR}"/*.{pid,udspath,uds} 2>/dev/null || true; }
	return 0
}

function _write_vnc_log() {
	[[ -n "${VNC_LOG:-}" ]] && [[ -f "${VNC_LOG}" ]] && { tail -v "${VNC_LOG}" | sed -E "s/^/${PROGNAME}: /" >&2 && echo >&2 "${PROGNAME}: End of log"; }
}

function show_help() {
	expand -t 4 <<EOF
Wrapper to run TurboVNC and XFCE in a container

Usage: ${PROGNAME} [options] -- <vncserver args>
	--password <password>	Set the VNC password (default: password)
	--display <display>		Set the VNC display (default: :10)	
	--user-dir <dir>		Set the VNC directory (default: /tmp/${USER}-vnc)
	--log-file <file>		Set the VNC _errecho file (default: "${VNC_USER_DIR}/vnc.log")
	--socket <socket>		Set the VNC Unix socket (default: ${VNC_USER_DIR}/socket.uds)
	--port <port>			Set the VNC port (default: unset, use Unix socket)
	--foreground | --fg		Run in the foreground (default)
	--background | --bg		Run in the background
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
		case ${1:-} in
			--?*=* | -?*=*) # Handle --flag=value args
				set -- "${1%%=*}" "${1#*=}" "${@:2}"
				continue
				;;
			--trace) set -o xtrace ;;
			--verbose) export VERBOSE=1 ;;
			-h | --help) show_help; return 0 ;;
			--version) echo "${PROGNAME} version ${PROG_VERSION:-}"; return 0 ;;
			--password)
				shift || { _errecho ERROR "$1 requires an argument"; return 1; }
				export VNC_PASSWORD="${1:-}"
				;;
			--display)
				shift || { _errecho ERROR "$1 requires an argument"; return 1; }
				export VNC_DISPLAY="$1"
				;;
			--user-dir)
				shift || { _errecho ERROR "$1 requires an argument"; return 1; }
				export VNC_USER_DIR="$1"
				;;
			--log-file)
				shift || { _errecho ERROR "$1 requires an argument"; return 1; }
				export VNC_LOG="$1"
				;;
			--socket)
				shift || { _errecho ERROR "$1 requires an argument"; return 1; }
				export VNC_SOCKET="$1"
				;;
			--port)
				shift || { _errecho ERROR "$1 requires an argument"; return 1; }
				export VNC_PORT="$1"
				unset VNC_SOCKET
				;;
			--foreground | --fg) export VNC_FG=1 ;;
			--background | --bg) export VNC_FG=0 ;;
			--wm)
				shift || { _errecho ERROR "$1 requires an argument"; return 1; }
				export TVNC_WM="$1"
				;;
			-? | --?*) # Handle unrecognized options
				_errecho "Unknown option \"${1:-}\""
				break
				;;
			*)
				_errecho "Unknown argument \"${1:-}\""
				break
				;;
		esac
		shift
	done

	# Trap errors:
	trap _errhandler_ ERR

	_errecho --verbose "Running as \"${USER:-$(id -un || true)}\" with UID \"${UID:-$(id -u || true)}\" and GID \"${GID:-$(id -g || true)}\""

	# Set up the VNC directory
	[[ -n "${VNC_USER_DIR:-}" ]] || _errexit "VNC directory \"${VNC_USER_DIR:-}\" is not set."
	[[ -d "${VNC_USER_DIR:-}" ]] || mkdir -p -m 700 "${VNC_USER_DIR}"
	[[ -w "${VNC_USER_DIR}" ]] || _errexit "VNC directory \"${VNC_USER_DIR}\" is not writable."
	_errecho --verbose "\$VNC_USER_DIR=\"${VNC_USER_DIR}\""

	echo "${VNC_PASSWORD:-}" | vncpasswd -f >"${VNC_USER_DIR}/passwd"
	chmod 600 "${VNC_USER_DIR}/passwd"
	_errecho --verbose "Set VNC password to \"${VNC_PASSWORD:-}\""

	local hostname
	[[ -n "${hostname:-}" ]] || hostname="$(uname -n)" || hostname="${HOST:-}" || _errexit "Could not determine hostname."
	[[ -n "${hostname:-}" ]] && echo "${hostname}" >"${VNC_USER_DIR}/hostname"
	_errecho --verbose "Set hostname to \"${hostname}\""
	printenv >"${VNC_USER_DIR}/environment"

	# Set port or socket:
	if [[ -n "${VNC_PORT:-}" ]]; then
		# Validate port:
		if ! { [[ "${VNC_PORT}" =~ ^[0-9]+$ ]] && [[ "${VNC_PORT}" -lt 1 ]] && [[ "${VNC_PORT}" -gt 65535 ]]; }; then
			_errexit --verbose "VNC port \"${VNC_PORT}\" is invalid."
		fi
		set -- -rfbport "${VNC_PORT}" "${@}"
		echo "${VNC_PORT}" >"${VNC_USER_DIR}/port"
	elif [[ -n "${VNC_SOCKET:-}" ]]; then
		set -- -rfbunixpath "${VNC_SOCKET}" "${@}"
	fi

	# Set other arguments:
	[[ -n "${VNC_FG:-}" ]] && set -- -fg "${@}"
	[[ -n "${VNC_LOG:-}" ]] && set -- -_errecho "${VNC_LOG}" "${@}"
	[[ -n "${VNC_DISPLAY:-}" ]] && set -- "${VNC_DISPLAY}" "${@}"

	[[ -n "${!VNC_@}" ]] && export "${!VNC_@}"
	[[ -n "${TVNC_WM:-}" ]] && export TVNC_WM="${TVNC_WM}"

	_ERR_WRITE_LOG=1 # Write _errecho on exit
	retval=0         # Declare retval for exit trap

	trap 'retval=$?; trap - EXIT; _cleanup_vncserver; _write_vnc_log; >&2 echo "${PROGNAME}: Exiting (status: ${retval:-0})"; exit ${retval:-0}' EXIT
	_errecho --verbose "Starting vncserver with arguments \"${*}\""
	vncserver "${@}"
}

! (return 0 2>/dev/null) || run_hyakvnc_vncserver "$@"
