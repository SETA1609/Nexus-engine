#!/usr/bin/env python3
"""Validate workflow YAML files — no non-trivial logic inline in CI YAML."""
import os, yaml, sys

exit_code = 0
for root, dirs, files in os.walk('.github/workflows'):
    for f in files:
        if f.endswith('.yml') or f.endswith('.yaml'):
            path = os.path.join(root, f)
            try:
                yaml.safe_load(open(path))
            except Exception as e:
                print(f'FAIL: {path}: {e}')
                exit_code = 1
            else:
                print(f'OK: {path}')

sys.exit(exit_code)
