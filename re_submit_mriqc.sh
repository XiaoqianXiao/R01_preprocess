#!/bin/bash

# --- Set Defaults ---
file_pattern="${file_pattern:-mriqc_36878451_*.out}"
lines_to_check="${lines_to_check:-3}"
search_term="${search_term:-completed}"

# --- 1. Capture the failed files using the logic ---
mapfile -t failed_files < <(
    for file in $file_pattern; do
        if [[ -f "$file" ]]; then
            tail_chunk=$(tail -n "$lines_to_check" "$file" 2>/dev/null)
            if [[ "$tail_chunk" != *"$search_term"* ]]; then
                echo "$file"
            fi
        fi
    done
)

# --- 2. Extract Slurm Task IDs ---
failed_ids=()
for file in "${failed_files[@]}"; do
    if [[ -n "$file" ]]; then
        # Extracts the number right before '.out' (e.g., mriqc_36869418_11.out -> 11)
        task_id=$(basename "$file" | grep -oE '[0-9]+\.out$' | grep -oE '[0-9]+')
        if [[ -n "$task_id" ]]; then
            failed_ids+=("$task_id")
        fi
    fi
done

# --- 3. Safety Check and Count ---
if [ ${#failed_ids[@]} -eq 0 ]; then
    echo "No failed subjects found. Nothing to re-run!"
    exit 0
fi

# Join the IDs into a comma-separated list for Slurm (e.g., 0,11,12...)
array_list=$(IFS=,; echo "${failed_ids[*]}")

echo "Found ${#failed_ids[@]} failed subjects."
echo "Submitting Slurm array for task IDs: ${array_list}"

# --- 4. Submit targeted Slurm array ---
sbatch --array="${array_list}" mriqc_job.sh