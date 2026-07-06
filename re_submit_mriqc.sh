#!/bin/bash

# Path to your source data
DATA_DIR="/gscratch/scrubbed/fanglab/xiaoqian/IFOCUS/sourcedata/nii"

# Case 1: No arguments passed -> Submit ALL subjects via Slurm Array
if [ $# -eq 0 ]; then
  SUBJECTS=($(find "$DATA_DIR" -maxdepth 1 -type d -name "sub-*" -exec basename {} \; | sed 's/sub-//g' | sort))
  N=$((${#SUBJECTS[@]} - 1))

  if [ $N -lt 0 ]; then
    echo "Error: No subjects found in $DATA_DIR"
    exit 1
  fi

  echo "Submitting array jobs for ALL $((N + 1)) subjects..."
  sbatch --array=0-$N mriqc_job.sh

# Case 2: Specific subject(s) provided as arguments
else
  echo "Processing explicit subject list. Submitting individual jobs..."
  
  # Loop through all arguments provided to the script
  for ARG in "$@"; do
    # Strip "sub-" prefix if included, to keep naming consistent
    TARGET_SUB=$(echo "$ARG" | sed 's/sub-//g')
    
    # Verify the subject directory exists before submitting
    if [ -d "${DATA_DIR}/sub-${TARGET_SUB}" ]; then
      echo "-> Submitting job for subject: sub-${TARGET_SUB}"
      sbatch --export=ALL,SINGLE_SUB="${TARGET_SUB}" mriqc_job.sh
    else
      echo "-> [WARNING] Subject directory sub-${TARGET_SUB} not found in ${DATA_DIR}. Skipping."
    fi
  done
fi