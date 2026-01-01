#!/bin/bash
#SBATCH --job-name=fmriprep
#SBATCH --partition=ckpt-all       # Use 'ckpt' or 'ckpt-all' or 'cpu-g2'
#SBATCH --account=fang             # Use your correct account
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8          # fMRIPrep needs good CPU power (8-16 is ideal)
#SBATCH --mem=32G                  # 32GB is minimum recommended; use 48G or 64G if possible
#SBATCH --time=24:00:00            # Can take 12-24h per subject
#SBATCH --output=logs/fmriprep_%x_%A_%a.out
#SBATCH --error=logs/fmriprep_%x_%A_%a.err

# --- Configuration ---
CONTAINER_SIF=/gscratch/scrubbed/fanglab/xiaoqian/containers/fmriprep.sif
# Note: Using the license path you provided in previous scripts
LICENSE_FILE=/gscratch/scrubbed/fanglab/xiaoqian/files/fs_license.txt

# Directories
BIDS_ROOT=/gscratch/scrubbed/fanglab/xiaoqian/IFOCUS/sourcedata/nii
DERIVS_ROOT=/gscratch/scrubbed/fanglab/xiaoqian/IFOCUS/derivatives
FS_SUBJECTS_DIR="${DERIVS_ROOT}/freesurfer"
OUTPUT_DIR="${DERIVS_ROOT}/fmriprep"
WORK_DIR=/gscratch/scrubbed/fanglab/xiaoqian/IFOCUS/work_fmriprep

# Ensure directories exist
mkdir -p "${OUTPUT_DIR}"
mkdir -p "${WORK_DIR}"

# Load Apptainer
module load apptainer 2>/dev/null || true

# --- 1. Identify Subject ---
subjects=( $(find "${BIDS_ROOT}" -maxdepth 1 -type d -name "sub-*" | sort | xargs -n 1 basename) )
SUBJ=${subjects[$SLURM_ARRAY_TASK_ID]}

# fMRIPrep expects the label without "sub-" (e.g., "002" not "sub-002")
SUBJ_LABEL=${SUBJ#sub-}

echo "Processing Subject: ${SUBJ} (Label: ${SUBJ_LABEL})"

# --- 2. Run fMRIPrep ---
# Explanation of Flags:
# --participant-label: Specific subject to run
# --fs-subjects-dir:  <CRITICAL> Points to your PRE-COMPUTED defaced FreeSurfer output
# --output-spaces:    Standard output spaces (MNI152NLin2009cAsym is default standard)
# --work-dir:         Scratch directory for intermediate files (speeds up resume)
# --skip-bids-validation: Prevents minor BIDS naming issues from stopping the job
# --stop-on-first-crash: Helpful for debugging

# We bind the BIDS root, derivatives (for FS), and work dir
apptainer run --cleanenv \
  -B "${BIDS_ROOT}:/data" \
  -B "${OUTPUT_DIR}:/outputs" \
  -B "${FS_SUBJECTS_DIR}:/fsdir" \
  -B "${WORK_DIR}:/work" \
  -B "${LICENSE_FILE}:/opt/freesurfer/license.txt" \
  "${CONTAINER_SIF}" \
  /data /outputs participant \
  --participant-label "${SUBJ_LABEL}" \
  --fs-subjects-dir /fsdir \
  --work-dir /work \
  --output-spaces MNI152NLin2009cAsym:res-2 \
  --skip-bids-validation \
  --stop-on-first-crash \
  --mem_mb 30000 \
  --nthreads 8 \
  --omp-nthreads 8

echo "fMRIPrep finished for ${SUBJ}"
