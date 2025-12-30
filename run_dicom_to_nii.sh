#!/usr/bin/env bash
set -euo pipefail

HEUDICONV_SIF=/gscratch/scrubbed/fanglab/xiaoqian/containers/heudiconv.sif
HEURISTIC=/gscratch/scrubbed/fanglab/xiaoqian/repo/R01_preprocess/heuristic_reproin_like.py

DICOM_ROOT=/gscratch/scrubbed/fanglab/xiaoqian/IFOCUS/sourcedata/dicom
BIDS_ROOT=/gscratch/scrubbed/fanglab/xiaoqian/IFOCUS/sourcedata/nii

mkdir -p "${BIDS_ROOT}"

echo "DICOM root : ${DICOM_ROOT}"
echo "BIDS root  : ${BIDS_ROOT}"

for SUBJ_PATH in "${DICOM_ROOT}"/*; do
  SUBJ=$(basename "${SUBJ_PATH}")
  [[ -d "${SUBJ_PATH}" ]] || continue

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
    -B "${HEURISTIC}:/heuristic.py:ro" \
    "${HEUDICONV_SIF}" \
    heudiconv \
      -d /dicom/{subject}/{session}/*/*/*.dcm \
      -s "${SUBJ}" \
      -f /heuristic.py \
      -c dcm2niix \
      -b \
      -o /bids \
      --overwrite

done

echo "All subjects finished."
