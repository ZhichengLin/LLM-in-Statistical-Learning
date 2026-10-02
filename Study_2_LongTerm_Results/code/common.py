#!/usr/bin/env python3
"""Shared paths, hashing, keyed set fingerprints and the long-term eligibility rule (Python implementation).

Nothing here prints identifiers or participant values. Run configuration is read from OUT/records/run_config.json,
which run_all.py writes before any step (paths are parameters, not hard-coded study facts).
"""
import hashlib
import hmac
import json
import os
from pathlib import Path

CODE = Path(__file__).resolve().parent
PKG = CODE.parent
CONTRACT = PKG / 'analysis_contract.yaml'

TASKS = [(1, 6), (2, 5), (3, 6)]
ITEM_CODES = [f't{t}_q{i}' for t, n in TASKS for i in range(1, n + 1)]
WAVES = [('S1', 'stage1'), ('S2', 'stage2'), ('S3', 'stage3'), ('M1', 'follow'), ('LT', 'follow2')]
LABELS = ['AI', 'AI Human', 'Human']

# ---- eligibility rule (contract section `eligibility`) --------------------------------------------------------
ELIGIBLE, EXCLUDED_YES, EXCLUDED_UNKNOWN, NOT_RETURNED = 'eligible', 'excluded_reported_use', 'excluded_unknown', 'not_returned'


def classify_tool_use(returned, tool_value):
    """Long-term eligibility of one participant. Only an exact trimmed 'no' is eligible; 'yes' is excluded;
    anything else (blank, None, 'unsure', 'No', ...) is excluded as unknown. Non-returners are not classified."""
    if not returned:
        return NOT_RETURNED
    v = (tool_value if tool_value is not None else '').strip()
    if v == 'no':
        return ELIGIBLE
    if v == 'yes':
        return EXCLUDED_YES
    return EXCLUDED_UNKNOWN


def sha256(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def load_config(out):
    cfg_path = Path(out) / 'records' / 'run_config.json'
    if not cfg_path.exists():
        raise RuntimeError('run configuration missing; run the public entry point first')
    return json.loads(cfg_path.read_text())


def read_key(path):
    return Path(path).read_bytes()


def ensure_key(path):
    p = Path(path)
    if not p.exists():
        p.parent.mkdir(parents=True, exist_ok=True)
        os.chmod(p.parent, 0o700)
        fd = os.open(p, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(fd, 'wb') as f:
            f.write(os.urandom(32))
    return p.read_bytes()


def set_fingerprint(key, ids):
    """Keyed (HMAC-SHA256) fingerprint of a participant set; canonical form = sorted trimmed IDs joined by newline
    (byte order), identical to eligibility.R. Not reversible without the private key."""
    canon = '\n'.join(sorted(str(i).strip() for i in ids))
    return hmac.new(key, canon.encode('utf-8'), hashlib.sha256).hexdigest()


def write_private(path, text):
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    os.chmod(p.parent, 0o700)
    fd = os.open(p, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, 'w', encoding='utf-8') as f:
        f.write(text)
    os.chmod(p, 0o600)


def code_files(code_dir=None, extensions=('.py', '.R', '.Rmd', '.json')):
    """Every pipeline source bound into the READY record: all files under code_dir, recursively, with a bound
    extension (hidden files and __pycache__ excluded); sorted relative POSIX paths (byte order, as in guard.R)."""
    root = Path(code_dir) if code_dir else CODE
    rels = [p.relative_to(root).as_posix() for p in root.rglob('*')
            if p.is_file() and p.suffix in set(extensions) and not any(x.startswith('.') or x == '__pycache__'
                                                                       for x in p.relative_to(root).parts)]
    if (root.parent / 'run.R').is_file():
        rels.append('../run.R')
    return sorted(rels, key=lambda s: s.encode('utf-8'))
