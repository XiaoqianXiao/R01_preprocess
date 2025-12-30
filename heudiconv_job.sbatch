#!/bin/bash
#SBATCH --job-name=heudiconv
#SBATCH --partition=compute        # Change to your specific partition (e.g., ckpt, cpu-g2)
#SBATCH --account=fanglab          # Change to your SLURM account
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1          # HeuDiConv is mostly single-threaded
#SBATCH --mem=8G                   # 8GB is usually plenty for dicom conversion
#SBATCH --time=02:00:00            # 2 hours per subject (adjust if needed)
#SBATCH --output=logs/%x_%A_%a.out # Standard output log (creates a logs/ folder)
#SBATCH --error=logs/%x_%A_%a.err  # Standard error log

# --- Configuration ---
HEUDICONV_SIF=/gscratch/scrubbed/fanglab/xiaoqian/containers/heudiconv.sif
HEURISTIC=/gscratch/scrubbed/fanglab/xiaoqian/repo/R01_preprocess/heuristic_reproin_like.py

DICOM_ROOT=/gscratch/scrubbed/fanglab/xiaoqian/IFOCUS/sourcedata/dicom
BIDS_ROOT=/gscratch/scrubbed/fanglab/xiaoqian/IFOCUS/sourcedata/nii

# Load Apptainer (if not already in your path)
module load apptainer 2>/dev/null || true

# --- 1. Identify the specific subject for this task ---
# Get a list of all subject folders (names only)
# We use a bash array to map the SLURM_ARRAY_TASK_ID to a folder name
subjects=( $(ls -d "${DICOM_ROOT}"/* | xargs -n 1 basename) )

# Pick the subject corresponding to this job array index
SUBJ=${subjects[$SLURM_ARRAY_TASK_ID]}
SUBJ_PATH="${DICOM_ROOT}/${SUBJ}"

# Check if the folder exists (safety check)
if [ ! -d "${SUBJ_PATH}" ]; then
    echo "Error: Subject directory ${SUBJ_PATH} not found."
    exit 1
fi

echo "========================================"
echo "Job ID     : ${SLURM_JOB_ID}"
echo "Array Task : ${SLURM_ARRAY_TASK_ID}"
echo "Processing : ${SUBJ}"
echo "========================================"

# --- 2. Process all sessions for this subject ---
# We loop sessions inside the job so one subject finishes completely in one job
for SES_PATH in "${SUBJ_PATH}"/ses-*; do
    [[ -d "${SES_PATH}" ]] || continue
    SES=$(basename "${SES_PATH}" | sed 's/^ses-//')

    echo "  -> Found session: ${SES}"

    apptainer exec \
      -B "${DICOM_ROOT}:/dicom:ro" \
      -B "${BIDS_ROOT}:/bids" \
      -B "${HEURISTIC}:/heuristic.py:ro" \
      "${HEUDICONV_SIF}" \
      heudiconv \
        -d '/dicom/{subject}/ses-{session}/*/*/*.dcm' \
        -s "${SUBJ}" \
        -ss "${SES}" \
        -f /heuristic.py \
        -c dcm2niix \
        -b \
        -o /bids \
        --overwrite
done

echo "Done with subject ${SUBJ}"
