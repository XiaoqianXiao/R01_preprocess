#!/usr/bin/env bash
set -euo pipefail

############################
# User configuration
############################

HEUDICONV_SIF=/gscratch/scrubbed/fanglab/xiaoqian/containers/heudiconv.sif
HEURISTIC=/gscratch/scrubbed/fanglab/xiaoqian/repo/R01_preprocess/heuristic_reproin_like.py

DICOM_ROOT=/gscratch/fang/IFOCUS/sourcedata/dicom
BIDS_ROOT=/gscratch/fang/IFOCUS/sourcedata/nii

############################
# Safety checks
############################

mkdir -p "${BIDS_ROOT}"

if [[ ! -f "${HEUDICONV_SIF}" ]]; then
  echo "ERROR: heudiconv.sif not found:"
  echo "  ${HEUDICONV_SIF}"
  exit 1
fi

############################
# Main loop
############################

for SUBJ_PATH in "${DICOM_ROOT}"/*; do
  SUBJ=$(basename "${SUBJ_PATH}")

  # Only process directories
  [[ -d "${SUBJ_PATH}" ]] || continue

  # Skip non-subject folders (extra safety)
  if [[ ! "${SUBJ}" =~ ^[0-9]+$ ]]; then
    echo "Skipping non-numeric subject folder: ${SUBJ}"
    continue
  fi

  # Check for at least one ses-* directory
  if ! ls "${SUBJ_PATH}"/ses-* >/dev/null 2>&1; then
    echo "Skipping ${SUBJ}: no ses-* directories found"
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
      -d /dicom/{subject}/{session}/*/*.dcm \
      -s "${SUBJ}" \
      -f "${HEURISTIC}" \
      -c dcm2niix \
      -b \
      -o /bids \
      --overwrite

done

echo "========================================"
echo "All subjects processed"
echo "========================================"
