apptainer pull heudiconv.sif docker://nipy/heudiconv:latest

DICOM_ROOT=/gscratch/fang/IFOCUS/sourcedata/dicom
BIDS_ROOT=//gscratch/fang/IFOCUS/sourcedata/nii
HEURISTIC=/path/to/heuristic_reproin_like.py

for subj in $(ls $DICOM_ROOT); do
    echo "Processing subject $subj"

    heudiconv \
      -d $DICOM_ROOT/{subject}/ses-{session}/*/*dcm \
      -s $subj \
      -ss pilotTR1500 \
      -f $HEURISTIC \
      -c dcm2niix \
      -b \
      -o $BIDS_ROOT
done