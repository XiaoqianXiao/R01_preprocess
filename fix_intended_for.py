import os
import json
import glob
from pathlib import Path

# --- Configuration ---
# Update this to your actual BIDS root directory
BIDS_ROOT = "/gscratch/scrubbed/fanglab/xiaoqian/IFOCUS/sourcedata/nii"

def update_intended_for(bids_dir):
    bids_path = Path(bids_dir)
    
    # Iterate over all subjects
    subjects = sorted(list(bids_path.glob("sub-*")))
    if not subjects:
        print(f"No subjects found in {bids_dir}")
        return

    for subj_dir in subjects:
        subj_id = subj_dir.name
        print(f"Processing {subj_id}...")

        # Iterate over all sessions
        sessions = sorted(list(subj_dir.glob("ses-*")))
        for ses_dir in sessions:
            ses_id = ses_dir.name
            func_dir = ses_dir / "func"
            fmap_dir = ses_dir / "fmap"

            # Skip if no fmap or func folder
            if not fmap_dir.exists() or not func_dir.exists():
                continue

            # 1. Find all BOLD files in this session
            # We need the path relative to the subject folder (e.g., ses-01/func/sub-01_...bold.nii.gz)
            func_files = sorted(list(func_dir.glob("*_bold.nii.gz")))
            intended_for_list = []
            
            for func_file in func_files:
                # Create relative path: ses-X/func/filename.nii.gz
                rel_path = f"{ses_id}/func/{func_file.name}"
                intended_for_list.append(rel_path)

            if not intended_for_list:
                continue

            # 2. Update every JSON in the fmap folder
            fmap_jsons = sorted(list(fmap_dir.glob("*.json")))
            for fmap_json in fmap_jsons:
                try:
                    with open(fmap_json, 'r') as f:
                        data = json.load(f)
                    
                    # Only update if different to avoid touching file timestamps unnecessarily
                    if data.get("IntendedFor") != intended_for_list:
                        data["IntendedFor"] = intended_for_list
                        
                        with open(fmap_json, 'w') as f:
                            json.dump(data, f, indent=4)
                        print(f"  -> Updated {fmap_json.name}")
                        
                except Exception as e:
                    print(f"  [ERROR] Could not update {fmap_json.name}: {e}")

if __name__ == "__main__":
    update_intended_for(BIDS_ROOT)
    print("Done!")
