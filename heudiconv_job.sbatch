#!/bin/bash
#SBATCH --job-name=heudiconv
#SBATCH --partition=ckpt-all
#SBATCH --account=fang
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=8G
#SBATCH --time=02:00:00
#SBATCH --output=logs/%x_%A_%a.out
#SBATCH --error=logs/%x_%A_%a.err

set -euo pipefail

# --- Configuration ---
HEUDICONV_SIF=/gscratch/fang/images/heudiconv.sif
HEURISTIC=/gscratch/scrubbed/fanglab/xiaoqian/repo/R01_preprocess/heuristic_reproin_like.py

DICOM_ROOT=/gscratch/scrubbed/fanglab/xiaoqian/IFOCUS/sourcedata/dicom
BIDS_ROOT=/gscratch/scrubbed/fanglab/xiaoqian/IFOCUS/sourcedata/nii

module load apptainer 2>/dev/null || true

# --- 1. Identify subject ---
# Manual example:
# sbatch --export=ALL,TARGET_SUB=139,TARGET_SES=T12 heudiconv_job.sbatch

if [[ -n "${TARGET_SUB:-}" ]]; then
    SUBJ="${TARGET_SUB#sub-}"
    echo "Running in MANUAL mode for subject ${SUBJ}"
else
    mapfile -t SUBJECTS < <(
        find "${DICOM_ROOT}" \
            -mindepth 1 \
            -maxdepth 1 \
            -type d \
            -printf '%f\n' |
            sort -V
    )

    TASK_ID="${SLURM_ARRAY_TASK_ID:?SLURM_ARRAY_TASK_ID or TARGET_SUB is required}"
    SUBJ="${SUBJECTS[$TASK_ID]}"

    echo "Running in ARRAY mode for subject ${SUBJ} (index ${TASK_ID})"
fi

SUBJ_PATH="${DICOM_ROOT}/${SUBJ}"

if [[ ! -d "${SUBJ_PATH}" ]]; then
    echo "Error: Subject directory not found: ${SUBJ_PATH}" >&2
    exit 1
fi

# --- 2. Process sessions ---
for SES_PATH in "${SUBJ_PATH}"/ses-*; do
    [[ -d "${SES_PATH}" ]] || continue

    SES_FOLDER=$(basename "${SES_PATH}")  # ses-T12
    SES="${SES_FOLDER#ses-}"              # T12

    # Process only TARGET_SES when specified.
    if [[ -n "${TARGET_SES:-}" ]]; then
        TARGET_SES_CLEAN="${TARGET_SES#ses-}"
        [[ "${SES}" == "${TARGET_SES_CLEAN}" ]] || continue
    fi

    echo "------------------------------------------------"
    echo "Subject       : ${SUBJ}"
    echo "Source session: ${SES_PATH}"
    echo "Session label : ${SES}"
    echo "BIDS output   : ${BIDS_ROOT}/sub-${SUBJ}/ses-${SES}"
    echo "------------------------------------------------"

    # Stage DICOM links without BIDS prefixes:
    # /heudiconv_input/139/T12/
    TMP_ROOT="${SLURM_TMPDIR:-/tmp}/heudiconv_${SLURM_JOB_ID:-manual}_${SUBJ}_${SES}"
    TMP_SES="${TMP_ROOT}/${SUBJ}/${SES}"

    rm -rf "${TMP_ROOT}"
    mkdir -p "${TMP_SES}"

    FILE_COUNT=0

    while IFS= read -r -d '' DICOM_FILE; do
        FILE_COUNT=$((FILE_COUNT + 1))
        STAGED_NAME=$(printf '%06d.dcm' "${FILE_COUNT}")
        CONTAINER_DICOM="/dicom/${DICOM_FILE#${DICOM_ROOT}/}"

        ln -s "${CONTAINER_DICOM}" "${TMP_SES}/${STAGED_NAME}"
    done < <(
        find "${SES_PATH}" \
            -type f \
            ! -name '.*' \
            -print0 |
            sort -z
    )

    if ((FILE_COUNT == 0)); then
        echo "Warning: No DICOM files found; skipping ${SES_PATH}" >&2
        rm -rf "${TMP_ROOT}"
        continue
    fi

    echo "DICOM files   : ${FILE_COUNT}"

    apptainer exec \
        -B "${DICOM_ROOT}:/dicom:ro" \
        -B "${TMP_ROOT}:/heudiconv_input:ro" \
        -B "${BIDS_ROOT}:/bids" \
        -B "${HEURISTIC}:/heuristic.py:ro" \
        "${HEUDICONV_SIF}" \
        heudiconv \
            -d '/heudiconv_input/{subject}/{session}/*' \
            -s "${SUBJ}" \
            -ss "${SES}" \
            -f /heuristic.py \
            -c dcm2niix \
            -b \
            -o /bids \
            --overwrite

    rm -rf "${TMP_ROOT}"
done