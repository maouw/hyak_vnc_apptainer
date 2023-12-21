#!/usr/bin/env bash
# shellcheck shell=bash

[[ "${XDEBUG:-}" = "1" ]] && set -o xtrace
set -o errtrace -o nounset -o pipefail
shopt -qs lastpipe inherit_errexit

PROGNAME="${0##*/}"
VERBOSE="${VERBOSE:-0}"
PROG_VERSION="0.0.1"
SCRIPTDIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" || true
NEURODOCKER_IMAGE_TAG="master"
NEURODOCKER_IMAGE="repronim/neurodocker:${NEURODOCKER_IMAGE_TAG}"
NEURODOCKER_RUNNER="${NEURODOCKER_RUNNER:-apptainer}"
NEURODOCKER_TEMPLATE_PATH="${NEURODOCKER_TEMPLATE_PATH:-}"
NEURODOCKER_GENERATE_FORMAT="${NEURODOCKER_GENERATE_FORMAT:-apptainer}"


function _errecho() {
	[[ "${1:-}" == "--verbose" ]] && { shift; [[ "${VERBOSE:-0}" == 0 ]] && return 0; }
	printf >&2 "[%b] %b\n" "${PROGNAME}" "$*" || true
	return 0
}

function _errexit() {
	local status="${1:-}"
	printf >&2 "[%s:L%s]  Command \"%b\" failed with status %b.\n" "${PROGNAME}" "${BASH_LINENO[0]:-?}" "${BASH_COMMAND[0]:-}" "${status:-"?"}" || true
	exit "${status:-1}"
}

function show_help() {
	expand -t 4 <<EOF
Wrapper to generate container recipes with neurodocker

Usage: ${PROGNAME} [options] -- <neurodocker args>
	Options:
		--generate=<format>		Generate a Dockerfile or Apptainer/Singularity recipe
									(default: apptainer, options: dockerfile, apptainer, singularity)
		--base-image=<url|name>	Set the base image (default: docker://ubuntu:22.04.
									Unless --bootstrap is set, a URL is required and the scheme will be used to
									determine the bootstrap type.)
		--bootstrap=<type>		(Apptainer only) Set the bootstrap type (default: determed by --base-image)
		--write-build-labels	Generate build labels for Apptainer automatically
		--no-nd-base-fix		Do not correct the "base_image" key in the generated output
									neurodocker limitation as of 0.9.5)
		--output=<file>			Set the output file instead of printing to stdout
		--neurodocker-runner	Set the neurodocker runner to use
									(default: first of apptainer or docker, options: apptainer, singularity, docker)
		--neurodocker-image		Set the neurodocker runner image to use
		--template-path			Set the path to the neurodocker templates (optional)
		--verbose				Verbose output
		--trace					Trace output
		--help | -h				Print this help message
		--version				Print the version of this script
		-- <neurodocker args>	Pass any additional arguments to neurodocker
									(e.g. --label)

Description:
	This script is a wrapper to generate container recipes with neurodocker.
	The reason for this wrapper is that neurodocker does not support all of the
	Apptainer/Singularity recipe format (e.g. bootstrap from a local image).
	Therefore, this script will run neurodocker and then fix the output to
	produce a valid Apptainer/Singularity recipe.

Examples:
	# Generate an Apptainer recipe from a local image and add \`jq\`:
	$ ${PROGNAME} --generate=apptainer --base-image=localimage://foo.sif \
		--output foo-with-jq.def -- --pkg-manager=apt --jq --version=1.6
EOF
}

