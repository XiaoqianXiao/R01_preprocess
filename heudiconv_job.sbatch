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
subjects=( $(ls -d "${DICOM_ROOT}"/* | xargs -n 1 basename) )
SUBJ=${subjects[$SLURM_ARRAY_TASK_ID]}
SUBJ_PATH="${DICOM_ROOT}/${SUBJ}"

if [ ! -d "${SUBJ_PATH}" ]; then
    echo "Error: Subject directory ${SUBJ_PATH} not found."
    exit 1
fi

echo "Processing Subject: ${SUBJ}"

# --- 2. Process Sessions ---
for SES_PATH in "${SUBJ_PATH}"/ses-*; do
    [[ -d "${SES_PATH}" ]] || continue
    
    # 1. Get the folder name (e.g., "ses-pilotTR1500")
    SES_RAW=$(basename "${SES_PATH}")
    
    # 2. FORCE CLEANING: Use sed to remove 'ses-' from the start
    # This turns "ses-pilotTR1500" into "pilotTR1500"
    SES_CLEAN=$(echo "$SES_RAW" | sed 's/^ses-//')
    
    # 3. Debug Print (Check your .out log file if this fails!)
    echo "  ------------------------------------------------"
    echo "  Folder Found : ${SES_RAW}"
    echo "  Session Arg  : ${SES_CLEAN}"  
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