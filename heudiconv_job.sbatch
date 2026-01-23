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

# --- Configuration ---
HEUDICONV_SIF=/gscratch/scrubbed/fanglab/xiaoqian/containers/heudiconv.sif
HEURISTIC=/gscratch/scrubbed/fanglab/xiaoqian/repo/R01_preprocess/heuristic_reproin_like.py

DICOM_ROOT=/gscratch/scrubbed/fanglab/xiaoqian/IFOCUS/sourcedata/dicom
BIDS_ROOT=/gscratch/scrubbed/fanglab/xiaoqian/IFOCUS/sourcedata/nii

module load apptainer 2>/dev/null || true

# --- 1. Identify Subject ---
# If TARGET_SUB is passed via --export, we use it. Otherwise, we use the array index.
if [ ! -z "$TARGET_SUB" ]; then
    SUBJ="$TARGET_SUB"
    echo "Running in MANUAL mode for Subject: ${SUBJ}"
else
    subjects=( $(ls -d "${DICOM_ROOT}"/* | xargs -n 1 basename) )
    SUBJ=${subjects[$SLURM_ARRAY_TASK_ID]}
    echo "Running in ARRAY mode for Subject: ${SUBJ} (Index: ${SLURM_ARRAY_TASK_ID})"
fi

SUBJ_PATH="${DICOM_ROOT}/${SUBJ}"

if [ ! -d "${SUBJ_PATH}" ]; then
    echo "Error: Subject directory ${SUBJ_PATH} not found."
    exit 1
fi

# --- 2. Process Sessions ---
for SES_PATH in "${SUBJ_PATH}"/ses-*; do
    [[ -d "${SES_PATH}" ]] || continue
    
    SES_RAW=$(basename "${SES_PATH}")

    # If TARGET_SES is passed, skip any session that doesn't match
    if [ ! -z "$TARGET_SES" ]; then
        # Check if the raw folder matches 'ses-baseline' or just 'baseline'
        if [[ "$SES_RAW" != "ses-$TARGET_SES" && "$SES_RAW" != "$TARGET_SES" ]]; then
            continue
        fi
    fi
    
    # FORCE CLEANING: Turn "ses-baseline" into "baseline"
    SES_CLEAN=$(echo "$SES_RAW" | sed 's/^ses-//')
    
    echo "  ------------------------------------------------"
    echo "  Processing Subject : ${SUBJ}"
    echo "  Folder Found       : ${SES_RAW}"
    echo "  Session Arg        : ${SES_CLEAN}"  
    echo "  ------------------------------------------------"

    apptainer exec \
      -B "${DICOM_ROOT}:/dicom:ro" \
      -B "${BIDS_ROOT}:/bids" \
      -B "${HEURISTIC}:/heuristic.py:ro" \
      "${HEUDICONV_SIF}" \
      heudiconv \
        -d '/dicom/{subject}/ses-{session}/*/*/*.dcm' \
        -s "${SUBJ}" \
        -ss "${SES_CLEAN}" \
        -f /heuristic.py \
        -c dcm2niix \
        -b \
        -o /bids \
        --overwrite
done