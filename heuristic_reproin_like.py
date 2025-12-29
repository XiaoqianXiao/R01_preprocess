def create_key(template, outtype=('nii.gz',), annotation_classes=None):
    return template, outtype, annotation_classes


# ReproIn-style templates (session-aware)
t1w = create_key(
    'sub-{subject}/ses-{session}/anat/'
    'sub-{subject}_ses-{session}'
    '[_acq-{acq}]'
    '[_rec-{rec}]'
    '[_run-{run}]'
    '_T1w'
)

bold = create_key(
    'sub-{subject}/ses-{session}/func/'
    'sub-{subject}_ses-{session}'
    '_task-{task}'
    '[_acq-{acq}]'
    '[_dir-{dir}]'
    '[_run-{run}]'
    '_bold'
)

fmap_epi = create_key(
    'sub-{subject}/ses-{session}/fmap/'
    'sub-{subject}_ses-{session}'
    '[_acq-{acq}]'
    '_dir-{dir}'
    '[_run-{run}]'
    '_epi'
)


def infotodict(seqinfo):
    info = {
        t1w: [],
        bold: [],
        fmap_epi: [],
    }

    for s in seqinfo:
        pname = s.protocol_name.lower()

        # ---------- ANAT ----------
        if pname.startswith('anat-t1w'):
            info[t1w].append(s.series_id)

        # ---------- FUNC ----------
        elif pname.startswith('func-bold'):
            info[bold].append(s.series_id)

        # ---------- FMAP ----------
        elif pname.startswith('fmap-epi'):
            info[fmap_epi].append(s.series_id)

    return info
