#!/bin/bash
DERIVS_ROOT="/gscratch/scrubbed/fanglab/xiaoqian/IFOCUS/derivatives"
ANAT_MODE="${ANAT_MODE:-defaced}"

case "${ANAT_MODE}" in
    defaced)
        DERIVS_DIR="${FS_DERIVS_DIR:-${DERIVS_ROOT}/freesurfer}"
        EXPECTED_LOG_PATTERN="desc-defaced"
        EXPECTED_LABEL="Defaced"
        ;;
    original)
        DERIVS_DIR="${FS_DERIVS_DIR:-${DERIVS_ROOT}/freesurfer_original}"
        EXPECTED_LOG_PATTERN="_T1w.nii.gz"
        EXPECTED_LABEL="Original"
        ;;
    *)
        echo "ERROR: ANAT_MODE must be 'defaced' or 'original' (got '${ANAT_MODE}')"
        exit 1
        ;;
esac

echo "=========================================================="
echo "FreeSurfer Verification Report"
echo "=========================================================="
echo "Anatomical input mode: ${ANAT_MODE}"
echo "FreeSurfer derivatives directory: ${DERIVS_DIR}"
printf "%-15s | %-15s | %-30s\n" "Subject" "Status" "Input Check"
echo "----------------------------------------------------------"

for SUBJ_DIR in "${DERIVS_DIR}"/sub-*; do
    [ -d "${SUBJ_DIR}" ] || continue
    SUBJ=$(basename "${SUBJ_DIR}")
    
    # 1. Check for completion
    LOG_FILE="${SUBJ_DIR}/scripts/recon-all.log"
    if [ -f "${LOG_FILE}" ] && tail -n 1 "${LOG_FILE}" | grep -q "finished without error"; then
        STATUS="SUCCESS"
    else
        STATUS="INCOMPLETE"
    fi

    # 2. Check provenance from the recon-all command in the log.
    if grep -q "${EXPECTED_LOG_PATTERN}" "${LOG_FILE}" 2>/dev/null; then
        INPUT_CHECK="Verified (${EXPECTED_LABEL} used)"
    else
        INPUT_CHECK="WARNING: Input unclear"
    fi

    printf "%-15s | %-15s | %-30s\n" "${SUBJ}" "${STATUS}" "${INPUT_CHECK}"
done

echo ""
echo "To visually verify the skull stripping and lack of face:"
echo "1. Login with X11 forwarding (ssh -Y user@cluster)"
echo "2. Run this command to verify a subject:"
echo "   apptainer exec /path/to/freesurfer.sif freeview -v \\"
echo "   ${DERIVS_DIR}/sub-002/mri/T1.mgz \\"
echo "   ${DERIVS_DIR}/sub-002/mri/brainmask.mgz:colormap=heat:opacity=0.4"
