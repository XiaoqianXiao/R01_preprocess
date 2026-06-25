#!/bin/bash

# --- CONFIGURATION ---
DERIVS_DIR="/gscratch/scrubbed/fanglab/xiaoqian/IFOCUS/derivatives/freesurfer"
OUTPUT_CSV="freesurfer_longitudinal_status.csv"

# Critical files for successful completion
REQUIRED_FILES=(
    "mri/brain.mgz"
    "mri/wmparc.mgz"
    "surf/lh.white"
    "surf/rh.white"
    "surf/lh.pial"
    "surf/rh.pial"
)

# --- HEADER ---
echo "Subject_ID,Type,State,Lock_Files,Missing_Files,Action_Needed" > "${OUTPUT_CSV}"

printf "\n%-35s %-12s %-10s %-8s %-15s\n" "FOLDER NAME" "TYPE" "STATE" "LOCKS" "ACTION"
echo "--------------------------------------------------------------------------------------------"

for subj_path in "${DERIVS_DIR}"/sub-*; do
    [ -d "$subj_path" ] || continue
    subj=$(basename "$subj_path")
    
    # --- Identify Processing Type ---
    if [[ "$subj" == *".long."* ]]; then
        type="LONG"       # Stage 3: Longitudinal
    elif [[ "$subj" == *"_base"* ]]; then
        type="BASE"       # Stage 2: Subject Template
    else
        type="CROSS"      # Stage 1: Cross-sectional
    fi

    state="Unknown"
    has_locks="No"
    action="None"
    missing_count=0

    # 1. Check for Lock Files
    if ls "${subj_path}/scripts/IsRunning"* 1> /dev/null 2>&1; then
        has_locks="YES"
        state="RUNNING"
    fi

    # 2. Check recon-all.log for Success/Failure
    log_file="${subj_path}/scripts/recon-all.log"
    if [ -f "$log_file" ]; then
        if grep -q "finished without error" "$log_file"; then
            state="COMPLETE"
        elif grep -q "exited with ERRORS" "$log_file"; then
            state="FAILED"
            action="Check .log"
        elif [ "$state" != "RUNNING" ]; then
            state="INCOMPLETE"
        fi
    else
        state="NO_START"
        action="Submit Job"
    fi

    # 3. Verify Critical File Existence
    for file in "${REQUIRED_FILES[@]}"; do
        if [ ! -f "${subj_path}/${file}" ]; then
            ((missing_count++))
        fi
    done

    # 4. Refine Status if Files are Missing
    if [ "$state" == "COMPLETE" ] && [ "$missing_count" -gt 0 ]; then
        state="CORRUPT"
        action="Delete/Re-run"
    fi

    # Output to Terminal and CSV
    printf "%-35s %-12s %-10s %-8s %-15s\n" "$subj" "$type" "$state" "$has_locks" "$action"
    echo "$subj,$type,$state,$has_locks,$missing_count,$action" >> "${OUTPUT_CSV}"
done

echo "--------------------------------------------------------------------------------------------"
echo "Summary saved to: ${OUTPUT_CSV}"