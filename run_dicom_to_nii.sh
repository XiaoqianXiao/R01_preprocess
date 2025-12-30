#!/bin/bash
set -euo pipefail

# ----------------------------
# Paths (EDIT ONLY IF NEEDED)
# ----------------------------
HEUDICONV_IMG=/gscratch/scrubbed/fanglab/xiaoqian/containers/heudiconv.sif
DICOM_ROOT=/gscratch/fang/IFOCUS/sourcedata/dicom
BIDS_ROOT=/gscratch/fang/IFOCUS/sourcedata/nii
HEURISTIC=/gscratch/scrubbed/fanglab/xiaoqian/repo/R01_preprocess/heuristic_reproin_like.py
SESSION=pilotTR1500

# ----------------------------
# One-time container pull
# ----------------------------
if [ ! -f "$HEUDICONV_IMG" ]; then
    apptainer pull "$HEUDICONV_IMG" docker://nipy/heudiconv:latest
fi

# ----------------------------
# Create output directory
# ----------------------------
mkdir -p "$BIDS_ROOT"

# ----------------------------
# Loop over subjects safely
# ----------------------------
for subjdir in "$DICOM_ROOT"/*; do
    subj=$(basename "$subjdir")

    # skip non-directories
    [ -d "$subjdir" ] || continue

    echo "========================================"
    echo "Processing subject: $subj"
    echo "========================================"

    apptainer run --cleanenv \
      -B "$DICOM_ROOT":/dicom \
      -B "$BIDS_ROOT":/bids \
      -B "$HEURISTIC":/heuristic.py \
      "$HEUDICONV_IMG" \
      heudiconv \
        -d /dicom/{subject}/ses-{session}/*/*dcm \
        -s "$subj" \
        -ss "$SESSION" \
        -f /heuristic.py \
        -c dcm2niix \
        -b \
        -o /bids

done

echo "All subjects processed."
