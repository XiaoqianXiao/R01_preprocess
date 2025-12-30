#!/bin/bash
set -euo pipefail

# ----------------------------
# Apptainer temp/cache
# ----------------------------
export APPTAINER_TMPDIR=/gscratch/scrubbed/fanglab/xiaoqian/apptainer/tmp
export APPTAINER_CACHEDIR=/gscratch/scrubbed/fanglab/xiaoqian/apptainer/cache
export TMPDIR=/gscratch/scrubbed/fanglab/xiaoqian/apptainer/tmp

mkdir -p "$APPTAINER_TMPDIR" "$APPTAINER_CACHEDIR"
mkdir -p /gscratch/scrubbed/fanglab/xiaoqian/containers

# ----------------------------
# Paths
# ----------------------------
HEUDICONV_IMG=/gscratch/scrubbed/fanglab/xiaoqian/containers/heudiconv.sif
DICOM_ROOT=/gscratch/fang/IFOCUS/sourcedata/dicom
BIDS_ROOT=/gscratch/fang/IFOCUS/sourcedata/nii
HEURISTIC=/gscratch/scrubbed/fanglab/xiaoqian/repo/R01_preprocess/heuristic_reproin_like.py
SESSION=pilotTR1500

# ----------------------------
# Pull container (once)
# ----------------------------
if [ ! -f "$HEUDICONV_IMG" ]; then
    apptainer pull "$HEUDICONV_IMG" docker://nipy/heudiconv:latest
fi

mkdir -p "$BIDS_ROOT"

# ----------------------------
# Loop subjects
# ----------------------------
for subjdir in "$DICOM_ROOT"/*; do
    subj=$(basename "$subjdir")
    [ -d "$subjdir" ] || continue

    echo "========================================"
    echo "Processing subject: $subj"
    echo "========================================"

    apptainer run --cleanenv \
      -B "$DICOM_ROOT":/dicom \
      -B "$BIDS_ROOT":/bids \
      -B "$HEURISTIC":/heuristic.py \
      "$HEUDICONV_IMG" \
        -d /dicom/{subject}/ses-{session}/*/*dcm \
        -s "$subj" \
        -ss "$SESSION" \
        -f /heuristic.py \
        -c dcm2niix \
        -b \
        -o /bids
done

echo "All subjects processed."
