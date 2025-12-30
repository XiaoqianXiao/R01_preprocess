#!/usr/bin/env bash
set -euo pipefail

IMG=heudiconv.sif

DICOM_ROOT=/gscratch/fang/IFOCUS/sourcedata/dicom
BIDS_ROOT=/gscratch/fang/IFOCUS/bids
HEURISTIC=/gscratch/scrubbed/fanglab/xiaoqian/repo/R01_preprocess/heuristic_reproin_like.py

for subj in $(ls $DICOM_ROOT); do
  echo "========================================"
  echo "Processing subject: $subj"
  echo "========================================"

  apptainer exec \
    -B $DICOM_ROOT:/dicom \
    -B $BIDS_ROOT:/bids \
    -B $HEURISTIC:/heuristic.py \
    $IMG \
    heudiconv \
      -d /dicom/{subject}/ses-{session}/*/* \
      -s $subj \
      -ss pilotTR1500 \
      -f /heuristic.py \
      -c dcm2niix \
      -b \
      --overwrite \
      -o /bids
done