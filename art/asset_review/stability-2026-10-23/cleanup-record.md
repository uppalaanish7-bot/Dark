# Stability 2026-10-23 cleanup record

Removed after inspection:

- `tools/__pycache__/audit_provided_assets.cpython-313.pyc` and `tools/__pycache__/create_hollow_spire.cpython-313.pyc` — Python bytecode caches; source scripts remain in `tools/` and Python regenerates these files.
- `borrowed_dawn_test_830984_progress.cfg` and its `.bak` in Godot's `RELIC - Arena Protocol` user-data directory — isolated profile files created by this run of `tests/story_validation.gd`; the test aborted before its own cleanup.

Retained the Godot `.godot` import/editor data, Android build/staging outputs, existing test `.bak` files, models, textures, scenes, and all source assets. Those are either actively used/generated project data or not attributable to this cleanup run.

The now-empty `tools/__pycache__` directory remains because Windows marks it read-only; its bytecode files were removed. No recursive cleanup was attempted.
