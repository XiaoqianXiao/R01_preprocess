#!/usr/bin/env bash
set -euo pipefail

############################
# User configuration
############################

HEUDICONV_SIF=/gscratch/scrubbed/fanglab/xiaoqian/containers/heudiconv.sif
HEURISTIC=/gscratch/scrubbed/fanglab/xiaoqian/repo/R01_preprocess/heuristic_reproin_like.py

DICOM_ROOT=/gscratch/scrubbed/fanglab/xiaoqian/IFOCUS/sourcedata/dicom
BIDS_ROOT=/gscratch/scrubbed/fanglab/xiaoqian/IFOCUS/sourcedata/nii

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


  # Check for at least one ses-* directory
  if ! ls "${SUBJ_PATH}"/ses-* >/dev/null 2>&1; then
    echo "Skipping ${SUBJ}: no ses-* directories found"
    continue
  fi

  echo "========================================"
  echo "Processing subject: ${SUBJ}"
  echo "========================================"

  # Unzip any .dicom.zip files in series directories
  for ses_path in "${SUBJ_PATH}"/ses-*; do
    [[ -d "${ses_path}" ]] || continue
    for series_path in "${ses_path}"/*; do
      [[ -d "${series_path}" ]] || continue
      for zipfile in "${series_path}"/*.dicom.zip; do
        if [[ -f "${zipfile}" ]]; then
          echo "Unzipping ${zipfile}"
          unzip -n "${zipfile}" -d "${series_path}"
        fi
      done
    done
  done

  # Diagnostic: List files in a sample series dir (pick first func-bold* if exists, else any)
  SAMPLE_SERIES=$(ls -d "${SUBJ_PATH}"/ses-*/func-bold* 2>/dev/null | head -1)
  if [[ -z "${SAMPLE_SERIES}" ]]; then
    SAMPLE_SERIES=$(ls -d "${SUBJ_PATH}"/ses-*/* 2>/dev/null | head -1)
  fi
  if [[ -n "${SAMPLE_SERIES}" ]]; then
    echo "Diagnostic: Recursive files in sample series ${SAMPLE_SERIES}:"
    ls -lR "${SAMPLE_SERIES}" | head -20
  else
    echo "Diagnostic: No series directories found"
  fi

  # Diagnostic: Count files that would match the glob
  FILE_COUNT=$(find "${SUBJ_PATH}"/ses-*/*/* -type f 2>/dev/null | wc -l)
  echo "Diagnostic: Total files in all nested series dirs: ${FILE_COUNT}"
  if [[ ${FILE_COUNT} -eq 0 ]]; then
    echo "Warning: No files found post-unzip; check zip contents manually with 'zipinfo <file.dicom.zip>'"
  fi

  apptainer exec \
    -B "${DICOM_ROOT}:/dicom:ro" \
    -B "${BIDS_ROOT}:/bids" \
    -B $HEURISTIC:/heuristic.py \
    "${HEUDICONV_SIF}" \
    heudiconv \
      -d /dicom/{subject}/{session}/*/*/* \
      -s "${SUBJ}" \
      -f /heuristic.py \
      -c dcm2niix \
      -b \
      -o /bids \
      --overwrite

done

echo "========================================"
echo "All subjects processed"
echo "========================================"