#!/bin/bash
#SBATCH --job-name=recon-all
#SBATCH --partition=cpu-g2-mem2x
#SBATCH --account=psych
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
DERIVS_DIR=/gscratch/scrubbed/fanglab/xiaoqian/IFOCUS/derivatives/freesurfer

# --- Submit mode ---
# If this script is run with bash from the login node, submit it to SLURM.
# Examples:
#   bash submit_specific_recon.sh sub-154/ses-baseline
#   bash submit_specific_recon.sh sub-154
#   bash submit_specific_recon.sh sub-154/ses-baseline sub-326/ses-baseline
if [ -z "${SLURM_JOB_ID:-}" ]; then
    if [ "$#" -lt 1 ]; then
        echo "Usage:"
        echo "  bash $0 sub-154/ses-baseline"
        echo "  bash $0 sub-154"
        echo "  bash $0 sub-154/ses-baseline sub-326/ses-baseline"
        exit 1
    fi

    mkdir -p logs

    submit_targets=()
    for target in "$@"; do
        if [[ "${target}" == */* ]]; then
            if [ -d "${BIDS_ROOT}/${target}" ]; then
                submit_targets+=("${target}")
                echo "  -> Found ${target}"
            else
                echo "  [WARNING] Could not find ${target} in ${BIDS_ROOT}"
            fi
        elif [ -d "${BIDS_ROOT}/${target}" ]; then
            while IFS= read -r session_dir; do
                session_name=$(basename "${session_dir}")
                submit_targets+=("${target}/${session_name}")
                echo "  -> Found ${target}/${session_name}"
            done < <(find "${BIDS_ROOT}/${target}" -maxdepth 1 -type d -name "ses-*" | sort)
        else
            echo "  [WARNING] Could not find ${target} in ${BIDS_ROOT}"
        fi
    done

    if [ "${#submit_targets[@]}" -eq 0 ]; then
        echo "No valid subject/session targets found. Exiting."
        exit 1
    fi

    target_list=$(IFS=,; echo "${submit_targets[*]}")
    array_end=$(("${#submit_targets[@]}" - 1))

    echo "---------------------------------------------------"
    echo "Submitting recon-all for: ${target_list}"
    echo "SLURM array range: 0-${array_end}"
    echo "---------------------------------------------------"

    sbatch \
        --array="0-${array_end}" \
        --export=ALL,BIDS_ROOT="${BIDS_ROOT}",TARGETS="${target_list}" \
        "$0"
    exit $?
fi

mkdir -p "${DERIVS_DIR}" logs

module load apptainer 2>/dev/null || true

# --- 1. Identify Target (Subject/Session) ---
# Full run:
#   sbatch --array=0-N submit_specific_recon.sh
#
# Specific run:
#   bash submit_specific_recon.sh sub-154/ses-baseline
#   bash submit_specific_recon.sh sub-154

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