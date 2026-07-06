#!/bin/bash
#SBATCH --job-name=mriqc_sub
#SBATCH --account=fang
#SBATCH --partition=ckpt-all
#SBATCH --qos=normal
#SBATCH --ntasks=4
#SBATCH --mem=32G
#SBATCH --time=12:00:00
#SBATCH --output=mriqc_%A_%a.out
#SBATCH --error=mriqc_%A_%a.err
#SBATCH --array=0-%N

module load apptainer
# 1. Determine Subject ID based on how the job was submitted
if [ -n "$SINGLE_SUB" ]; then
  # Submitted manually via explicit list loop
  SUBJECT="$SINGLE_SUB"
  echo "Running in SINGLE mode for subject: sub-${SUBJECT}"
elif [ -n "$SLURM_ARRAY_TASK_ID" ]; then
  # Submitted via original Slurm Job Array
  SUBJECTS=($(find /gscratch/scrubbed/fanglab/xiaoqian/IFOCUS/sourcedata/nii -maxdepth 1 -type d -name "sub-*" -exec basename {} \; | sed 's/sub-//g' | sort))
  SUBJECT=${SUBJECTS[$SLURM_ARRAY_TASK_ID]}
  echo "Running in ARRAY mode for index ${SLURM_ARRAY_TASK_ID}: sub-${SUBJECT}"
else
  echo "Error: Neither SINGLE_SUB nor SLURM_ARRAY_TASK_ID is set."
  exit 1
fi

# Double check if SUBJECT is valid
if [ -z "$SUBJECT" ]; then
  echo "Error: Subject variable is empty."
  exit 1
fi

# 2. Setup isolated host work directory to avoid multi-job race conditions
HOST_WORK_DIR="/gscratch/scrubbed/fanglab/xiaoqian/IFOCUS/derivatives/mriqc_work/sub-${SUBJECT}"
mkdir -p "$HOST_WORK_DIR"

# 3. Execute Apptainer with isolated work directory binding
apptainer run \
  --cleanenv \
  -B /gscratch/scrubbed/fanglab/xiaoqian/IFOCUS/sourcedata/nii:/data \
  -B /gscratch/scrubbed/fanglab/xiaoqian/IFOCUS/derivatives/mriqc:/out \
  -B "${HOST_WORK_DIR}":/work \
  /gscratch/fang/images/mriqc_24.0.2.sif \
  /data /out participant \
  --participant-label "${SUBJECT}" \
  --work-dir /work \
  --n_procs 4 \
  --mem_gb 24 \
  --fd_thres 0.3 \
  --verbose-reports \
  --no-sub

#######
# # Dynamically get all subject IDs from /gscratch/scrubbed/fanglab/xiaoqian/IFOCUS/sourcedata/nii
# SUBJECTS=($(find /gscratch/scrubbed/fanglab/xiaoqian/IFOCUS/sourcedata/nii -maxdepth 1 -type d -name "sub-*" -exec basename {} \; | sed 's/sub-//g' | sort))

# # Get the subject ID for this array task
# SUBJECT=${SUBJECTS[$SLURM_ARRAY_TASK_ID]}

# # Check if SUBJECT is valid
# if [ -z "$SUBJECT" ]; then
#   echo "Error: No subject found for task ID $SLURM_ARRAY_TASK_ID"
#   exit 1
# fi


# apptainer run \
#   --cleanenv \
#   -B /gscratch/scrubbed/fanglab/xiaoqian/IFOCUS/sourcedata/nii:/data \
#   -B /gscratch/scrubbed/fanglab/xiaoqian/IFOCUS/derivatives/mriqc:/out \
#   -B /gscratch/scrubbed/fanglab/xiaoqian/IFOCUS/derivatives/mriqc_work:/work \
#   /gscratch/fang/images/mriqc_24.0.2.sif \
#   /data /out participant \
#   --participant-label ${SUBJECT} \
#   --work-dir /work \
#   --n_procs 4 \
#   --mem_gb 24 \
#   --fd_thres 0.3 \
#   --verbose-reports \
#   --no-sub
