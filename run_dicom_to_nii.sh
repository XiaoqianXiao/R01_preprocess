#!/usr/bin/env bash
set -euo pipefail

############################
# User configuration
############################

HEUDICONV_SIF=/gscratch/scrubbed/fanglab/xiaoqian/containers/heudiconv.sif
HEURISTIC=/gscratch/scrubbed/fanglab/xiaoqian/repo/R01_preprocess/heuristic_reproin_like.py

# Paths on Host
DICOM_INPUT=/gscratch/scrubbed/fanglab/xiaoqian/IFOCUS/sourcedata/dicom
BIDS_OUTPUT=/gscratch/scrubbed/fanglab/xiaoqian/IFOCUS/sourcedata/nii

############################
# Safety checks & Path Resolution
############################

mkdir -p "${BIDS_OUTPUT}"

############################
# Loop over subjects
############################

for SUBJ_PATH in "${DICOM_ROOT}"/*; do
  SUBJ=$(basename "${SUBJ_PATH}")

  [[ -d "${SUBJ_PATH}" ]] || continue

  # Only numeric subject IDs
  if [[ ! "${SUBJ}" =~ ^[0-9]+$ ]]; then
    echo "Skipping non-subject folder: ${SUBJ}"
    continue
  fi

  # Must contain ses-* directories
  if ! ls "${SUBJ_PATH}"/ses-* >/dev/null 2>&1; then
    echo "Skipping ${SUBJ}: no ses-* directories"
    continue
  fi

  echo "========================================"
  echo "Processing subject: ${SUBJ}"
  echo "========================================"

  singularity exec \
    -B "${DICOM_ROOT}:/dicom:ro" \
    -B "${BIDS_ROOT}:/bids" \
    "${HEUDICONV_SIF}" \
    heudiconv \
      -d /dicom/{subject}/{session}/*/*/*.dcm \
      -s "${SUBJ}" \
      -f "${HEURISTIC}" \
      -c dcm2niix \
      -b \
      -o /bids \
      --overwrite

done

echo "All subjects finished"