function main() {
	local bootstrap_type base_image_url base_image_schema base_image
	local -i no_nd_base_fix=0
	local output_file

	local -i write_build_labels=0
	# Parse arguments:
	(($# == 0)) && { show_help; return 0; }
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
			--version) echo "${PROGNAME} version ${PROG_VERSION:-}"; return 0 ;;
			--generate)
				shift || { _errecho "$1 requires an argument"; return 1; }
				case "${1:-}" in
					apptainer | singularity)
						NEURODOCKER_GENERATE_FORMAT="apptainer"
						;;
					docker)
						NEURODOCKER_GENERATE_FORMAT="dockerfile"
						;;
					*)
						_errecho "Invalid generate format \"${1:-}\". Must be one of \"dockerfile\", \"apptainer\", or \"singularity\"."
						return 1
						;;
				esac
				;;
			--template-path)
				shift || { _errecho "$1 requires an argument"; return 1; }
				NEURODOCKER_TEMPLATE_PATH="${1:-}"
				[[ -n "${NEURODOCKER_TEMPLATE_PATH:-}" ]] || [[ -d "${NEURODOCKER_TEMPLATE_PATH:-}" ]] || { _errecho "No directory at \"${NEURODOCKER_TEMPLATE_PATH:-}\". Exiting."; return 1; }
				;;
			--base-image) # Set the base image
				shift || { _errecho "$1 requires an argument"; return 1; }
				base_image_url="${1:-}"
				;;
			--bootstrap) # Set the bootstrap type
				shift || { _errecho "$1 requires an argument"; return 1; }
				bootstrap_type="${1:-}"
				;;
			--write-build-labels)
				write_build_labels=1
				;;
			--no-nd-base-fix)
				no_nd_base_fix=1
				;;
			--output) # Set the output files
				shift || { _errecho "$1 requires an argument"; return 1; }
				output_file="${1:-}"
				mkdir -p "$(dirname "${output_file}")" || { _errecho "Could not create directory \"$(dirname "${output_file}")\". Exiting."; return 1; }
				;;
			--neurodocker-runner-image) # Set the neurodocker runner image to use
				shift || { _errecho "$1 requires an argument"; return 1; }
				NEURODOCKER_IMAGE="${1:-}"
				;;
			--neurodocker-runner) # Set the neurodocker runner to use
				shift || { _errecho "$1 requires an argument"; return 1; }
				case "${1:-}" in
					apptainer | singularity | docker | neurodocker)
						NEURODOCKER_RUNNER="${1:-}"
						;;
					*)
						_errecho "Invalid neurodocker runner \"${1:-}\". Must be one of \"apptainer\", \"singularity\", or \"docker\"."
						return 1
						;;
				esac
				;;
			--)
				shift
				break
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
	trap _errexit ERR

	# Check required arguments:
	if [[ -z "${base_image_url:-}" ]]; then
		_errecho "Must specify a base image with --base-image"
		return 1
	fi

	# Set the base image schema for 'Bootstrap:' and 'From:' in the generated output:
	case "${base_image_url}" in
		*://*)
			base_image_schema="${base_image_url%%://*}"
			base_image="${base_image_url#*://}"
			;;

		*)
			base_image_schema="docker"
			_errecho "No schema specified for \"${base_image_url}\". Assuming \"${base_image_schema}\"."
			;;
	esac

	# Set the bootstrap type for 'Bootstrap:' in the generated output:
	case "${base_image_schema}" in
		library | oras | docker | shub)
			bootstrap_type="${bootstrap_type:-${base_image_schema}}"
			;;
		localimage | file)
			bootstrap_type="${bootstrap_type:-localimage}"
			[[ -n "${base_image:-}" ]] || [[ -f "${base_image}" ]] || { _errecho "No file at \"${base_image}\". Exiting."; return 1; }
			base_image="$(realpath --relative-to="$(dirname "${output_file:-}")" "${base_image}")"
			;;
		*)
			_errecho "Invalid schema \"${base_image_schema}\". Must be one of \"library\", \"oras\", \"docker\", \"shub\", \"localimage\", or \"file\"."
			return 1
			;;
	esac

	# Set the neurodocker runner:
	if ! command -v "${NEURODOCKER_RUNNER:=apptainer}" >/dev/null 2>&1; then
		_errecho "Could not find \"${1:-}\" in \$PATH. Will try to use first available of \"apptainer, singularity, docker, or neurodocker\"."
		for runner in apptainer singularity docker neurodocker; do
			if command -v "${runner}" >/dev/null 2>&1; then
				NEURODOCKER_RUNNER="${runner}"
				_errecho "Using \"${NEURODOCKER_RUNNER}\" as the neurodocker runner."
				break
			fi
		done
	fi

	if ! command -v "${NEURODOCKER_RUNNER}" >/dev/null 2>&1; then
		_errecho "Could not find \"${NEURODOCKER_RUNNER}\" in \$PATH. Exiting."
		return 1
	fi

	# Build the arguments for neurodocker:
	local -a neurodocker_args=()
	local -a neurodocker_runner_args=()

	case "${NEURODOCKER_RUNNER}" in
		apptainer | singularity)
			neurodocker_args+=(run)
			case "${NEURODOCKER_IMAGE:-}" in
				*://*) ;;

				*) NEURODOCKER_IMAGE="docker://${NEURODOCKER_IMAGE:-}" ;;
			esac
			neurodocker_args+=("${NEURODOCKER_IMAGE:-}")
			;;
		docker)
			neurodocker_args+=(run --rm)
			[[ -n "${NEURODOCKER_TEMPLATE_PATH:-}" ]] && neurodocker_args+=(--volume "${NEURODOCKER_TEMPLATE_PATH}:/templates")
			neurodocker_args+=("${NEURODOCKER_IMAGE:-}")
			[[ -n "${NEURODOCKER_TEMPLATE_PATH:-}" ]] && neurodocker_args+=(--volume "${NEURODOCKER_TEMPLATE_PATH}:/templates")
			;;
		*) ;;
	esac

	[[ "${NEURODOCKER_GENERATE_FORMAT}" == "apptainer" ]] && NEURODOCKER_GENERATE_FORMAT="singularity"
	neurodocker_args+=(generate)
	[[ -n "${NEURODOCKER_TEMPLATE_PATH:-}" ]] && neurodocker_args+=(--template-path "${NEURODOCKER_TEMPLATE_PATH}")
	neurodocker_args+=("${NEURODOCKER_GENERATE_FORMAT}")
	neurodocker_args+=(--base-image "${base_image}")

	# Add build labels if requested:
	if [[ "${NEURODOCKER_GENERATE_FORMAT}" == "singularity" ]] && [[ "${write_build_labels:-0}" == 1 ]] && [[ -w "$(dirname "${output_file:-}")" ]]; then
		[[ -x "${SCRIPTDIR}/write-apptainer-labels.sh" ]] || { _errecho "Could not find \"write-apptainer-labels.sh\" in \"${SCRIPTDIR}\". Exiting."; return 1; }
		"${SCRIPTDIR}/write-apptainer-labels.sh" >"$(dirname "${output_file}")"/build_labels || { _errecho "Could not write build labels. Exiting."; return 1; }
		neurodocker_args+=(--copy build_labels "/.build_labels")
	fi

	# If stdin is not a terminal, pass --yes to neurodocker to avoid interactive prompts:
	[[ -t 0 ]] || neurodocker_args+=(--yes)
	neurodocker_args+=("$@")

	# Run neurodocker:
	local res
	_errecho "Running neurodocker with the following arguments:\n${NEURODOCKER_RUNNER} ${neurodocker_runner_args[*]} ${neurodocker_args[*]}"
	res="$("${NEURODOCKER_RUNNER}" "${neurodocker_runner_args[@]}" "${neurodocker_args[@]}")" || { _errecho "neurodocker failed (exit code ${?})"; return 1; }
	[[ -z "${res:-}" ]] && { _errecho "neurodocker did not return any output. Exiting."; return 1; }

	# Fix the "base_image" key in the generated output:
	if [[ "${NEURODOCKER_GENERATE_FORMAT}" == "singularity" ]] && [[ "${no_nd_base_fix:-0}" == 0 ]]; then
		_errecho "Fixing the \"bootstrap:\" and  \"base_image\" keys in the generated output."
		res="$(echo "${res}" | sed -E 's/^\s*bootstrap:\s*docker.*$/bootstrap: '"${bootstrap_type}"'/Ig' || { _errecho "Could not fix the \"bootstrap\" key in the generated output."; })"
		res="$(echo "${res}" | sed -E 's#["]base_image["]\s*[:]\s*["][^"]*["]#"base_image": "'"${base_image_url}"'"#Ig')" || { _errecho "Could not fix the \"base_image\" key in the generated output."; }
	fi
	echo "${res}" >"${output_file:-/dev/stdout}"

	return 0
}

main "${@}"
