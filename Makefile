SHELL := /bin/bash
.SHELLFLAGS := -e -O xpg_echo -o errtrace -o functrace -c
MAKEFLAGS += --no-builtin-rules
MAKEFLAGS += --no-builtin-variables
MAKE := $(make)
DATETIME_FORMAT := %(%Y-%m-%d %H:%M:%S)T
.ONESHELL:
.SUFFIXES:
.DELETE_ON_ERROR:

# Where to store built containers:
CONTAINERDIR := $(PWD)/sif

# Make sure CONTAINERDIR exists:
$(CONTAINERDIR):
	@mkdir -p $@


# Make targets for each directory that contains a Singularity file
# (allows you to build a single container with `make <container_name>`):
SUBDIRS := $(patsubst def/%/Singularity,%,$(wildcard def/*/Singularity))
.PHONY: $(SUBDIRS)
$(SUBDIRS): %: ${CONTAINERDIR}/%.sif

# Build target for each container:
${CONTAINERDIR}/%.sif: def/%/Singularity bin/write-apptainer-labels.sh | $(CONTAINERDIR)
ifeq (, $(shell command -v apptainer 2>/dev/null))
	$(error "No apptainer in $(PATH). If you're on klone, you should be on a compute node")
endif
	pushd $(<D)
	apptainer build --force --fix-perms --warn-unused-build-args $@ $(<F)
	popd

# Targets for printing help:
.PHONY: help
help:  ## Prints this usage.
	@printf '== Recipes ==\n' && grep --no-filename -E '^[a-zA-Z0-9-]+:' $(MAKEFILE_LIST) && echo '\n== Images ==' && echo $(SUBDIRS) | tr ' ' '\n' 
# see https://www.gnu.org/software/make/manual/html_node/Origin-Function.html
MAKEFILE_ORIGINS := \
	default \
	environment \
	environment\ override \
	file \
	command\ line \
	override \
	automatic \
	\%

PRINTVARS_MAKEFILE_ORIGINS_TARGETS += \
	$(patsubst %,printvars/%,$(MAKEFILE_ORIGINS)) \

.PHONY: $(PRINTVARS_MAKEFILE_ORIGINS_TARGETS)
$(PRINTVARS_MAKEFILE_ORIGINS_TARGETS):
	@$(foreach V, $(sort $(.VARIABLES)), \
		$(if $(filter $(@:printvars/%=%), $(origin $V)), \
			$(info $V=$($V) ($(value $V)))))

.PHONY: printvars
printvars: printvars/file ## Print all Makefile variables (file origin).

.PHONY: printvar-%
printvar-%: ## Print one Makefile variable.
	@echo '($*)'
	@echo '  origin = $(origin $*)'
	@echo '  flavor = $(flavor $*)'
	@echo '   value = $(value  $*)'


.PHONY: clean-containers
clean-all: clean ## Remove all built images
	rm -rfv sif/

.PHONY: clean-downloads
clean-downloads: ## Remove all downloaded files.
	rm -rfv .setup-downloads/*

.PHONY: clean
clean-all: clean-containers clean-downloads ## Remove all built containers, all built images, and all downloaded files.

.DEFAULT_GOAL := help


$(CONTAINERDIR)/hyakvnc-vncserver-ubuntu22.04.sif:: def/hyakvnc-vncserver-ubuntu22.04/hyakvnc-vncserver.sh $(shell find ./common/configs/ubuntu)
$(CONTAINERDIR)/hyakvnc-freesurfer-ubuntu22.04.sif:: sif/hyakvnc-vncserver-ubuntu22.04.sif $(shell find ./common/configs/freesurfer)
$(CONTAINERDIR)/hyakvnc-freesurfer-matlab-ubuntu22.04.sif:: sif/hyakvnc-freesurfer-ubuntu22.04.sif
