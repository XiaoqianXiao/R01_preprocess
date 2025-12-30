def create_key(template):
    return (template, ('nii.gz',), None)

t1w = create_key(
    'sub-{subject}/ses-{session}/anat/sub-{subject}_ses-{session}_T1w'
)

bold = create_key(
    'sub-{subject}/ses-{session}/func/sub-{subject}_ses-{session}_task-{task}_run-{run}_bold'
)

fmap = create_key(
    'sub-{subject}/ses-{session}/fmap/sub-{subject}_ses-{session}_dir-{dir}_epi'
)

def infotodict(seqinfo):
    info = {
        t1w: [],
        bold: [],
        fmap: [],
    }

    for s in seqinfo:
        name = (s.protocol_name or '').lower()

        # T1w
        if 't1w' in name:
            info[t1w].append(s.series_id)

        # BOLD
        elif 'bold' in name:
            info[bold].append(s.series_id)

        # Fieldmaps
        elif 'fmap' in name or 'epi' in name:
            info[fmap].append(s.series_id)

    return info