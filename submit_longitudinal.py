import os
import subprocess
import glob

# --- Configuration ---
DERIVS_ROOT = "/gscratch/scrubbed/fanglab/xiaoqian/IFOCUS/derivatives"
ANAT_MODE = os.environ.get("ANAT_MODE", "defaced")
if ANAT_MODE not in {"defaced", "original"}:
    raise ValueError(f"ANAT_MODE must be 'defaced' or 'original' (got {ANAT_MODE!r})")

DERIVS_DIR = os.environ.get(
    "FS_DERIVS_DIR",
    os.path.join(DERIVS_ROOT, "freesurfer" if ANAT_MODE == "defaced" else "freesurfer_original"),
)
SBATCH_TEMPLATE = "long_stage.sbatch"

# Find all cross-sectional directories
folders = sorted(
    os.path.basename(d)
    for d in glob.glob(f"{DERIVS_DIR}/sub-*_ses-*")
    if ".long." not in os.path.basename(d) and not os.path.basename(d).endswith("_base")
)

print(f"Anatomical input mode: {ANAT_MODE}")
print(f"FreeSurfer derivatives directory: {DERIVS_DIR}")

# Group sessions by subject
# Results in: {'sub-001': ['sub-001_ses-01', 'sub-001_ses-02'], ...}
subject_map = {}
for f in folders:
    sub_id = f.split('_')[0]
    subject_map.setdefault(sub_id, []).append(f)

for sub_id, tp_list in subject_map.items():
    # 1. Submit the BASE stage
    # Pass all timepoints as a space-separated string
    tps = " ".join([f"-tp {tp}" for tp in tp_list])
    base_cmd = (
        f"sbatch --export=ALL,ANAT_MODE={ANAT_MODE},STAGE=BASE,"
        f"SUBID={sub_id},TPS='{tps}' {SBATCH_TEMPLATE}"
    )
    
    print(f"Submitting BASE for {sub_id}...")
    result = subprocess.run(base_cmd, shell=True, capture_output=True, text=True)
    
    # Get the Job ID of the Base run
    if result.returncode == 0:
        base_job_id = result.stdout.strip().split()[-1]
        
        # 2. Submit the LONG stage for each session, dependent on the BASE job
        for tp in tp_list:
            long_cmd = (f"sbatch --dependency=afterok:{base_job_id} "
                        f"--export=ALL,ANAT_MODE={ANAT_MODE},STAGE=LONG,SUBID={sub_id},TP={tp} {SBATCH_TEMPLATE}")
            subprocess.run(long_cmd, shell=True)
            print(f"  -> Queued LONG for {tp} (waiting for Job {base_job_id})")
