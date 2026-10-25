# Cleanup audit

Review recorded: 21 October 2026. The audit identified **1,971 candidate files totalling 288,164,614 bytes (274.815 MiB)**. No candidate files were deleted.

| Candidate | Files | Bytes | Audit finding |
| --- | ---: | ---: | --- |
| `art/asset_review/motion_frames/` | 1,800 | 241,766,746 | Generated PNG review frames. |
| `art/asset_review/enemy_motion_upgrade/` | 150 | 45,193,920 | Generated PNG review frames. |
| `textures/` | 18 | 1,148,563 | Legacy PNGs and import sidecars; the audit found no references except their own sidecars. |
| Root `icon.svg` and `icon.svg.import` | 2 | 2,008 | Unused old icon; the active project icon is `assets/hero_icon.svg`. |
| `HERO_Architecture_Report.docx` | 1 | 53,377 | Identical file hash to the retained `HERO_Game_Architecture_Report.docx`. |
| **Total** | **1,971** | **288,164,614** | **274.815 MiB** |

The attempted deletion was rejected by automatic approval review with the message **`rejected: blocked by policy`**. No further reason was provided. No deletion was performed, and deletion was not retried or routed through another mechanism. This report records the candidates for review; it does not claim that disk space was recovered.

Preserve source `.blend` files, source assets, tools and rebuild inputs. Preserve backups consumed by `tools/rig_court_bosses.py`. Working models, animation resources, project files, active art, and player saves are outside this candidate set. Changes made concurrently by Antigravity require another dependency review before any later cleanup.
