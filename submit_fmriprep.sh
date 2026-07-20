#!/bin/bash

# Define your BIDS directory
BIDS_ROOT="/gscratch/scrubbed/fanglab/xiaoqian/IFOCUS/sourcedata/nii"
ANAT_MODE="${ANAT_MODE:-defaced}"

case "${ANAT_MODE}" in
    defaced|original) ;;
    *)
        echo "Error: ANAT_MODE must be 'defaced' or 'original' (got '${ANAT_MODE}')"
        exit 1
        ;;
esac

# Create a directory for log files
mkdir -p logs

# --- Session-Level Identification ---
# Find all session directories (e.g., sub-001/ses-01)
# We sort them to ensure consistent array indexing
SESSIONS=($(find "${BIDS_ROOT}" -maxdepth 2 -type d -name "ses-*" | sed "s|$BIDS_ROOT/||" | sort))

NUM_SESSIONS=${#SESSIONS[@]}

# Fallback: Check if the dataset is single-session (no ses-* folders)
if [ "${NUM_SESSIONS}" -eq 0 ]; then
    echo "No ses-* directories found. Checking for subject-only directories..."
    SESSIONS=($(find "${BIDS_ROOT}" -maxdepth 1 -type d -name "sub-*" | sed "s|$BIDS_ROOT/||" | sort))
    NUM_SESSIONS=${#SESSIONS[@]}
fi

if [ "${NUM_SESSIONS}" -eq 0 ]; then
    echo "Error: No data found in ${BIDS_ROOT}"
    exit 1
fi

ARRAY_LIMIT=$((NUM_SESSIONS - 1))

echo "-----------------------------------------------------------"
echo "fMRIPrep Longitudinal Launcher"
echo "Found ${NUM_SESSIONS} targets (sessions/subjects)."
echo "Submitting array job for indices 0 to ${ARRAY_LIMIT}..."
echo "Anatomical input mode: ${ANAT_MODE}"
echo "-----------------------------------------------------------"

# Submit the array job
# The fmriprep.sbatch script will use SLURM_ARRAY_TASK_ID to pick the specific session
sbatch --array=0-${ARRAY_LIMIT} --export=ALL,ANAT_MODE="${ANAT_MODE}" fmriprep.sbatch
