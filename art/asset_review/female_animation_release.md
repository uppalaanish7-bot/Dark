# Female character animation review

Verified 21 October 2026 using Godot 4.7.2, GL Compatibility renderer.

The shipped Girl Knight uses the supplied geometry and materials, a 20-bone
rig with three independent cape segments, and 51 animation clips. The repaired
cape region contains 78 vertices; neighboring calf armor remains leg-weighted.
The rest mesh is preserved within 0.028 mm of the source skin reconstruction.

Retained improvements include stable exploration/combat idle selection,
phase-preserving walk/jog/sprint blending, interruptible braking, minimum
landing and roll recovery, planted stationary feet, anatomical sword grip,
three distinct sword cuts, directed spell release, and delayed cape motion.

All of these validation scripts pass:

- `tests/female_character_validation.gd`
- `tests/player_animation_quality.gd`
- `tests/player_ground_contact_validation.gd`
- `tests/player_cast_motion_validation.gd`
- `tests/player_combat_validation.gd`

Measured female results:

| Check | Maximum error / result |
| --- | ---: |
| Skinned sole contact during stationary cuts and casts | 1.254 mm |
| Planted ankle drift during stationary combo | 9.410 mm |
| Sole rotation from rest plane during combo | 0 radians |
| Sword grip drift | 0.000120 mm |
| Moving attack gait advance per 60 Hz frame | 0.019787 cycles |
| Worst sword-to-target alignment at spell release | 0.999992 dot product |

Both players were tested to guard against shared-runtime regressions. Fresh
360-frame front and rear renders were reviewed for sprint, roll, jump,
three cuts, gathering magic, aimed release and recovery. Preview outputs:

- `art/asset_review/motion_previews/female_motion.gif`
- `art/asset_review/motion_previews/female_rear_motion.gif`
- `art/asset_review/motion_previews/female_contact_sheet.jpg`
- `art/asset_review/motion_previews/female_rear_contact_sheet.jpg`

The two prior cape-test failures were calf armor points at |x| = 0.158 m;
the true cape ends at |x| = 0.1516 m. The test now distinguishes them and
also asserts that the calf armor retains its leg binding.

This is a polished version of the existing low-poly fantasy character.
It does not add a photorealistic mesh, new facial rig, or simulated cloth.
The visual review uses desktop OpenGL; device performance is covered by
the separate Android packaging and device-validation workflow.
