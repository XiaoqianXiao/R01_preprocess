#!/bin/bash
BIDS_ROOT=/gscratch/scrubbed/fanglab/xiaoqian/IFOCUS/sourcedata/nii
mkdir -p logs

# Count subjects
NUM_SUBJ=$(find "${BIDS_ROOT}" -maxdepth 1 -type d -name "sub-*" | wc -l)
ARRAY_LIMIT=$((NUM_SUBJ - 1))

echo "Found ${NUM_SUBJ} subjects. Submitting FreeSurfer recon-all..."
sbatch --array=0-${ARRAY_LIMIT} recon_all.sbatch
