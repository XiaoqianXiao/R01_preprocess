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
# POINT TO YOUR NEW CONTAINER
CONTAINER_SIF=/gscratch/scrubbed/fanglab/xiaoqian/containers/pydeface.sif
BIDS_ROOT=/gscratch/scrubbed/fanglab/xiaoqian/IFOCUS/sourcedata/nii

module load apptainer 2>/dev/null || true

# Identify Subject
subjects=( $(find "${BIDS_ROOT}" -maxdepth 1 -type d -name "sub-*" | sort | xargs -n 1 basename) )
SUBJ=${subjects[$SLURM_ARRAY_TASK_ID]}
SUBJ_DIR="${BIDS_ROOT}/${SUBJ}"

if [ ! -d "${SUBJ_DIR}" ]; then
    echo "Error: Subject directory ${SUBJ_DIR} not found."
    exit 1
fi

echo "Processing Subject: ${SUBJ}"

find "${SUBJ_DIR}" -name "*_T1w.nii.gz" | while read -r T1W_FILE; do
    if [[ "${T1W_FILE}" == *"desc-defaced"* ]]; then continue; fi

    OUT_FILE="${T1W_FILE//_T1w.nii.gz/_desc-defaced_T1w.nii.gz}"
    
    echo "  -> Found Anatomical: $(basename "${T1W_FILE}")"
    
    if [ -f "${OUT_FILE}" ]; then
        echo "     [SKIP] Defaced file already exists."
    else
        echo "     [RUN] Running PyDeface..."
        
        # SIMPLIFIED EXECUTION:
        # We only need to bind the data folder. 
        # PyDeface is now found automatically in the system path.
        apptainer exec \
            --pid \
            -B "${BIDS_ROOT}" \
            "$CONTAINER_SIF" \
            pydeface "${T1W_FILE}" --outfile "${OUT_FILE}" --force
        
        echo "     [DONE] Created $(basename "${OUT_FILE}")"
    fi
done
