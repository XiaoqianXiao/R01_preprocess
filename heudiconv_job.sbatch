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

# Select subject.
if [[ -n "${TARGET_SUB:-}" ]]; then
    SUBJ="${TARGET_SUB#sub-}"
else
    mapfile -t SUBJECTS < <(
        find "${DICOM_ROOT}" \
            -mindepth 1 \
            -maxdepth 1 \
            -type d \
            -printf '%f\n' |
            sort -V
    )

    TASK_ID="${SLURM_ARRAY_TASK_ID:?Set TARGET_SUB or SLURM_ARRAY_TASK_ID}"

    if ((TASK_ID < 0 || TASK_ID >= ${#SUBJECTS[@]})); then
        echo "Error: SLURM_ARRAY_TASK_ID ${TASK_ID} is outside the subject list." >&2
        exit 1
    fi

    SUBJ="${SUBJECTS[$TASK_ID]#sub-}"
fi

SUBJ_PATH="${DICOM_ROOT}/${SUBJ}"

if [[ ! -d "${SUBJ_PATH}" ]]; then
    echo "Error: subject directory not found: ${SUBJ_PATH}" >&2
    exit 1
fi

# Process source sessions such as:
# dicom/127/ses-T6
for SES_PATH in "${SUBJ_PATH}"/ses-*; do
    [[ -d "${SES_PATH}" ]] || continue

    SES_FOLDER="$(basename "${SES_PATH}")"  # ses-T6
    SES="${SES_FOLDER#ses-}"                # T6

    if [[ -n "${TARGET_SES:-}" ]]; then
        TARGET_SES_CLEAN="${TARGET_SES#ses-}"
        [[ "${SES}" == "${TARGET_SES_CLEAN}" ]] || continue
    fi

    echo "------------------------------------------------"
    echo "Subject        : ${SUBJ}"
    echo "Source session : ${SES_PATH}"
    echo "Session arg    : ${SES}"
    echo "Expected output: ${BIDS_ROOT}/sub-${SUBJ}/ses-${SES}"
    echo "------------------------------------------------"

    TMP_ROOT="${SLURM_TMPDIR:-/tmp}/heudiconv_${SLURM_JOB_ID:-manual}_${SUBJ}_${SES}"
    TMP_SES="${TMP_ROOT}/${SUBJ}/ses-${SES}"

    rm -rf "${TMP_ROOT}"
    mkdir -p "${TMP_SES}"

    FILE_COUNT=0

    while IFS= read -r -d '' DICOM_FILE; do
        FILE_COUNT=$((FILE_COUNT + 1))
        STAGED_NAME="$(printf '%06d.dcm' "${FILE_COUNT}")"
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
        echo "Warning: no DICOM files found under ${SES_PATH}; skipping." >&2
        rm -rf "${TMP_ROOT}"
        continue
    fi

    echo "DICOM files    : ${FILE_COUNT}"

    apptainer exec \
        -B "${DICOM_ROOT}:/dicom:ro" \
        -B "${TMP_ROOT}:/heudiconv_input:ro" \
        -B "${BIDS_ROOT}:/bids" \
        -B "${HEURISTIC}:/heuristic.py:ro" \
        "${HEUDICONV_SIF}" \
        heudiconv \
            -d '/heudiconv_input/{subject}/ses-{session}/*' \
            -s "${SUBJ}" \
            -ss "${SES}" \
            -f /heuristic.py \
            -c dcm2niix \
            -b \
            -o /bids \
            --overwrite

    # Normalize malformed output:
    # sub-127/ses-ses-T6 -> sub-127/ses-T6
    BAD_DIR="${BIDS_ROOT}/sub-${SUBJ}/ses-ses-${SES}"
    GOOD_DIR="${BIDS_ROOT}/sub-${SUBJ}/ses-${SES}"

    if [[ -d "${BAD_DIR}" ]]; then
        if [[ -e "${GOOD_DIR}" ]]; then
            echo "Error: both output directories exist:" >&2
            echo "  ${BAD_DIR}" >&2
            echo "  ${GOOD_DIR}" >&2
            echo "Resolve them manually to prevent data loss." >&2
            exit 1
        fi

        mv "${BAD_DIR}" "${GOOD_DIR}"

        # Rename filenames containing ses-ses-T6.
        while IFS= read -r -d '' OLD_PATH; do
            OLD_NAME="$(basename "${OLD_PATH}")"
            NEW_NAME="${OLD_NAME//ses-ses-${SES}/ses-${SES}}"

            if [[ "${OLD_NAME}" != "${NEW_NAME}" ]]; then
                mv \
                    "${OLD_PATH}" \
                    "$(dirname "${OLD_PATH}")/${NEW_NAME}"
            fi
        done < <(
            find "${GOOD_DIR}" \
                -depth \
                -name "*ses-ses-${SES}*" \
                -print0
        )

        # Update internal path references in JSON or other text metadata.
        while IFS= read -r -d '' META_FILE; do
            sed -i \
                "s/ses-ses-${SES}/ses-${SES}/g" \
                "${META_FILE}"
        done < <(
            grep -IlZr \
                "ses-ses-${SES}" \
                "${GOOD_DIR}" \
                2>/dev/null || true
        )
    fi

    rm -rf "${TMP_ROOT}"
done