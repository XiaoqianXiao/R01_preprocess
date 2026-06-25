#!/usr/bin/env bash
set -euo pipefail

IMAGE="/gscratch/fang/images/flywheel.sif"
BIND_SRC="/gscratch/fang/IFOCUS/sourcedata/MRI"
BIND_DEST="/DATA_DIR"
PROJECT_PATH="fang-lab/IFOCUS"

apptainer exec --env FW_KEY="$FW_KEY" -B "${BIND_SRC}:${BIND_DEST}" "$IMAGE" sh -c \
     "fw login \"\$FW_KEY\" && fw sync $PROJECT_PATH ${BIND_DEST} --include 'session.timestamp > 2026-01-01' --include dicom --jobs 4"
