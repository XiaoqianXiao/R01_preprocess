#!/bin/bash

# Define your BIDS directory
BIDS_ROOT=/gscratch/scrubbed/fanglab/xiaoqian/IFOCUS/sourcedata/nii

# Create a directory for log files
mkdir -p logs

# Count the number of subject directories (sub-*)
NUM_SUBJ=$(find "${BIDS_ROOT}" -maxdepth 1 -type d -name "sub-*" | wc -l)
ARRAY_LIMIT=$((NUM_SUBJ - 1))

if [ "${NUM_SUBJ}" -eq 0 ]; then
    echo "No subject directories found in ${BIDS_ROOT}"
    exit 1
fi

echo "Found ${NUM_SUBJ} subjects."
echo "Submitting PyDeface job array for indices 0 to ${ARRAY_LIMIT}..."

# Submit the array job
# This launches one job per subject
sbatch --array=0-${ARRAY_LIMIT} pydeface.sbatch
