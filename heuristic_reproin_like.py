import os

def create_key(template, outtype=('nii.gz',), annotation_classes=None):
    if template is None or not template:
        raise ValueError('Template must be a valid format string')
    return (template, outtype, annotation_classes)

# UPDATE: Added subject and session to arguments to allow sanitization
def infotodict(seqinfo, subject=None, session=None):
    """
    Heuristic to parse ReproIn-style protocol names directly.
    """
    
    # --- SANITIZATION STEP ---
    # This ensures we don't get 'ses-ses-pilot' even if the bash script passes 'ses-pilot'
    clean_session = str(session)
    if clean_session.startswith('ses-'):
        clean_session = clean_session[4:]
    
    # We hardcode the cleaned session into the string below, 
    # instead of letting HeuDiConv interpolate {session} automatically.
    # -------------------------

    info = {}
    
    # BIDS entities order
    bids_order = ['task', 'acq', 'ce', 'rec', 'dir', 'run', 'echo', 'part']

    for s in seqinfo:
        pname = s.protocol_name
        
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
        # Note: We use {subject} (letting HeuDiConv fill it), 
        # but we use our sanitized f'{clean_session}' immediately.
        filename_parts = [
            'sub-{subject}', 
            f'ses-{clean_session}'  # <--- This guarantees exactly one prefix
        ]
        
        for entity_key in bids_order:
            if entity_key in entities:
                val = entities[entity_key]
                filename_parts.append(f'{entity_key}-{val}')
        
        filename_parts.append(suffix)
        filename_base = '_'.join(filename_parts)
        
        # Path: sub-{subject}/ses-{clean_session}/{datatype}/{filename_base}
        out_template = f'sub-{{subject}}/ses-{clean_session}/{datatype}/{filename_base}'
        
        key = create_key(out_template)
        
        if key not in info:
            info[key] = []
            
        info[key].append(s.series_id)

    return info