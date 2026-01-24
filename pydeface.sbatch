#!/bin/bash
#SBATCH --job-name=pydeface
#SBATCH --partition=ckpt-all
#SBATCH --account=fang
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=8G
#SBATCH --time=04:00:00
#SBATCH --output=logs/pydeface_%x_%A_%a.out
#SBATCH --error=logs/pydeface_%x_%A_%a.err

# --- Configuration ---
CONTAINER_SIF=/gscratch/fang/images/pydeface.sif
BIDS_ROOT=/gscratch/scrubbed/fanglab/xiaoqian/IFOCUS/sourcedata/nii

module load apptainer 2>/dev/null || true

# --- Identify Subject ---
# Check if TARGET_SUB was passed via --export from the wrapper script
if [ -n "$TARGET_SUB" ]; then
    SUBJ="$TARGET_SUB"
    echo "Manual Mode: Processing specific subject $SUBJ"
else
    # Default Array Mode: Get subject based on array task ID
    subjects=( $(find "${BIDS_ROOT}" -maxdepth 1 -type d -name "sub-*" | sort | xargs -n 1 basename) )
    SUBJ=${subjects[$SLURM_ARRAY_TASK_ID]}
    echo "Array Mode: Processing index $SLURM_ARRAY_TASK_ID ($SUBJ)"
fi

SUBJ_DIR="${BIDS_ROOT}/${SUBJ}"

if [ ! -d "${SUBJ_DIR}" ]; then
    echo "Error: Subject directory ${SUBJ_DIR} not found."
    exit 1
fi

# --- Determine Search Path (Session Logic) ---
# If TARGET_SES is provided, narrow the search to that session folder
if [ -n "$TARGET_SES" ]; then
    SEARCH_PATH="${SUBJ_DIR}/${TARGET_SES}"
    echo "Session Filter: $TARGET_SES"
else
    SEARCH_PATH="${SUBJ_DIR}"
    echo "Processing all sessions for $SUBJ"
fi

if [ ! -d "${SEARCH_PATH}" ]; then
    echo "Error: Search path ${SEARCH_PATH} not found."
    exit 1
fi

# --- Execution ---
find "${SEARCH_PATH}" -name "*_T1w.nii.gz" | while read -r T1W_FILE; do
    # Skip if the file is already a defaced output
    if [[ "${T1W_FILE}" == *"desc-defaced"* ]]; then continue; fi

    OUT_FILE="${T1W_FILE//_T1w.nii.gz/_desc-defaced_T1w.nii.gz}"
    
    echo "  -> Found Anatomical: $(basename "${T1W_FILE}")"
    
    if [ -f "${OUT_FILE}" ]; then
        echo "     [SKIP] Defaced file already exists."
    else
        echo "     [RUN] Running PyDeface on $T1W_FILE"
        
        apptainer exec \
            --pid \
            -B "${BIDS_ROOT}" \
            "$CONTAINER_SIF" \
            pydeface "${T1W_FILE}" --outfile "${OUT_FILE}" --force
        
        echo "     [DONE] Created $(basename "${OUT_FILE}")"
    fi
done