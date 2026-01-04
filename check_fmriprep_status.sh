#!/bin/bash

# --- CONFIGURATION (UPDATE THIS PATH) ---
DERIVS_DIR="/gscratch/scrubbed/fanglab/xiaoqian/IFOCUS/derivatives/fmriprep"
# ----------------------------------------

# Define Output CSV
OUTPUT_CSV="fmriprep_status_report.csv"
echo "Subject,HTML_Report,Anat_Preproc,Func_Preproc,Confounds,Status" > "${OUTPUT_CSV}"

echo "======================================================================"
echo "Checking fMRIPrep Outputs in: ${DERIVS_DIR}"
echo "======================================================================"

printf "%-15s %-10s %-15s %-15s %-15s %-15s\n" "SUBJECT" "HTML" "ANAT (T1w)" "FUNC (BOLD)" "CONFOUNDS" "STATUS"
echo "----------------------------------------------------------------------"

# Find all subject folders (sub-*) inside the directory
for subj_path in "${DERIVS_DIR}"/sub-*; do
    [ -d "$subj_path" ] || continue
    subj=$(basename "$subj_path")
    
    # 1. Check for HTML Report (The most obvious sign of completion)
    #    Note: It usually lives in the main directory, outside the subject folder
    if [ -f "${DERIVS_DIR}/${subj}.html" ]; then
        html_status="OK"
    else
        html_status="MISSING"
    fi

    # 2. Check Anatomical Output (T1w preproc)
    #    This confirms the structural pipeline finished
    if ls "${subj_path}/ses-"*"/anat/${subj}_"*_desc-preproc_T1w.nii.gz 1> /dev/null 2>&1 || \
       ls "${subj_path}/anat/${subj}_"*_desc-preproc_T1w.nii.gz 1> /dev/null 2>&1; then
        anat_status="OK"
    else
        anat_status="MISSING"
    fi

    # 3. Check Functional Output (BOLD preproc)
    #    We look for at least ONE preprocessed BOLD file
    if ls "${subj_path}/ses-"*"/func/${subj}_"*_desc-preproc_bold.nii.gz 1> /dev/null 2>&1 || \
       ls "${subj_path}/func/${subj}_"*_desc-preproc_bold.nii.gz 1> /dev/null 2>&1; then
        func_status="OK"
    else
        func_status="MISSING"
    fi

    # 4. Check Confounds (Essential for analysis)
    if ls "${subj_path}/ses-"*"/func/${subj}_"*_desc-confounds_timeseries.tsv 1> /dev/null 2>&1 || \
       ls "${subj_path}/func/${subj}_"*_desc-confounds_timeseries.tsv 1> /dev/null 2>&1; then
        conf_status="OK"
    else
        conf_status="MISSING"
    fi

    # Determine Overall Status
    if [ "$html_status" == "OK" ] && [ "$anat_status" == "OK" ] && [ "$func_status" == "OK" ]; then
        status="COMPLETE"
    else
        status="INCOMPLETE"
    fi

    # Print to Screen
    printf "%-15s %-10s %-15s %-15s %-15s %-15s\n" "$subj" "$html_status" "$anat_status" "$func_status" "$conf_status" "$status"
    
    # Save to CSV
    echo "$subj,$html_status,$anat_status,$func_status,$conf_status,$status" >> "${OUTPUT_CSV}"
done

echo "----------------------------------------------------------------------"
echo "Report saved to: ${OUTPUT_CSV}"
