#!/bin/bash
#SBATCH --job-name=recon-all
#SBATCH --partition=cpu-g2
#SBATCH --account=fang
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=12G
#SBATCH --time=32:00:00
#SBATCH --output=logs/recon_%x_%A_%a.out
#SBATCH --error=logs/recon_%x_%A_%a.err

# --- Configuration ---
CONTAINER_SIF=/gscratch/fang/images/freesurfer.sif
LICENSE_FILE=/mmfs1/home/xxqian/files/fs_license.txt
BIDS_ROOT=/gscratch/scrubbed/fanglab/xiaoqian/IFOCUS/sourcedata/nii
DERIVS_DIR=/gscratch/scrubbed/fanglab/xiaoqian/IFOCUS/derivatives/freesurfer
mkdir -p "${DERIVS_DIR}"

module load apptainer 2>/dev/null || true

# --- 1. Identify Target (Subject/Session) ---
# This gets the path like "sub-001/ses-01" from the array
targets=($(find "${BIDS_ROOT}" -maxdepth 2 -type d -name "ses-*" | sed "s|$BIDS_ROOT/||" | sort))
CURRENT_TARGET=${targets[$SLURM_ARRAY_TASK_ID]} # e.g., sub-001/ses-01

# Extract Sub and Ses IDs for naming
SUBJ=$(echo "$CURRENT_TARGET" | cut -d'/' -f1)
SES=$(echo "$CURRENT_TARGET" | cut -d'/' -f2)

# Create a unique FreeSurfer ID (e.g., sub-001_ses-01)
# This is critical for neuroimaging data management
FS_ID="${SUBJ}_${SES}"
TARGET_DIR="${BIDS_ROOT}/${CURRENT_TARGET}"

echo "Processing Target: ${FS_ID}"

# --- 2. Find the Defaced T1w Image ---
# Restrict search ONLY to the specific session folder
INPUT_FILE=$(find "${TARGET_DIR}" -name "*_desc-defaced_T1w.nii.gz" | head -n 1)

if [ -z "${INPUT_FILE}" ]; then
    echo "Error: No defaced T1w found in ${TARGET_DIR}. Check PyDeface output!"
    exit 1
fi

echo "  -> Input: $(basename "${INPUT_FILE}")"
echo "  -> Output Folder: ${DERIVS_DIR}/${FS_ID}"

# --- 3. Safety Check: Clear lock files ---
if [ -d "${DERIVS_DIR}/${FS_ID}/scripts" ]; then
    echo "Cleaning up potential lock files for ${FS_ID}..."
    rm -f "${DERIVS_DIR}/${FS_ID}/scripts/IsRunning"*
fi

# --- 4. Run Recon-all ---

apptainer exec \
  -B "${BIDS_ROOT}" \
  -B "${LICENSE_FILE}:/opt/freesurfer/license.txt" \
  -B "${DERIVS_DIR}" \
  --env FS_LICENSE=/opt/freesurfer/license.txt \
  "${CONTAINER_SIF}" \
  recon-all \
    -i "${INPUT_FILE}" \
    -s "${FS_ID}" \
    -sd "${DERIVS_DIR}" \
    -all \
    -parallel \
    -openmp 4

echo "Finished ${FS_ID} at $(date)"