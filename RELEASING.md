# Releasing

The BigWigs packager runs automatically on annotated tag push. Versions
follow `vMAJOR.MINOR.PATCH` (e.g. `v1.0.1`). Tags, the TOC `## Version:`
line, and CHANGELOG entries all use the `v` prefix.

## Pre-flight checklist

1. Add a new entry at the top of `CHANGELOG.md` for the version you're
   about to release.
2. Bump `## Version:` in `DontRelease.toc` to match the tag you'll push.
3. Sanity-check Lua syntax locally:

   ```bash
   for f in *.lua; do luac -p "$f" || break; done
   ```

4. Commit and push to `main`.

## Cutting a release

```bash
git tag -a v1.0.1 -m "v1.0.1"
git push origin --follow-tags
```

`--follow-tags` pushes the current branch plus any annotated tags
reachable from `HEAD`. If you ever forget to push `main` before tagging,
this still gets the tag's commit onto the remote so the release
workflow's `actions/checkout` step doesn't fail.

The workflow `.github/workflows/release.yml` triggers on tag push and runs
`BigWigsMods/packager@v2`. It will:

- Read `.pkgmeta`, drop the paths listed under `ignore:`, and package the
  remaining files into a `DontRelease/` folder inside the zip.
- Generate a release zip named `DontRelease-v1.0.1.zip`.
- Upload the zip to CurseForge (via `CF_API_KEY`), Wago (via
  `WAGO_API_TOKEN`), and create a GitHub Release attached to the tag
  (via `GITHUB_TOKEN`, auto-provided).
- Use `CHANGELOG.md` as the release-notes body (see `manual-changelog:`
  block in `.pkgmeta`).

## Required GitHub secrets

Configure under Settings → Secrets and variables → Actions:

| Secret | Source |
| --- | --- |
| `CF_API_KEY` | <https://legacy.curseforge.com/account/api-tokens> |
| `WAGO_API_TOKEN` | <https://addons.wago.io/account/apikeys> |
| `GITHUB_TOKEN` | (auto-provided; nothing to configure) |

## Project IDs

Set these in `DontRelease.toc` so the packager knows which CurseForge and
Wago projects to publish to:

```bash
## X-Curse-Project-ID: 123456
## X-Wago-ID: abc123def
```

Both lines are currently blank in the TOC. Fill them in once the projects
have been created on each platform.

## First-time project setup

When creating the project on CurseForge / Wago for the first time, the
**Project Summary** field (separate from the long description) wants ~150
characters of plain text. The recommended copy is at the top of
`CurseForge-description.md` inside an HTML comment so it sits next to the
long description but doesn't render if the whole file is pasted into the
description field by mistake.

## Regenerating bundled assets

Icons, banners, and the four "Whomp" sounds are procedurally generated.
Re-run the scripts in `tools/` to regenerate them with the latest
design / synthesis parameters:

```bash
python3 tools/make_icon.py     # writes Icon-256.png, Icon-128.png, Icon-64.png
python3 tools/make_banner.py   # writes Banner-1280.png, Banner-640.png
python3 tools/make_sounds.py   # writes Sounds/whomp1.ogg ... whomp4.ogg
```

`make_icon.py` also writes `Icon.tga` (the file the TOC actually
references). After the PIL save, it patches byte 17 of the TGA header to
`0x28` so WoW's TGA loader interprets the origin as top-left — without
this patch the icon renders upside-down in-game.

`make_sounds.py` is stdlib-only (no numpy/PIL) but requires `ffmpeg` on
PATH for the WAV → OGG step. Synthesis parameters (base pitch, semitone
step, vibrato, harmonic weights) are constants at the top of the file —
tweak and re-run to iterate on the timbre.

## Manual packaging (for testing)

If you want to test the packager output without pushing a tag:

```bash
curl -s https://raw.githubusercontent.com/BigWigsMods/packager/master/release.sh | bash -s -- -d
```

The `-d` flag skips uploading. Output ends up in `.release/`.
