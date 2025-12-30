#!/bin/bash

# Define where your dicoms are
DICOM_ROOT=/gscratch/scrubbed/fanglab/xiaoqian/IFOCUS/sourcedata/dicom

# Create a logs directory
mkdir -p logs

# Count number of directories in DICOM_ROOT
# We subtract 1 because array indices start at 0
NUM_SUBJ=$(ls -d "${DICOM_ROOT}"/* | wc -l)
ARRAY_LIMIT=$((NUM_SUBJ - 1))

echo "Found ${NUM_SUBJ} subjects."
echo "Submitting job array for indices 0 to ${ARRAY_LIMIT} (unthrottled)..."

# Submit the job array without the % limit
sbatch --array=0-${ARRAY_LIMIT} heudiconv_job.sbatch