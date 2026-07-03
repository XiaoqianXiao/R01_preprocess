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

# Dynamically get all subject IDs from /gscratch/scrubbed/fanglab/xiaoqian/IFOCUS/sourcedata/nii
SUBJECTS=($(find /gscratch/scrubbed/fanglab/xiaoqian/IFOCUS/sourcedata/nii -maxdepth 1 -type d -name "sub-*" -exec basename {} \; | sed 's/sub-//g' | sort))

# Get the subject ID for this array task
SUBJECT=${SUBJECTS[$SLURM_ARRAY_TASK_ID]}

# Check if SUBJECT is valid
if [ -z "$SUBJECT" ]; then
  echo "Error: No subject found for task ID $SLURM_ARRAY_TASK_ID"
  exit 1
fi

apptainer run \
  --cleanenv \
  -B /gscratch/scrubbed/fanglab/xiaoqian/IFOCUS/sourcedata/nii:/data \
  -B /gscratch/scrubbed/fanglab/xiaoqian/IFOCUS/derivatives/mriqc:/out \
  -B /gscratch/scrubbed/fanglab/xiaoqian/IFOCUS/derivatives/mriqc_work:/work \
  /gscratch/fang/images/mriqc_24.0.2.sif \
  /data /out participant \
  --participant-label ${SUBJECT} \
  --work-dir /work \
  --n_procs 4 \
  --mem_gb 24 \
  --fd_thres 0.3 \
  --verbose-reports \
  --no-sub
