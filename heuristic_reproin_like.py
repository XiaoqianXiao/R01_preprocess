import os

def create_key(template, outtype=('nii.gz',), annotation_classes=None):
    if template is None or not template:
        raise ValueError('Template must be a valid format string')
    return (template, outtype, annotation_classes)

def infotodict(seqinfo):
    """
    Heuristic to parse ReproIn-style protocol names directly.
    Expects protocol_names (folder names) like:
    - func-bold_task-rest_run-01
    - anat-T1w
    - fmap-epi_dir-AP
    - dwi-dwi_acq-98dir_dir-AP
    """
    
    info = {}
    
    # BIDS entities order is strict. 
    # We will parse the folder name parts and re-assemble them in this order.
    # Note: 'mod' and 'recording' are less common but included for completeness.
    bids_order = ['task', 'acq', 'ce', 'rec', 'dir', 'run', 'echo', 'part']

    for s in seqinfo:
        # ReproIn convention: The protocol name usually acts as the source
        # format: datatype-suffix_entity-value_entity-value...
        pname = s.protocol_name
        
        # Skip if no protocol name or likely not a ReproIn sequence
        if not pname or '-' not in pname:
            continue

        parts = pname.split('_')
        
        # 1. Parse Datatype and Suffix (First segment: e.g., "func-bold")
        head = parts[0].split('-')
        if len(head) < 2:
            continue # malformed
            
        datatype = head[0] # e.g., func, anat, dwi, fmap
        suffix = head[1]   # e.g., bold, T1w, dwi, epi
        
        # 2. Parse Entities (Remaining segments: e.g., "task-rest", "run-01")
        entities = {}
        for part in parts[1:]:
            if '-' in part:
                key, value = part.split('-', 1)
                entities[key] = value
        
        # 3. Construct the BIDS filename
        # Start with subject and session
        # pattern: sub-{subject}_ses-{session}
        filename_parts = ['sub-{subject}', 'ses-{session}']
        
        # Add entities in strict BIDS order
        for entity_key in bids_order:
            if entity_key in entities:
                # Handle special casing if needed (usually just string insertion)
                val = entities[entity_key]
                filename_parts.append(f'{entity_key}-{val}')
        
        # Add suffix
        filename_parts.append(suffix)
        
        # Join with underscores
        filename_base = '_'.join(filename_parts)
        
        # Construct full path key
        # Path: sub-{subject}/ses-{session}/{datatype}/{filename_base}
        out_template = f'sub-{{subject}}/ses-{{session}}/{datatype}/{filename_base}'
        
        # 4. Create the key and assign series
        key = create_key(out_template)
        
        if key not in info:
            info[key] = []
            
        info[key].append(s.series_id)

    return info