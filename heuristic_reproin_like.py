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
            parts = pname.split('_')[1:]  # Skip 'anat-t1w'
            kwargs = {'item': s.series_id}
            for part in parts:
                if part.startswith('acq-'):
                    kwargs['acq'] = part[4:].replace(' ', '')  # Remove spaces if any
                elif part.startswith('rec-'):
                    kwargs['rec'] = part[4:]
                elif part.startswith('run-'):
                    kwargs['run'] = part[4:]
            info[t1w].append(kwargs)

        # ---------- FUNC ----------
        elif pname.startswith('func-bold'):
            parts = pname.split('_')[1:]  # Skip 'func-bold'
            kwargs = {'item': s.series_id}
            for part in parts:
                if part.startswith('task-'):
                    kwargs['task'] = part[5:]
                elif part.startswith('acq-'):
                    kwargs['acq'] = part[4:]
                elif part.startswith('dir-'):
                    kwargs['dir'] = part[4:]
                elif part.startswith('run-'):
                    kwargs['run'] = part[4:]
            info[bold].append(kwargs)

        # ---------- FMAP ----------
        elif pname.startswith('fmap-epi'):
            parts = pname.split('_')[1:]  # Skip 'fmap-epi'
            kwargs = {'item': s.series_id}
            for part in parts:
                if part.startswith('acq-'):
                    kwargs['acq'] = part[4:]
                elif part.startswith('dir-'):
                    kwargs['dir'] = part[4:]
                elif part.startswith('run-'):
                    kwargs['run'] = part[4:]
            info[fmap_epi].append(kwargs)

    return info