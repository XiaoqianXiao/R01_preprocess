#!/bin/bash
DERIVS_DIR="/gscratch/scrubbed/fanglab/xiaoqian/IFOCUS/derivatives/freesurfer"

echo "=========================================================="
echo "FreeSurfer Verification Report"
echo "=========================================================="
printf "%-15s | %-15s | %-30s\n" "Subject" "Status" "Defaced Input Check"
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

    # 2. Check provenance (Did it use the defaced file?)
    # We grep the log to see if the input command contained 'desc-defaced'
    if grep -q "desc-defaced" "${LOG_FILE}" 2>/dev/null; then
        INPUT_CHECK="Verified (Defaced used)"
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
