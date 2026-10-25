# Tower performance notes

The saved rendered reference in `final_boss_master/rendered_metrics.txt` records 300 frames: 60.15 average FPS, 48.04 minimum instantaneous FPS, and a 20.82 ms longest frame, with no explicit FPS cap. That capture predates the current tower visibility and flight changes, so it is a reference point rather than a same-build before/after comparison.

Changes made for the current tower:

- Keep only the active arena floor visible and collidable during a fight. The next floor becomes visible and collidable while the lift is active or moving. This avoids drawing three full arenas and keeping all 44 floor panels in the physics broadphase at once.
- Refresh retinue navigation routes about every 0.56–0.68 seconds instead of every 0.32–0.44 seconds. Guardians keep the tighter 0.36–0.48 second cadence.
- Request the next floor's two character scenes asynchronously while the player boards the lift.
- Cap desktop frame output at 60 FPS and set first-run 3D rendering scale to 85%. The interface remains full resolution.
- Keep dynamic shadows disabled on combat lights, and cap each boss's summoned retinue at three active soldiers.

The updated 60 FPS capped profile ran on Intel UHD Graphics 730 and recorded 91 samples per floor. Floor one measured 62.35 average FPS, 30.25 minimum instantaneous FPS, 33.06 ms longest frame, and 156 average draw calls. Floor eleven with Nox and the retinue measured 60.49 average FPS, 44.85 minimum instantaneous FPS, 22.30 ms longest frame, and 177.9 average draw calls. See `final_boss_master/tower_rendered_profile.txt` for the raw values.

The average stayed near 60 FPS, but this short sample does not show a smoother worst frame than the older 300-frame reference. Scene counts and FPS caps differ, and the minimum frame values are sensitive to a single stutter. This is an honest first post-change measurement, not proof that every hitch is gone. Headless FPS is not used for the comparison.
