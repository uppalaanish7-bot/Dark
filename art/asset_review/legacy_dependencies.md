# Legacy actor dependencies

Review date: 6 October 2026. This is an inspection report; no gameplay, source models, textures, saves or packages were changed.

**None of the four current character models or the current boss art can be removed yet.** The player, ordinary enemies and boss share the same visual loader. The supplied `Game Asserts` directory is outside the Godot project, and no current script or scene references its models.

The supplied collection contains 22 GLBs: one female character, one boss, two boss guards and nine `BOSS` / `SLODIER` pairs. `Weapons` is empty. These are candidates for the next replacement stage. Folder labels and file presence do not establish compatible rigs, working animation or a level assignment; this report does not claim the new actors are ready to play.

## Dependency map

| Current resource or contract | Consumers and implications | Retirement condition |
| --- | --- | --- |
| Root `knight.glb`, `mage.glb`, `elf.glb`, `nain.glb` | `scripts/character_visual.gd:3-41` loads them dynamically. Both `player.gd` and `scripts/enemy.gd` instantiate that visual class. `scripts/boss.gd:21` forces knight index 0. | Replace the visual loading path for every player and enemy role, including the boss. Replacing only the selected player leaves live dependencies. |
| Eight root character colour PNGs: `knight_knight{first,second}_color.png`, `mage_sorcerer{First,Second}_color.png`, `elf_elf{First,Second}_color.png`, `nain_nain{First,Second}_color.png` | Each original GLB embeds the two corresponding images; current Godot import settings extract embedded textures. Keep the GLBs, their `.import` sidecars and extracted textures together during migration. | Retire with the last consumer of the matching old model, after checking the imported scene's resource dependencies. |
| `assets/{knight,mage,elf,nain}_animations.res` | The visual loader attaches a model-specific baked library. It assumes a `Skeleton3D`, `DEF-hand.R`, and original prop bones. Locomotion, pistol aiming, melee, damage, death, dodge and victory use its named clips. | Supply and verify a compatible animation adapter/library for each replacement skeleton; copying these libraries onto an unrelated rig is insufficient. |
| `Godot/AnimationLibrary_Godot_Standard.glb` and `tools/build_animations.gd` | The bake tool uses 19 source clips and explicit `DEF-*` bone mappings to generate the four libraries. `training_dummy.gd` also preloads the source. The live main game uses the baked libraries instead. | Keep as a reusable motion source until replacement motion is complete. It can leave the runtime export independently of keeping authoring files, but not be deleted while the old bake/dummy tools are retained unchanged. |
| `assets/warden_knight_knightfirst_color.png` and `assets/warden_knight_knightsecond_color.png` | `scripts/boss.gd:163-173` replaces knight material textures by name. There is no separate old boss GLB: it is the scaled knight with these overrides and a procedural sword. | Change the boss visual/material setup first. These two textures then become independently removable if no remaining references exist. |
| Procedural pistol, sword and muzzle in `scripts/character_visual.gd:47-63,111-150` | The pistol and sword are code-generated geometry, not files in a weapons directory. `player.gd:260-278` uses `visual.muzzle` for blocked-shot raycasts and effects. The sword follows the animated right hand and the boss invokes sword clips. | Keep the functioning weapon objects and muzzle interface until replacement weapons and attachment points exist. The empty incoming `Weapons` directory supplies no replacement. |
| `scripts/boss.gd` / `scripts/enemy.gd` | These are gameplay classes: navigation, collision, health, attack timing, warnings, damage, rewards and death. The game creates these classes and identifies `actor is BOSS` when saving. | Retain their gameplay behavior while replacing art. Removing the boss class would also break spawning, checkpoint restoration, wave completion and final-quest rewards. |
| Legacy `training_dummy.tscn/.gd`, `bullet.tscn/.gd`, `blood_ball.tscn/.gd`, `blood_puddle.tscn/.gd` | No incoming reference was found from the active `ground.tscn` / `player.tscn` / `scripts/` graph. They reference one another, and the dummy still references all old actors and the animation source. | An independent archive/cleanup candidate, not a required actor migration. Retire this branch coherently if cleanup is later requested. |

## Indices also carry gameplay and saved state

| Index | Current model / player class | Additional coupling |
| --- | --- | --- |
| 0 | Knight / Vanguard | Healing on elimination; reused by the boss. |
| 1 | Mage / Arcanist | Faster energy regeneration; ordinary enemies at index 1 use ranged attacks and a different speed. |
| 2 | Elf / Ranger | Player movement bonus. |
| 3 | Dwarf (`nain`) / Ironclad | Player damage reduction; visual scale and enemy head height differ. |

`scripts/campaign_data.gd` and `scripts/lobby.gd` define four selectable classes and their upgrades. `scripts/game.gd` saves selected skin as an integer in settings and cycles ordinary enemies modulo four. `scripts/progress.gd` stores exactly four upgrade ranks. `scripts/world_session.gd:83` clamps saved enemy skin indices to 0-3, while checkpoints record only a boss flag and that index, not an asset or role ID.

Keep these class identities and earned ranks stable for an art-only replacement. Changing to a single player character, assigning the nine incoming boss pairs to levels, or introducing guard/sub-boss roles requires a separate mapping and save migration. The current campaign still has three levels and one final-wave boss type; the incoming folders do not automatically create ten playable floors. The costume, character-skin and gun-skin pages contain empty slots, so there is no old portrait or cosmetic artwork to remove there.

## What is independent enough to retire

- **Active character/boss assets: none today.** Each model, its matching motion library and the boss overrides still have live consumers.
- The nine PNGs under `textures/` (`arm_skin`, `dummy_limb_skin`, `dummy_head_skin`, `dummy_torso_skin`, `gun_body_skin`, `gun_grip_skin`, `floor_concrete`, `wall_panel`, `pillar_metal`) have no source references beyond their own `.import` records in this review. They are independent legacy cleanup candidates, as is the inactive dummy/bullet/blood branch above. No cleanup was performed because the present stage is identification only.
- Exporting uses `all_resources`. Leaving unused legacy resources in the project can still include them in a package; changing a runtime loader alone is not proof that a subsequent package excludes old art. Keep existing backups and asset notices while any original art or source animation is reused.

## Smallest later migration sequence

1. Inspect the incoming GLBs for skeletons, bone names, animation clips, materials, scale and forward direction; choose explicit player, enemy, guard and boss mappings without changing level rules.
2. Add replacement visual/animation adapters that preserve the current movement, weapon, muzzle and actor interfaces. Keep class indices and save meanings stable unless a migration is intentionally designed.
3. Replace the boss material/weapon setup and normal-enemy visuals. Verify hitboxes, head heights, attack cues, hand attachments and resumed checkpoints against the new silhouettes.
4. Run the existing movement/combat, boss, campaign, story and save-resume checks. Replace old rig-name assertions with equivalent checks for the approved new rigs; preserve their behavioral coverage. Capture the actors in gameplay.
5. Only then audit remaining dynamic loaders, tools, legacy scenes and export dependencies, retire the unreferenced old art, reimport and rebuild packages.
