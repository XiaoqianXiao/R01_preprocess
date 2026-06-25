#!/bin/bash
#SBATCH --job-name=fmriprep
#SBATCH --partition=cpu-g2
#SBATCH --account=fang
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=48G                  # Increased to 48G for better stability
#SBATCH --time=24:00:00
#SBATCH --output=logs/fmriprep_%x_%A_%a.out
#SBATCH --error=logs/fmriprep_%x_%A_%a.err

# --- Configuration ---
CONTAINER_SIF=/gscratch/fang/images/fmriprep.sif
LICENSE_FILE=/mmfs1/home/xxqian/files/fs_license.txt

# Directories
BIDS_ROOT=/gscratch/scrubbed/fanglab/xiaoqian/IFOCUS/sourcedata/nii
DERIVS_ROOT=/gscratch/scrubbed/fanglab/xiaoqian/IFOCUS/derivatives
FS_SUBJECTS_DIR="${DERIVS_ROOT}/freesurfer"
OUTPUT_DIR="${DERIVS_ROOT}/fmriprep"
WORK_DIR=/gscratch/scrubbed/fanglab/xiaoqian/IFOCUS/work_fmriprep

mkdir -p "${OUTPUT_DIR}" "${WORK_DIR}"
module load apptainer 2>/dev/null || true

# --- 1. Identify Target (Session-Level) ---
# We find all session directories to process them as individual jobs
targets=($(find "${BIDS_ROOT}" -maxdepth 2 -type d -name "ses-*" | sed "s|$BIDS_ROOT/||" | sort))
CURRENT_TARGET=${targets[$SLURM_ARRAY_TASK_ID]} # e.g., sub-001/ses-01

SUBJ=$(echo "$CURRENT_TARGET" | cut -d'/' -f1)
SES=$(echo "$CURRENT_TARGET" | cut -d'/' -f2)
SUBJ_LABEL=${SUBJ#sub-}

# --- 2. Map to Longitudinal FreeSurfer Output ---
# This matches the folder name created in your Phase 3 Recon-all
# e.g., sub-001_ses-01.long.sub-001_base
FS_LONG_ID="${SUBJ}_${SES}.long.${SUBJ}_base"

echo "Processing Subject: ${SUBJ}, Session: ${SES}"
echo "Using Longitudinal FS ID: ${FS_LONG_ID}"

# Verify the FS folder exists before starting
if [ ! -d "${FS_SUBJECTS_DIR}/${FS_LONG_ID}" ]; then
    echo "ERROR: Longitudinal FreeSurfer folder ${FS_LONG_ID} not found!"
    echo "Ensure Phase 3 of the longitudinal pipeline is complete."
    exit 1
fi

# --- 3. Run fMRIPrep ---
# Note: We use --fs-subject-id to force fMRIPrep to use the .long folder
# We also add --bids-filter-file if you only want to process THIS session
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
  --fs-subject-id "${FS_LONG_ID}" \
  --session-id "${SES#ses-}" \
  --work-dir /work \
  --output-spaces MNI152NLin2009cAsym:res-2 \
  --skip-bids-validation \
  --stop-on-first-crash \
  --mem_mb 40000 \
  --nthreads 8 \
  --omp-nthreads 8

echo "fMRIPrep finished for ${SUBJ} ${SES}"