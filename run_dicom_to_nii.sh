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

# Resolve Symlinks (Crucial for Hyak/Singularity)
# This converts /gscratch/... to /mmfs1/gscratch/... (or whatever the real path is)
DICOM_ROOT=$(realpath "${DICOM_INPUT}")
BIDS_ROOT=$(realpath "${BIDS_OUTPUT}")
HEURISTIC_REAL=$(realpath "${HEURISTIC}")

if [[ ! -f "${HEUDICONV_SIF}" ]]; then
  echo "ERROR: heudiconv.sif not found at: ${HEUDICONV_SIF}"
  exit 1
fi

echo "Detailed Path Info:"
echo "  DICOM Input (Physical): ${DICOM_ROOT}"
echo "  BIDS Output (Physical): ${BIDS_ROOT}"

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

  # --- DEBUG STEP: Verify container visibility ---
  # Now we check the EXACT path inside the container
  echo "DEBUG: Checking visibility inside container..."
  apptainer exec \
    -B "${DICOM_ROOT}" \
    "${HEUDICONV_SIF}" \
    ls -d "${SUBJ_PATH}/ses-"* | head -1 || echo "ERROR: Container still cannot see subject folder!"

  # --- HEUDICONV COMMAND ---
  # Updates:
  # 1. Binds the exact paths (no colon renaming)
  # 2. Uses the real full path in the -d template
  apptainer exec \
    -B "${DICOM_ROOT}" \
    -B "${BIDS_ROOT}" \
    -B "${HEURISTIC_REAL}:/heuristic.py" \
    "${HEUDICONV_SIF}" \
    heudiconv \
      -d "${DICOM_ROOT}/{subject}/{session}/*/*/*.dcm" \
      -s "${SUBJ}" \
      -f /heuristic.py \
      -c dcm2niix \
      -b \
      -o "${BIDS_ROOT}" \
      --overwrite

done

echo "========================================"
echo "All subjects processed"
echo "========================================"