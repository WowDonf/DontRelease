<!-- CURSEFORGE SUMMARY -------------------------------------------------
Paste this into CurseForge's "Project Summary" field (NOT this file's body).
Plain text only, ~150 characters:

Blocks accidental release on raid wipes. A big warning covers the death dialog so a reflexive click can't drop you out of the fight.

Alternatives if the primary doesn't fit the listing well:
  - "Wipe-aware release guard: a warning frame that physically covers the Release button. Optional hold-to-dismiss for extra friction."
  - "Big 'DO NOT RELEASE' warning that sits on top of the death popup, so accidental release on wipes takes a deliberate act."
  - "Stops accidental release on raid wipes. Movable warning frame, hold-to-dismiss option, eleven configurable alert sounds."
------------------------------------------------------------------------- -->

# DontRelease

**Stop releasing on the first wipe. Wait for the battle res.**

A movable, recolorable, scalable warning frame that appears over the
standard death dialog whenever a raid wipe is detected. The message
defaults to "DO NOT RELEASE" with "Wait for battle res or raid leader's
call." underneath. Both lines, the color, the size, and the position are
configurable.

**While the warning is up, the Release Spirit button can't be clicked** —
the frame is sized to the popup and drawn above it with mouse input
enabled, so a reflexive click lands on the warning instead of on Release.
Normal release is available the instant the warning is dismissed.

The "wipe" is detected by counting dead raid members against a threshold
you set (default 3), plus an immediate trigger on the `ENCOUNTER_END`
event when an encounter ends in failure. Single deaths don't pop the
warning. While you're dead, the addon polls once per second so a wipe
that develops ten seconds after your own death still triggers the
warning (and trash-pull wipes, which have no `ENCOUNTER_END` to
backstop, get caught too). The frame auto-hides the instant a battle
res request arrives, and can be configured to suppress itself entirely
when a self-res is available (Soulstone, Reincarnation, or anything else
the client offers you on the death dialog).

---

## Why it's not just a "press X to release" reminder

Two layers of protection:

1. **The Release button is physically unreachable while the warning is
   up.** The frame is sized to whatever the death popup currently
   measures — including when a Soulstone or Reincarnation button widens
   it — and drawn above it with mouse input enabled. A reflex click at
   the spot where "Release Spirit" was hits the warning instead. The
   popup is fully usable again the moment the warning is dismissed.

2. **Optional hold-to-dismiss on the warning itself.** Enable "hold to
   close" and you must hold Shift / Ctrl / Alt for a configurable
   duration (default 1.5s) — with a visible gold progress bar at the
   bottom of the frame — to dismiss the warning. That's enough friction
   to prevent accidental dismissal while still being single-keystroke
   fast when you actually want to release.

---

## What's bundled

- **3 Blizzard alarm sounds** (Alarm 1 / 2 / 3)
- **8 custom .ogg sounds**
- All routable through **Master / SFX / Music / Ambience / Dialog** volume
  channels so the sound follows whichever in-game volume slider the user
  already cares about.
- Configurable color picker (wheel, RGB, hex)
- Scale slider 0.5x – 3.0x
- Wipe-threshold slider 1 – 30 dead raiders
- Hold-to-close with adjustable 0.5 – 5.0 second hold duration
- Suppression of the warning when a self-res is available — optional

---

## Slash commands

`/dnr` opens options. `/dnr help` lists every subcommand (toggle, scale,
threshold, sound, lock / unlock, reset, status). `/dontrelease` works as a
full-name alternative.
