import os

def create_key(template, outtype=('nii.gz',), annotation_classes=None):
    if template is None or not template:
        raise ValueError('Template must be a valid format string')
    return template, outtype, annotation_classes

# --- Templates ---
# HeuDiConv automatically fills {subject} and {session}
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
        # Safety check for empty protocol names
        if not s.protocol_name:
            continue
            
        pname = s.protocol_name.lower()

        # ---------- ANAT ----------
        if pname.startswith('anat-t1w'):
            parts = pname.split('_')[1:]
            kwargs = {} # format dictionary
            
            for part in parts:
                if part.startswith('acq-'):
                    kwargs['acq'] = part[4:].replace(' ', '')
                elif part.startswith('rec-'):
                    kwargs['rec'] = part[4:]
                elif part.startswith('run-'):
                    kwargs['run'] = part[4:]
            
            # FIXED: Append tuple (series_id, formatting_dict)
            info[t1w].append((s.series_id, kwargs))

        # ---------- FUNC ----------
        elif pname.startswith('func-bold'):
            parts = pname.split('_')[1:]
            kwargs = {}
            
            for part in parts:
                if part.startswith('task-'):
                    kwargs['task'] = part[5:]
                elif part.startswith('acq-'):
                    kwargs['acq'] = part[4:]
                elif part.startswith('dir-'):
                    kwargs['dir'] = part[4:]
                elif part.startswith('run-'):
                    kwargs['run'] = part[4:]
            
            # FIXED: Append tuple
            info[bold].append((s.series_id, kwargs))

        # ---------- FMAP ----------
        elif pname.startswith('fmap-epi'):
            parts = pname.split('_')[1:]
            kwargs = {}
            
            for part in parts:
                if part.startswith('acq-'):
                    kwargs['acq'] = part[4:]
                elif part.startswith('dir-'):
                    kwargs['dir'] = part[4:]
                elif part.startswith('run-'):
                    kwargs['run'] = part[4:]
            
            # FIXED: Append tuple
            info[fmap_epi].append((s.series_id, kwargs))

    return info