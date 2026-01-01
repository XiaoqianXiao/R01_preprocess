#!/bin/bash
BIDS_ROOT=/gscratch/scrubbed/fanglab/xiaoqian/IFOCUS/sourcedata/nii

# 1. Define the subjects you want to re-run
#    (Space-separated list)
TARGETS=("sub-318" "sub-326" "sub-330")

echo "Searching for indices for: ${TARGETS[*]}"

# 2. Generate the full sorted list of subjects exactly as the sbatch script does
#    (Must match the logic in recon_all.sbatch: find ... | sort)
all_subjects=( $(find "${BIDS_ROOT}" -maxdepth 1 -type d -name "sub-*" | sort | xargs -n 1 basename) )

# 3. Find the indices
indices=()
for target in "${TARGETS[@]}"; do
    found=false
    for i in "${!all_subjects[@]}"; do
        if [[ "${all_subjects[$i]}" == "${target}" ]]; then
            indices+=($i)
            echo "  -> Found ${target} at Array Index ${i}"
            found=true
            break
        fi
    done
    if [ "$found" = false ]; then
        echo "  [WARNING] Could not find ${target} in ${BIDS_ROOT}"
    fi
done

# 4. Join indices with commas for sbatch (e.g., "45,50,52")
IFS=,
ARRAY_STRING="${indices[*]}"
unset IFS

if [ -z "$ARRAY_STRING" ]; then
    echo "No valid subjects found. Exiting."
    exit 1
fi

# 5. Submit
echo "---------------------------------------------------"
echo "Submitting job array for indices: ${ARRAY_STRING}"
echo "---------------------------------------------------"
sbatch --array=${ARRAY_STRING} recon_all.sbatch
