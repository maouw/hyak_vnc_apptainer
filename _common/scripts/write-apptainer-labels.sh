#!/bin/sh
# shellcheck shell=sh

# %arguments
# IMAGE_TAG
# IMAGE_TITLE
# IMAGE_VERSION
# IMAGE_URL
# IMAGE_VCS_REF
# IMAGE_VCS_URL
# IMAGE_AUTHOR
# IMAGE_AUTHOR_EMAIL
# IMAGE_AUTHOR_NAME
# IMAGE_VENDOR
# IMAGE_DESCRIPTION
# IMAGE_DOCUMENTATION

write_to_build_labels() {
	[ -n "${APPTAINER_ROOTFS:-}" ] || return 1
	while [ $# -gt 1 ]; do
		eval "printf '%s %s\n' \"$1\" \"\${$#}\"" >>"${BUILD_LABELS_PATH:-/dev/stdout}"
		shift
	done
	return 0
}

write_apptainer_labels() {
	[ -n "${APPTAINER_ROOTFS:-}" ] || return 1
	BUILD_LABELS_PATH="${BUILD_LABELS_PATH:-${APPTAINER_ROOTFS:+${APPTAINER_ROOTFS}/.build.labels}}"
	#init_apptainer_label_args || return 1
	if command -v git >/dev/null 2>&1 && git tag 2>/dev/null; then
		IMAGE_VCS_URL="${IMAGE_VCS_URL:-$(git config --get remote.origin.url || true)}"
		[ -z "${IMAGE_URL:-}" ] && [ -n "${IMAGE_VCS_URL:-}" ] && IMAGE_URL="${IMAGE_VCS_URL%%.git}"
		IMAGE_VCS_REF="${IMAGE_VCS_REF:-$(git rev-parse --short HEAD || true)}"

		command -v sed >/dev/null 2>&1 && IMAGE_TAG="${IMAGE_TAG:-"$(git tag --points-at HEAD --list '*@*' --sort=-"creatordate:iso" | sed 's/.*@//;1q')"}"
	fi
	IMAGE_TAG="${IMAGE_TAG:-latest}"
	IMAGE_TITLE="${IMAGE_TITLE:-"${PWD##*/}"}"
	IMAGE_VERSION="${IMAGE_VERSION:-${IMAGE_TAG:-}}"


	if [ -z "${IMAGE_AUTHOR:-}" ] && command -v git >/dev/null 2>&1; then
		[ -n "${IMAGE_AUTHOR_EMAIL:-}" ] || IMAGE_AUTHOR_EMAIL="$(git config --get user.email || git config --get github.email || true)"
		[ -n "${IMAGE_AUTHOR_NAME:-}" ] || IMAGE_AUTHOR_NAME="$(git config --get user.name || git config --get github.user || true)"
		IMAGE_AUTHOR="${IMAGE_AUTHOR_NAME:+${IMAGE_AUTHOR_NAME} }<${IMAGE_AUTHOR_EMAIL:-}>"
	fi
	write_to_build_labels "org.label-schema.title" "org.opencontainers.image.title" "${IMAGE_TITLE:-}"
	write_to_build_labels "org.label-schema.version" "org.opencontainers.image.version" "${IMAGE_VERSION:-}"
	write_to_build_labels "org.label-schema.url" "org.opencontainers.image.url" "${IMAGE_URL:-}"
	write_to_build_labels "org.label-schema.vcs-ref" "org.opencontainers.image.revision" "${IMAGE_VCS_REF:-}"
	write_to_build_labels "org.label-schema.vcs-url" "org.opencontainers.image.source" "${IMAGE_VCS_URL:-}"
	write_to_build_labels "org.label-schema.vendor" "org.opencontainers.image.vendor" "${IMAGE_VENDOR:-}"
	write_to_build_labels "MAINTAINER" "org.opencontainers.image.authors" "${IMAGE_AUTHOR:-}"
	write_to_build_labels "org.label-schema.description" "org.opencontainers.image.description" "${IMAGE_DESCRIPTION:-}"
	write_to_build_labels "org.label-schema.usage" "org.opencontainers.image.documentation" "${IMAGE_DOCUMENTATION:-}"
}
