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
DERIVS_ROOT=/gscratch/scrubbed/fanglab/xiaoqian/IFOCUS/derivatives
ANAT_MODE="${ANAT_MODE:-defaced}"

case "${ANAT_MODE}" in
    defaced)
        DERIVS_DIR="${FS_DERIVS_DIR:-${DERIVS_ROOT}/freesurfer}"
        ;;
    original)
        DERIVS_DIR="${FS_DERIVS_DIR:-${DERIVS_ROOT}/freesurfer_original}"
        ;;
    *)
        echo "ERROR: ANAT_MODE must be 'defaced' or 'original' (got '${ANAT_MODE}')"
        exit 1
        ;;
esac

module load apptainer 2>/dev/null || true
echo "Anatomical input mode: ${ANAT_MODE}"
echo "FreeSurfer derivatives directory: ${DERIVS_DIR}"

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
