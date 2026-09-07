# DFT Personal Tactics Agent Guide

## Scope

This repository is the standalone `DFTPersonalTactics` World of Warcraft addon. `DreamForgeTools` is a required runtime dependency and is kept in the sibling repository at `../DreamForgeTools`.

## Required Workflow

For every change that touches Lua, the TOC, or DFT integration:

1. Run `./scripts/check-dft-update.sh` before editing. Verify: official metadata is reachable and no newer DFT release is waiting.
2. Run `./scripts/fetch-dft.sh /tmp/dft-upstream` before inspecting DFT behavior. Verify: the current closed-source DFT ZIP is downloaded and extracted, and record the printed version/path.
3. Read the downloaded `DreamForgeTools.toc` and the implementations of the integration points used by this addon. Verify: dependency name, interface version, event arguments, and notification spec remain valid. Use the sibling checkout only as a convenience, never as proof that the released DFT is unchanged.
4. Make the smallest change that solves the request. Verify: persistence remains in `DFTPersonalTacticsDB`, all supported difficulties remain distinct (`N`, `H`, `M`), and no DFT implementation is duplicated.
5. Run `luajit -b DFTPersonalTactics.lua /tmp/DFTPersonalTactics.luac`. Verify: the Lua file compiles.
6. Test in the WoW client with both addons enabled. Verify: `/dftpt`, the DFT options sidebar page when the host build includes it, the native WoW settings fallback otherwise, saving a formatted line, and one encounter schedule/cancel cycle.
7. Run `./scripts/check-dft-update.sh` again before release. Verify: the tested DFT version is still current and no update was missed.

## CurseForge Update Gate

The compatibility source of truth is the official DreamForge download page and its machine-readable manifest:

`https://dreamforgewow.com/?lng=en-US`

`https://dreamsrstorage.blob.core.windows.net/wowhead-assets/dft-meta.json`

The manifest currently provides `version`, `releasedAt`, `downloadUrl`, and `versionedUrl`. `scripts/fetch-dft.sh` consumes `downloadUrl`, downloads `DreamForgeTools-latest.zip`, and extracts it for source inspection. This is required because DFT is closed source; integration behavior must be checked from the released ZIP before assuming an API remains stable.

`scripts/check-dft-update.sh` is a fail-closed guard. A non-zero result means the official manifest was unavailable, malformed, or newer than the local DFT checkout. Stop the update and inspect the official download page manually; do not bypass the result silently. CurseForge remains a reference link only and is not required for automated checks.

The companion addon must declare `## RequiredDeps: DreamForgeTools`. If the host DFT build has a static sidebar list, it must list `DFTPersonalTactics` for DFT-sidebar integration. The official 2026.09.05 ZIP does not currently contain that entry, so the addon also registers a native WoW settings category as a fallback. The dependency remains one-way:

`DFTPersonalTactics -> DreamForgeTools`

Do not make DFT depend on this addon, which would create a circular load dependency.

## Integration Contract

Use only these DFT contracts unless the DFT repository documents a replacement:

- `DFT.Notify:Schedule(spec)` for `BAR` and `TTS` reminders.
- `DFT.Notify:CancelByTag(tag)` for cleanup.
- `DFT:On("BOSS_ENGAGED", encID, difficulty, t0, info)` for scheduling.
- `DFT:On("BOSS_DISENGAGED", ...)` for cancellation.
- `T:NewModule(name, displayName)` for module registration.
- The host DFT sidebar list only when the downloaded DFT build includes the module name.
- Native WoW Settings as the fallback when the host sidebar is static or unchanged.

Keep parser rules explicit. A malformed non-empty reminder line must fail the save operation. Do not silently coerce user input into a different time.

## Release Checklist

- Official DreamForge metadata update check passes before and after the change.
- DFT dependency and interface metadata are correct.
- LuaJIT syntax check passes.
- The DFT settings sidebar opens the personal tactics page when the host list includes it, or the native WoW settings fallback opens it otherwise.
- `/dftpt` opens the editor, and a line such as `{0:04} Burst` saves and schedules a DFT warning bar/TTS reminder.
- Enable/disable scheduling is controlled by the WoW settings checkbox; there are no command-line on/off switches.
- Encounter end cancels all reminders tagged `DFT_PERSONAL_TACTICS`.
- No generated files, secrets, or local WoW SavedVariables are committed.
