# Changelog

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
