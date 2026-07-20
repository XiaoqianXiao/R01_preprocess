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
BIDS_ROOT="${BIDS_ROOT:-/gscratch/scrubbed/fanglab/xiaoqian/IFOCUS/sourcedata/nii}"
DERIVS_ROOT=/gscratch/scrubbed/fanglab/xiaoqian/IFOCUS/derivatives
ANAT_MODE="${ANAT_MODE:-defaced}"

case "${ANAT_MODE}" in
    defaced)
        DERIVS_DIR="${FS_DERIVS_DIR:-${DERIVS_ROOT}/freesurfer}"
        ;;
    original)
        DERIVS_DIR="${FS_DERIVS_DIR:-${DERIVS_ROOT}/freesurfer_original}"
        ;;
    *)
        echo "ERROR: ANAT_MODE must be 'defaced' or 'original' (got '${ANAT_MODE}')"
        exit 1
        ;;
esac

mkdir -p "${DERIVS_DIR}" logs
module load apptainer 2>/dev/null || true
# --- 1. Identify Target (Subject/Session) ---
# Normal full run:
#   sbatch --array=0-N recon_all.sbatch
#
# Specific subject/session run:
#   sbatch --array=0-0 --export=ALL,TARGETS=sub-154/ses-01 recon_all.sbatch
#   sbatch --array=0-1 --export=ALL,TARGETS=sub-154/ses-01,sub-154/ses-02 recon_all.sbatch
#
# Or use:
#   ./submit_recon_subjects.sh sub-154
if [ -n "${TARGETS:-}" ]; then
    IFS=, read -r -a targets <<< "${TARGETS}"
else
    mapfile -t targets < <(
        find "${BIDS_ROOT}" -maxdepth 2 -type d -name "ses-*" |
        sed "s|${BIDS_ROOT}/||" |
        sort
    )
fi
if [ -z "${SLURM_ARRAY_TASK_ID:-}" ]; then
    echo "ERROR: SLURM_ARRAY_TASK_ID is not set. Submit with sbatch --array=..."
    exit 1
fi
if [ "${SLURM_ARRAY_TASK_ID}" -ge "${#targets[@]}" ]; then
    echo "ERROR: Array task ${SLURM_ARRAY_TASK_ID} is outside target list size ${#targets[@]}"
    exit 1
fi
CURRENT_TARGET=${targets[$SLURM_ARRAY_TASK_ID]} # e.g., sub-001/ses-01
# Extract Sub and Ses IDs for naming
SUBJ=$(echo "$CURRENT_TARGET" | cut -d'/' -f1)
SES=$(echo "$CURRENT_TARGET" | cut -d'/' -f2)
if [ -z "${SUBJ}" ] || [ -z "${SES}" ] || [ "${SUBJ}" = "${SES}" ]; then
    echo "ERROR: Target must look like sub-001/ses-01. Got: ${CURRENT_TARGET}"
    exit 1
fi
# Create a unique FreeSurfer ID (e.g., sub-001_ses-01)
# This is critical for neuroimaging data management
FS_ID="${SUBJ}_${SES}"
TARGET_DIR="${BIDS_ROOT}/${CURRENT_TARGET}"
echo "Processing Target: ${FS_ID}"
echo "Current target path: ${CURRENT_TARGET}"
echo "Array task id: ${SLURM_ARRAY_TASK_ID}"
echo "Anatomical input mode: ${ANAT_MODE}"
echo "FreeSurfer derivatives directory: ${DERIVS_DIR}"

# --- 2. Find the requested T1w Image ---
# Restrict search ONLY to the specific session folder
if [ "${ANAT_MODE}" = "defaced" ]; then
    INPUT_FILE=$(find "${TARGET_DIR}" -name "*_desc-defaced_T1w.nii.gz" | head -n 1)
    MISSING_MSG="No defaced T1w found in ${TARGET_DIR}. Run PyDeface first or use ANAT_MODE=original."
else
    INPUT_FILE=$(find "${TARGET_DIR}" -name "*_T1w.nii.gz" ! -name "*_desc-defaced_T1w.nii.gz" | head -n 1)
    MISSING_MSG="No original T1w found in ${TARGET_DIR}."
fi

if [ -z "${INPUT_FILE}" ]; then
    echo "Error: ${MISSING_MSG}"
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
