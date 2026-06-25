#!/usr/bin/env bash
set -euo pipefail

FW_KEY=

IMAGE="/gscratch/fang/images/flywheel.sif"
BIND_SRC="/gscratch/fang/IFOCUS/sourcedata/MRI"
BIND_DEST="/DATA_DIR"
PROJECT_PATH="fang-lab/IFOCUS"

apptainer exec --env FW_KEY="$FW_KEY" -B "${BIND_SRC}:${BIND_DEST}" "$IMAGE" sh -c \
     "fw login \"\$FW_KEY\" && fw download $PROJECT_PATH -o ${BIND_DEST} --include dicom"
