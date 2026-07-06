#!/bin/bash

# Path to your source data
DATA_DIR="/gscratch/scrubbed/fanglab/xiaoqian/IFOCUS/sourcedata/nii"

# Check if a specific subject ID was passed as an argument
if [ -n "$1" ]; then
  # Strip "sub-" prefix if the user included it, to keep consistency
  TARGET_SUB=$(echo "$1" | sed 's/sub-//g')
  
  # Verify the subject directory actually exists
  if [ ! -d "${DATA_DIR}/sub-${TARGET_SUB}" ]; then
    echo "Error: Subject directory sub-${TARGET_SUB} not found in ${DATA_DIR}"
    exit 1
  fi
  
  echo "Submitting single job for subject: sub-${TARGET_SUB}"
  
  # Submit a single job, passing the subject ID directly as an environment variable
  sbatch --export=ALL,SINGLE_SUB="${TARGET_SUB}" mriqc_job.sh

else
  # Default behavior: Calculate number of all subjects for an array job
  SUBJECTS=($(find "$DATA_DIR" -maxdepth 1 -type d -name "sub-*" -exec basename {} \; | sed 's/sub-//g' | sort))
  N=$((${#SUBJECTS[@]} - 1))

  if [ $N -lt 0 ]; then
    echo "Error: No subjects found in $DATA_DIR"
    exit 1
  fi

  echo "Submitting array jobs for $((N + 1)) subjects: ${SUBJECTS[@]}"

  # Submit the job with dynamic array
  sbatch --array=0-$N mriqc_job.sh
fi
