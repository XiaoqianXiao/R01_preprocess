#!/bin/bash
#SBATCH --job-name=fs_long
#SBATCH --partition=cpu-g2
#SBATCH --account=fang
#SBATCH --nodes=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=12G
#SBATCH --time=24:00:00
#SBATCH --output=logs/fs_long_%x_%j.out

CONTAINER_SIF=/gscratch/fang/images/freesurfer.sif
LICENSE_FILE=/mmfs1/home/xxqian/files/fs_license.txt
DERIVS_DIR=/gscratch/scrubbed/fanglab/xiaoqian/IFOCUS/derivatives/freesurfer

module load apptainer 2>/dev/null || true

if [ "$STAGE" == "BASE" ]; then
    echo "Running STAGE: BASE for $SUBID"
    # TPS is passed as "-tp sub-001_ses-01 -tp sub-001_ses-02"
    apptainer exec -B "${DERIVS_DIR},${LICENSE_FILE}:/opt/freesurfer/license.txt" \
      --env FS_LICENSE=/opt/freesurfer/license.txt \
      "${CONTAINER_SIF}" \
      recon-all -base "${SUBID}_base" $TPS -sd "${DERIVS_DIR}" -all -parallel -openmp 4

elif [ "$STAGE" == "LONG" ]; then
    echo "Running STAGE: LONG for $TP using base ${SUBID}_base"
    apptainer exec -B "${DERIVS_DIR},${LICENSE_FILE}:/opt/freesurfer/license.txt" \
      --env FS_LICENSE=/opt/freesurfer/license.txt \
      "${CONTAINER_SIF}" \
      recon-all -long "${TP}" "${SUBID}_base" -sd "${DERIVS_DIR}" -all -parallel -openmp 4
fi