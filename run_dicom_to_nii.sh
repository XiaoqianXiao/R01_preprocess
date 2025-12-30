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
  [[ -d "${SUBJ_PATH}" ]] || continue
  SUBJ=$(basename "${SUBJ_PATH}")

  for SES_PATH in "${SUBJ_PATH}"/ses-*; do
    [[ -d "${SES_PATH}" ]] || continue
    SES=$(basename "${SES_PATH}" | sed 's/^ses-//')

    echo "========================================"
    echo "Processing subject: ${SUBJ}, session: ${SES}"
    echo "========================================"

    apptainer exec \
      -B "${DICOM_ROOT}:/dicom:ro" \
      -B "${BIDS_ROOT}:/bids" \
      -B "${HEURISTIC}:/heuristic.py:ro" \
      "${HEUDICONV_SIF}" \
      heudiconv \
        -d '/dicom/{subject}/ses-{session}/*/*/*.dcm' \
        -s "${SUBJ}" \
        -ss "${SES}" \
        -f /heuristic.py \
        -c dcm2niix \
        -b \
        -o /bids \
        --overwrite
  done
done
