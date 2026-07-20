#!/bin/bash

BIDS_ROOT="/gscratch/scrubbed/fanglab/xiaoqian/IFOCUS/sourcedata/nii"
ANAT_MODE="${ANAT_MODE:-defaced}"

case "${ANAT_MODE}" in
    defaced|original) ;;
    *)
        echo "Error: ANAT_MODE must be 'defaced' or 'original' (got '${ANAT_MODE}')"
        exit 1
        ;;
esac

# Create a list of all session directories
# Format: sub-XXX/ses-YYY
SESSIONS=($(find "${BIDS_ROOT}" -maxdepth 2 -type d -name "ses-*" | sed "s|$BIDS_ROOT/||" | sort))

NUM_SESSIONS=${#SESSIONS[@]}

if [ "${NUM_SESSIONS}" -eq 0 ]; then
    echo "No sessions found. Checking for subjects only..."
    SESSIONS=($(find "${BIDS_ROOT}" -maxdepth 1 -type d -name "sub-*" | sed "s|$BIDS_ROOT/||" | sort))
    NUM_SESSIONS=${#SESSIONS[@]}
fi

if [ "${NUM_SESSIONS}" -eq 0 ]; then
    echo "No data found in ${BIDS_ROOT}"
    exit 1
fi

echo "Found ${NUM_SESSIONS} targets. Submitting array 0-$((NUM_SESSIONS - 1))..."
echo "Anatomical input mode: ${ANAT_MODE}"

sbatch --array=0-$((NUM_SESSIONS - 1)) --export=ALL,ANAT_MODE="${ANAT_MODE}" recon_all.sbatch
