#!/usr/bin/env bash
set -eEux -o pipefail

ROOTDIR="$(git rev-parse --show-toplevel)"

"${ROOTDIR}"/bin/generate-neurodocker.sh --generate apptainer --template-path "${ROOTDIR}/common/neurodocker-templates" \
	--base-image "localimage://${ROOTDIR}/sif/hyakvnc-vncserver-ubuntu22.04.sif" --write-build-labels --output "./Singularity" \
	-- --pkg-manager apt \
	--freesurfer version=7.3.1 exclude_paths='[average/mult-comp-cor,subjects/V1_average,subjects/cvs_avg35,subjects/cvs_avg35_inMNI152,subjects/fsaverage3,subjects/fsaverage4,subjects/fsaverage5,subjects/fsaverage6,subjects/fsaverage_sym,trctrain]' \
	--freeviewlauncher desktop=true
