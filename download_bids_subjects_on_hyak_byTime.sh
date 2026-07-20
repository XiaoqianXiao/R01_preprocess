#!/usr/bin/env bash
set -euo pipefail

# Download Flywheel DICOM sessions by session timestamp.
#
# Usage:
#   export FW_KEY='...'
#   START_DATE=2026-06-22 LIST_ONLY=1 ./download_bids_subjects_on_hyak_byTime.sh
#   START_DATE=2026-06-22 LIST_ONLY=0 ./download_bids_subjects_on_hyak_byTime.sh
#
# If the Apptainer image does not already include the Flywheel Python SDK,
# this script installs it under /DATA_DIR/.python-userbase by default.
# Set INSTALL_SDK=0 to fail instead of installing.
#
# Notes:
#   - fw sync --include only filters file types, not dates.
#   - This script first queries sessions by date, writes a CSV manifest, then
#     downloads each matching session with fw download --include dicom.

IMAGE="${IMAGE:-/gscratch/fang/images/flywheel.sif}"
BIND_SRC="${BIND_SRC:-/gscratch/fang/IFOCUS/sourcedata/MRI}"
BIND_DEST="${BIND_DEST:-/DATA_DIR}"
PROJECT_PATH="${PROJECT_PATH:-fang-lab/IFOCUS}"
START_DATE="${START_DATE:-2026-06-22}"
LIST_ONLY="${LIST_ONLY:-1}"
JOBS="${JOBS:-4}"
MANIFEST="${MANIFEST:-${BIND_DEST}/sessions_since_${START_DATE}.csv}"
INSTALL_SDK="${INSTALL_SDK:-1}"
PYTHONUSERBASE="${PYTHONUSERBASE:-${BIND_DEST}/.python-userbase}"

if [[ -z "${FW_KEY:-}" ]]; then
    echo "Error: FW_KEY is not set. Run: export FW_KEY='your_flywheel_api_key'" >&2
    exit 1
fi

if [[ "${LIST_ONLY}" != "0" && "${LIST_ONLY}" != "1" ]]; then
    echo "Error: LIST_ONLY must be 0 or 1." >&2
    exit 1
fi

if [[ "${INSTALL_SDK}" != "0" && "${INSTALL_SDK}" != "1" ]]; then
    echo "Error: INSTALL_SDK must be 0 or 1." >&2
    exit 1
fi

apptainer exec \
    --env FW_KEY="${FW_KEY}" \
    --env PYTHONUSERBASE="${PYTHONUSERBASE}" \
    -B "${BIND_SRC}:${BIND_DEST}" \
    "${IMAGE}" \
    bash -s -- "${START_DATE}" "${LIST_ONLY}" "${MANIFEST}" "${PROJECT_PATH}" "${BIND_DEST}" "${JOBS}" "${INSTALL_SDK}" <<'CONTAINER_SCRIPT'
set -euo pipefail

START_DATE="$1"
LIST_ONLY="$2"
MANIFEST="$3"
PROJECT_PATH="$4"
BIND_DEST="$5"
JOBS="$6"
INSTALL_SDK="$7"

fw login "${FW_KEY}"

if ! python3 -c 'import flywheel' >/dev/null 2>&1; then
    if [[ "${INSTALL_SDK}" == "1" ]]; then
        echo "Flywheel Python SDK is missing; installing flywheel-sdk into ${PYTHONUSERBASE}."
        python3 -m pip install --user flywheel-sdk
    else
        cat >&2 <<MSG
Error: The Flywheel Python SDK is not installed in this Apptainer image.

The fw CLI can download data, but it cannot filter sessions by timestamp.
This script needs the Python SDK only for the date query step.

Rerun with:
  INSTALL_SDK=1 START_DATE=${START_DATE} LIST_ONLY=${LIST_ONLY} bash download_bids_subjects_on_hyak_byTime.sh

The SDK will be installed under:
  ${PYTHONUSERBASE}
MSG
        exit 1
    fi
fi

python3 - "$START_DATE" "$MANIFEST" "$PROJECT_PATH" <<'PY'
import csv
from datetime import date, datetime
import os
import sys

import flywheel

start_date, manifest, project_path = sys.argv[1:4]
start_day = date.fromisoformat(start_date)

fw = flywheel.Client(os.environ["FW_KEY"])
project = fw.lookup(project_path)


def timestamp_date(value):
    if value is None:
        return None
    if isinstance(value, datetime):
        return value.date()
    if isinstance(value, date):
        return value
    text = str(value)
    if len(text) >= 10:
        return date.fromisoformat(text[:10])
    return None

rows = []
for session in project.sessions.iter_find():
    session_day = timestamp_date(getattr(session, "timestamp", None))
    if session_day is None or session_day < start_day:
        continue

    full_session = fw.get(session.id)
    subject_id = full_session.parents.subject
    subject = fw.get(subject_id) if subject_id else None
    timestamp = getattr(full_session, "timestamp", "") or ""

    rows.append(
        {
            "subject_label": getattr(subject, "label", "") if subject else "",
            "session_label": getattr(full_session, "label", ""),
            "session_id": full_session.id,
            "timestamp": str(timestamp),
            "download_path": (
                f"{project_path}/"
                f"{getattr(subject, 'label', '')}/"
                f"{getattr(full_session, 'label', '')}"
            ),
        }
    )

rows.sort(key=lambda row: (row["timestamp"], row["subject_label"], row["session_label"]))
os.makedirs(os.path.dirname(manifest), exist_ok=True)

with open(manifest, "w", newline="") as f:
    writer = csv.DictWriter(
        f,
        fieldnames=[
            "subject_label",
            "session_label",
            "session_id",
            "timestamp",
            "download_path",
        ],
    )
    writer.writeheader()
    writer.writerows(rows)

print(f"Wrote {len(rows)} sessions to {manifest}")
PY

echo "Manifest:"
echo "  ${MANIFEST}"

if [[ "${LIST_ONLY}" == "1" ]]; then
    echo "LIST_ONLY=1, so no data were downloaded."
    echo "Review the manifest, then rerun with LIST_ONLY=0 to download."
    exit 0
fi

python3 - "$MANIFEST" <<'PY' | xargs -P "${JOBS}" -I {} fw download --yes "{}" -o "${BIND_DEST}" --include dicom
import csv
import sys

with open(sys.argv[1], newline="") as f:
    for row in csv.DictReader(f):
        path = row["download_path"]
        if path:
            print(path)
PY
CONTAINER_SCRIPT
