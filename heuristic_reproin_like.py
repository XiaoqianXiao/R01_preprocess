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
        
        # Skip invalid protocols
        if not pname or '-' not in pname:
            continue

        parts = pname.split('_')
        
        # 1. Parse Datatype and Suffix
        head = parts[0].split('-')
        if len(head) < 2:
            continue 
            
        datatype = head[0] # e.g., func
        suffix = head[1]   # e.g., bold
        
        # 2. Parse Entities
        entities = {}
        for part in parts[1:]:
            if '-' in part:
                key, value = part.split('-', 1)
                entities[key] = value
        
        # 3. Construct the BIDS filename
        # CHANGE: Removed 'ses-' prefix here. 
        # We assume {session} already contains 'ses-pilot' from the bash script.
        filename_parts = [
            'sub-{subject}', 
            '{session}'
        ]
        
        for entity_key in bids_order:
            if entity_key in entities:
                val = entities[entity_key]
                filename_parts.append(f'{entity_key}-{val}')
        
        filename_parts.append(suffix)
        filename_base = '_'.join(filename_parts)
        
        # CHANGE: Removed 'ses-' prefix from directory path too.
        # Path: sub-{subject}/{session}/{datatype}/{filename_base}
        out_template = f'sub-{{subject}}/{{session}}/{datatype}/{filename_base}'
        
        key = create_key(out_template)
        
        if key not in info:
            info[key] = []
            
        info[key].append(s.series_id)

    return info