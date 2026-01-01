#!/bin/bash
#SBATCH --job-name=recon-all
#SBATCH --partition=ckpt-all
#SBATCH --account=fang
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4          # FreeSurfer can use OpenMP (4 cores is sweet spot)
#SBATCH --mem=12G                  # Recon-all needs ~8-10GB
#SBATCH --time=32:00:00            # Recon-all takes 6-12 hours usually
#SBATCH --output=logs/recon_%x_%A_%a.out
#SBATCH --error=logs/recon_%x_%A_%a.err

# --- Configuration ---
CONTAINER_SIF=/gscratch/scrubbed/fanglab/xiaoqian/containers/freesurfer.sif
LICENSE_FILE=/gscratch/scrubbed/fanglab/xiaoqian/files/fs_license.txt

# Directories
BIDS_ROOT=/gscratch/scrubbed/fanglab/xiaoqian/IFOCUS/sourcedata/nii
DERIVS_DIR=/gscratch/scrubbed/fanglab/xiaoqian/IFOCUS/derivatives/freesurfer
mkdir -p "${DERIVS_DIR}"

# Load Apptainer
module load apptainer 2>/dev/null || true

# --- 1. Identify Subject ---
# Get list of subjects (e.g., sub-002)
subjects=( $(find "${BIDS_ROOT}" -maxdepth 1 -type d -name "sub-*" | sort | xargs -n 1 basename) )
SUBJ=${subjects[$SLURM_ARRAY_TASK_ID]}
SUBJ_DIR="${BIDS_ROOT}/${SUBJ}"

if [ ! -d "${SUBJ_DIR}" ]; then
    echo "Error: Subject directory ${SUBJ_DIR} not found."
    exit 1
fi

echo "Processing Subject: ${SUBJ}"

# --- 2. Find the Defaced T1w Image ---
# We look specifically for the file ending in _desc-defaced_T1w.nii.gz
# This ensures we are using the 'faceless' input.
INPUT_FILE=$(find "${SUBJ_DIR}" -name "*_desc-defaced_T1w.nii.gz" | head -n 1)

if [ -z "${INPUT_FILE}" ]; then
    echo "Error: No defaced T1w image found for ${SUBJ}. Run PyDeface first!"
    exit 1
fi

echo "  -> Input: $(basename "${INPUT_FILE}")"
echo "  -> Output Dir: ${DERIVS_DIR}/${SUBJ}"

# --- 3. Run Recon-all ---
# -i : Input NIfTI
# -s : Subject ID (creates folder inside SD)
# -sd: Subjects Directory (where outputs go)
# -all: Run the full pipeline
# -parallel -openmp 4: Use 4 cores to speed it up

apptainer exec \
  -B "${BIDS_ROOT}" \
  -B "${LICENSE_FILE}:/opt/freesurfer/license.txt" \
  -B "${DERIVS_DIR}" \
  --env FS_LICENSE=/opt/freesurfer/license.txt \
  "${CONTAINER_SIF}" \
  recon-all \
    -i "${INPUT_FILE}" \
    -s "${SUBJ}" \
    -sd "${DERIVS_DIR}" \
    -all \
    -parallel \
    -openmp 4

echo "Recon-all completed for ${SUBJ}"
