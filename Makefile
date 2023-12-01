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
CONTAINERDIR := $(or $(CONTAINERDIR), $(shell pwd))

# Make sure CONTAINERDIR exists:
$(CONTAINERDIR):
	@mkdir -pv $@

# Make targets for each directory that contains a Singularity file
# (allows you to build a single container with `make <container_name>`):
SUBDIRS := $(patsubst %/Singularity,%,$(wildcard */Singularity))
.PHONY: $(SUBDIRS)
$(SUBDIRS): %: ${CONTAINERDIR}/%.sif

# Build target for each container:
${CONTAINERDIR}/%.sif: %/Singularity | $(CONTAINERDIR)
ifeq (, $(shell command -v apptainer 2>/dev/null))
	$(error "No apptainer in $(PATH). If you're on klone, you should be on a compute node")
endif
	pushd $(<D)
	apptainer build --fakeroot --fix-perms --warn-unused-build-args --build-arg CONTAINERDIR="$(CONTAINERDIR)" $@ $(<F)
	popd
	[ -n "$$APPTAINER_PASSPHRASE" ] && echo "$$APPTAINER_PASSPHRASE" | apptainer sign $@


# Add dependencies for containers that depend on other containers:
$(CONTAINERDIR)/ubuntu22.04_turbovnc.sif:: $(CONTAINERDIR)/ubuntu22.04_interactive.sif
$(CONTAINERDIR)/ubuntu22.04_xubuntu.sif:: $(CONTAINERDIR)/ubuntu22.04_turbovnc.sif

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


.DEFAULT_GOAL := help


.PHONY:
push-image:
	apptainer push -U ubuntu22.04_turbovnc.sif oras://ghcr.io/maouw/ubuntu22.04_turbovnc 