# Changelog

## v1.2.1

- Updated for 12.1.5 "The Promise of Tomorrow" (interface 120105). The
  TOC declares both `120100` and `120105`, so the addon loads un-flagged
  on the 12.1.0 and 12.1.5 clients. No code changes: nothing in this
  patch touches the death popup, `C_DeathInfo`, the Settings API, or the
  sound calls the addon uses. The deprecated packages 12.1.5 removed
  (`Blizzard_DeprecatedSoundScript` and the rest) only carried functions
  like `PlayVocalErrorSoundID`, which the addon never called.

## v1.2.0

- Updated for 12.1.0 (interface 120100). Dropped the 12.0.x numbers, so
  this build is 12.1.0 only. The aura changes in this patch don't touch
  anything the addon uses.
- Fixed self-res suppression never seeing Soulstones. It was calling
  `HasSoulstone()`, deprecated since 7.3.5 and no longer answering, so
  only Reincarnation ever registered. Now uses
  `C_DeathInfo.GetSelfResurrectOptions()`, which covers whatever the
  death dialog is actually offering. `/dnr status` lists them by name.
- Dropped the Enter-blocking code. It set `noKeys` on the death popup,
  but that field is called `ignoreKeys` now, and the death popup doesn't
  install a key handler at all unless it sets `enterClicksFirstButton`,
  which it doesn't. So Enter was never releasing you in the first place
  and there's no flag that would have changed that. No behavior change:
  what stops an accidental release is the warning frame sitting on top of
  the Release button. Fixed the readme and store page, which claimed
  otherwise.

## v1.1.0

- **New alert sound — "Defeat"**: an original somber game-over sting (bells
  over a soft minor cadence). Brings the bundled total to 11 sounds.
  Selectable from the Sound dropdown and `/dnr` test, routable through the
  same volume channels as the others.
- **Patch 12.0.7 ("Revelations") compatibility**: TOC now declares both
  `120005` and `120007`, so the addon loads un-flagged on the current live
  client and the 12.0.7 client. No code changes were required — the new
  trailing `encounterUnitStatus` parameter on `ENCOUNTER_END` is
  backward-compatible with existing wipe detection.

## v1.0.0

Initial release.

- **Movable warning frame** over the standard death dialog on raid wipes.
  Configurable title text, subtitle text, color (RGB picker), and scale
  (0.5x – 3.0x).
- **Blocks Enter on the death popup** while the warning is visible by
  flipping `StaticPopupDialogs["DEATH"].noKeys`. Restored automatically
  on hide so a reflexive keystroke can't release you, but normal release
  works again the moment the warning is dismissed.
- **Wipe detection**: dead-raider threshold (configurable 1 – 30, default
  3), immediate trigger on `ENCOUNTER_END(success=0)`, and a 1Hz poll
  while the player is dead so slow-cascading wipes — including trash
  pulls that have no `ENCOUNTER_END` to backstop — still trigger the
  warning.
- **Hold-to-close** option: require Shift / Ctrl / Alt to be held for a
  configurable duration (default 1.5s; range 0.5 – 5.0s) instead of a
  single press. A gold progress bar at the bottom of the frame fills as
  the user holds.
- **Smart suppression**: auto-hides on incoming battle-res request;
  optionally suppresses entirely when self-res is available (Soulstone,
  Shaman Reincarnation).
- **10 alert sounds**: 3 Blizzard alarms plus 7 bundled custom .ogg
  files (4 Womp variants + 3 Boop variants). Routable through Master /
  SFX / Music / Ambience / Dialog volume channels.
- **`/dnr` and `/dontrelease` slash commands**: toggle, threshold, scale,
  sound, lock/unlock, reset, status.
- **Addon compartment entry** next to the minimap. Left-click opens
  options, right-click toggles enabled.
- **Saved-variable validation and migration** with safe defaults on load
  and corruption recovery on type mismatch.
