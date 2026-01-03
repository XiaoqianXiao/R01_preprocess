#!/bin/bash

# --- CONFIGURATION ---
DERIVS_DIR="/gscratch/scrubbed/fanglab/xiaoqian/IFOCUS/derivatives/freesurfer"
OUTPUT_CSV="freesurfer_status_report.csv"

# Critical files for SUBJECTS
REQUIRED_FILES=(
    "mri/brain.mgz"
    "mri/wmparc.mgz"
    "surf/lh.white"
    "surf/rh.white"
    "surf/lh.pial"
    "surf/rh.pial"
    "surf/lh.sphere.reg"
    "surf/rh.sphere.reg"
)

# --- PART 1: CHECK THE TEMPLATE (fsaverage) ---
echo "==================================================================================="
echo "PHASE 1: Checking fsaverage Template Integrity"

TEMPLATE_DIR="${DERIVS_DIR}/fsaverage"
BA1_LABEL="${TEMPLATE_DIR}/label/lh.BA1_exvivo.label"

if [ ! -d "$TEMPLATE_DIR" ]; then
    echo "[WARN] fsaverage folder MISSING. (Safe: fMRIPrep will create it)"
    TEMPLATE_STATUS="MISSING (Safe)"
elif [ ! -f "$BA1_LABEL" ]; then
    echo "[CRITICAL] fsaverage exists but is MISSING 'BA1_exvivo.label'."
    echo "           Action: You MUST delete this folder: rm -rf ${TEMPLATE_DIR}"
    TEMPLATE_STATUS="CORRUPT"
else
    echo "[OK] fsaverage template looks valid (BA1_exvivo found)."
    TEMPLATE_STATUS="VALID"
fi
echo "==================================================================================="

# --- PART 2: CHECK SUBJECTS ---
echo "PHASE 2: Scanning Subjects in ${DERIVS_DIR}"
echo "Subject,State,Lock_Files,Missing_Files,Action_Needed,Template_Status" > "${OUTPUT_CSV}"

printf "\n%-25s %-15s %-10s %-10s %-20s\n" "SUBJECT" "STATE" "LOCKS" "MISSING" "ACTION"
echo "-----------------------------------------------------------------------------------"

for subj_path in "${DERIVS_DIR}"/sub-*; do
    [ -d "$subj_path" ] || continue
    subj=$(basename "$subj_path")
    
    state="Unknown"
    has_locks="No"
    action="None"
    missing_count=0

    # 1. Check Locks
    if ls "${subj_path}/scripts/IsRunning"* 1> /dev/null 2>&1; then
        has_locks="YES"
        state="LOCKED"
        action="DELETE LOCKS"
    fi

    # 2. Check Log
    log_file="${subj_path}/scripts/recon-all.log"
    if [ -f "$log_file" ]; then
        last_line=$(tail -n 1 "$log_file")
        if [[ "$last_line" == *"finished without error"* ]]; then
            [ "$state" == "Unknown" ] && state="Complete"
        elif [[ "$last_line" == *"exited with ERRORS"* ]]; then
            state="CRASHED"
            action="Check Log"
        else
            state="Running"
        fi
    else
        state="No_Log"
    fi

    # 3. Check Files
    for file in "${REQUIRED_FILES[@]}"; do
        if [ ! -f "${subj_path}/${file}" ]; then
            ((missing_count++))
        fi
    done

    # 4. Corrupt Check
    if [ "$state" == "Complete" ] && [ "$missing_count" -gt 0 ]; then
        state="CORRUPT"
        action="Re-run recon-all"
    fi

    printf "%-25s %-15s %-10s %-10s %-20s\n" "$subj" "$state" "$has_locks" "$missing_count" "$action"
    echo "$subj,$state,$has_locks,$missing_count,$action,$TEMPLATE_STATUS" >> "${OUTPUT_CSV}"
done

echo "-----------------------------------------------------------------------------------"
echo "Done! Report: ${OUTPUT_CSV}"