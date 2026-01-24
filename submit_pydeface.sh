#!/bin/bash

# Define your BIDS directory
BIDS_ROOT="/gscratch/scrubbed/fanglab/xiaoqian/IFOCUS/sourcedata/nii"

# Create a directory for log files
mkdir -p logs

# --- Logic for Specific Sub/Ses ---
# Usage: ./submit_pydeface.sh [sub-ID] [ses-ID]
# Example: ./submit_pydeface.sh sub-001 ses-01

TARGET_SUB=$1
TARGET_SES=$2

if [ -n "$TARGET_SUB" ]; then
    echo "Running for specific subject: $TARGET_SUB"
    if [ -n "$TARGET_SES" ]; then
        echo "Limiting to session: $TARGET_SES"
    fi
    
    # Submit a single job instead of an array
    # We export the variables so the sbatch script can read them
    sbatch --export=ALL,TARGET_SUB="$TARGET_SUB",TARGET_SES="$TARGET_SES" \
           --job-name="pydeface_${TARGET_SUB}" \
           pydeface.sbatch
else
    # Default: Run for all subjects in an array
    SUBJECTS=($(find "${BIDS_ROOT}" -maxdepth 1 -type d -name "sub-*" -printf "%f\n" | sort))
    NUM_SUBJ=${#SUBJECTS[@]}
    ARRAY_LIMIT=$((NUM_SUBJ - 1))

    if [ "${NUM_SUBJ}" -eq 0 ]; then
        echo "No subject directories found in ${BIDS_ROOT}"
        exit 1
    fi

    echo "Found ${NUM_SUBJ} subjects. Submitting job array 0-${ARRAY_LIMIT}..."
    sbatch --array=0-${ARRAY_LIMIT} pydeface.sbatch
fi