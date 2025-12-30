import os

def create_key(template, outtype=('nii.gz',), annotation_classes=None):
    if template is None or not template:
        raise ValueError('Template must be a valid format string')
    return (template, outtype, annotation_classes)

def infotodict(seqinfo):
    info = {}
    # BIDS entities order
    bids_order = ['task', 'acq', 'ce', 'rec', 'dir', 'run', 'echo', 'part']

    for s in seqinfo:
        pname = s.protocol_name
        if not pname or '-' not in pname:
            continue

        parts = pname.split('_')
        head = parts[0].split('-')
        if len(head) < 2: continue 
            
        datatype = head[0] # func
        suffix = head[1]   # bold
        
        entities = {}
        for part in parts[1:]:
            if '-' in part:
                key, value = part.split('-', 1)
                entities[key] = value
        
        # NOTE: We use 'ses-{session}' here. 
        # The Bash script MUST pass a clean ID (e.g., '01') for this to work.
        filename_parts = ['sub-{subject}', '{session}']
        
        for entity_key in bids_order:
            if entity_key in entities:
                val = entities[entity_key]
                filename_parts.append(f'{entity_key}-{val}')
        
        filename_parts.append(suffix)
        filename_base = '_'.join(filename_parts)
        
        out_template = f'sub-{{subject}}/{{session}}/{datatype}/{filename_base}'
        
        key = create_key(out_template)
        if key not in info: info[key] = []
        info[key].append(s.series_id)

    return info