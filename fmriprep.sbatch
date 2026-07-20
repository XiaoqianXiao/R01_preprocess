#!/bin/bash
#SBATCH --job-name=fmriprep
#SBATCH --partition=cpu-g2
#SBATCH --account=fang
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=48G                  # Increased to 48G for better stability
#SBATCH --time=24:00:00
#SBATCH --output=logs/fmriprep_%x_%A_%a.out
#SBATCH --error=logs/fmriprep_%x_%A_%a.err

# --- Configuration ---
CONTAINER_SIF=/gscratch/fang/images/fmriprep.sif
LICENSE_FILE=/mmfs1/home/xxqian/files/fs_license.txt

# Directories
BIDS_ROOT=/gscratch/scrubbed/fanglab/xiaoqian/IFOCUS/sourcedata/nii
DERIVS_ROOT=/gscratch/scrubbed/fanglab/xiaoqian/IFOCUS/derivatives
ANAT_MODE="${ANAT_MODE:-defaced}"

case "${ANAT_MODE}" in
    defaced)
        FS_SUBJECTS_DIR="${FS_DERIVS_DIR:-${DERIVS_ROOT}/freesurfer}"
        OUTPUT_DIR="${FMRIPREP_OUTPUT_DIR:-${DERIVS_ROOT}/fmriprep}"
        WORK_DIR="${FMRIPREP_WORK_DIR:-/gscratch/scrubbed/fanglab/xiaoqian/IFOCUS/work_fmriprep}"
        ;;
    original)
        FS_SUBJECTS_DIR="${FS_DERIVS_DIR:-${DERIVS_ROOT}/freesurfer_original}"
        OUTPUT_DIR="${FMRIPREP_OUTPUT_DIR:-${DERIVS_ROOT}/fmriprep_original}"
        WORK_DIR="${FMRIPREP_WORK_DIR:-/gscratch/scrubbed/fanglab/xiaoqian/IFOCUS/work_fmriprep_original}"
        ;;
    *)
        echo "ERROR: ANAT_MODE must be 'defaced' or 'original' (got '${ANAT_MODE}')"
        exit 1
        ;;
esac

mkdir -p "${OUTPUT_DIR}" "${WORK_DIR}"
module load apptainer 2>/dev/null || true

# --- 1. Identify Target (Session-Level) ---
# We find all session directories to process them as individual jobs
targets=($(find "${BIDS_ROOT}" -maxdepth 2 -type d -name "ses-*" | sed "s|$BIDS_ROOT/||" | sort))
CURRENT_TARGET=${targets[$SLURM_ARRAY_TASK_ID]} # e.g., sub-001/ses-01

SUBJ=$(echo "$CURRENT_TARGET" | cut -d'/' -f1)
SES=$(echo "$CURRENT_TARGET" | cut -d'/' -f2)
SUBJ_LABEL=${SUBJ#sub-}

# --- 2. Map to Longitudinal FreeSurfer Output ---
# This matches the folder name created in your Phase 3 Recon-all
# e.g., sub-001_ses-01.long.sub-001_base
FS_LONG_ID="${SUBJ}_${SES}.long.${SUBJ}_base"

echo "Processing Subject: ${SUBJ}, Session: ${SES}"
echo "Anatomical input mode: ${ANAT_MODE}"
echo "Using Longitudinal FS ID: ${FS_LONG_ID}"
echo "Using FreeSurfer directory: ${FS_SUBJECTS_DIR}"
echo "Writing fMRIPrep outputs to: ${OUTPUT_DIR}"

# Verify the FS folder exists before starting
if [ ! -d "${FS_SUBJECTS_DIR}/${FS_LONG_ID}" ]; then
    echo "ERROR: Longitudinal FreeSurfer folder ${FS_LONG_ID} not found!"
    echo "Ensure Phase 3 of the longitudinal pipeline is complete."
    exit 1
fi

BIDS_FILTER_HOST_FILE="${WORK_DIR}/bids_filter_${ANAT_MODE}_${SUBJ}_${SES}.json"
BIDS_FILTER_CONTAINER_FILE="/work/bids_filter_${ANAT_MODE}_${SUBJ}_${SES}.json"
if [ "${ANAT_MODE}" = "defaced" ]; then
    cat > "${BIDS_FILTER_HOST_FILE}" <<EOF
{
  "t1w": {
    "datatype": "anat",
    "suffix": "T1w",
    "desc": "defaced"
  },
  "bold": {
    "datatype": "func",
    "suffix": "bold"
  }
}
EOF
else
    cat > "${BIDS_FILTER_HOST_FILE}" <<EOF
{
  "t1w": {
    "datatype": "anat",
    "suffix": "T1w",
    "desc": null
  },
  "bold": {
    "datatype": "func",
    "suffix": "bold"
  }
}
EOF
fi

echo "Using BIDS filter file: ${BIDS_FILTER_HOST_FILE}"

# --- 3. Run fMRIPrep ---
# Note: We use --fs-subject-id to force fMRIPrep to use the .long folder
# We also add --bids-filter-file if you only want to process THIS session
apptainer run --cleanenv \
  -B "${BIDS_ROOT}:/data" \
  -B "${OUTPUT_DIR}:/outputs" \
  -B "${FS_SUBJECTS_DIR}:/fsdir" \
  -B "${WORK_DIR}:/work" \
  -B "${LICENSE_FILE}:/opt/freesurfer/license.txt" \
  "${CONTAINER_SIF}" \
  /data /outputs participant \
  --participant-label "${SUBJ_LABEL}" \
  --fs-subjects-dir /fsdir \
  --fs-subject-id "${FS_LONG_ID}" \
  --session-id "${SES#ses-}" \
  --bids-filter-file "${BIDS_FILTER_CONTAINER_FILE}" \
  --work-dir /work \
  --output-spaces MNI152NLin2009cAsym:res-2 \
  --skip-bids-validation \
  --stop-on-first-crash \
  --mem_mb 40000 \
  --nthreads 8 \
  --omp-nthreads 8

echo "fMRIPrep finished for ${SUBJ} ${SES}"
