<p align="center">
  <img src="assets/dft-personal-tactics-logo.svg" alt="DFT Personal Tactics logo: a clock surrounding a teal-lit inn" width="760">
</p>

# DFT Personal Tactics

DFT Personal Tactics is a small companion addon for [DreamForgeTools](https://www.curseforge.com/wow/addons/dreamforgetools). It stores personal burst reminders per encounter and difficulty, then reuses DreamForgeTools `Notify` channels for the warning bar, countdown, and TTS.

<p align="center">
  <img src="assets/dft-personal-tactics-icon.svg" alt="DFT Personal Tactics addon icon" width="144">
</p>

## Install

Keep both addons as direct children of `Interface/AddOns`:

```text
Interface/AddOns/DreamForgeTools/
Interface/AddOns/DFTPersonalTactics/
```

The companion addon declares `DreamForgeTools` as a required dependency. It is not a replacement for DFT.

## Edit Reminders

Open the editor with `/dftpt`. On a DFT build whose sidebar list includes `DFTPersonalTactics`, it is also available at `DreamForgeTools -> 战斗 -> DFT 个人战术板`. The addon always registers a native WoW settings page as a fallback because the current official DFT ZIP does not include third-party sidebar registration.

Use one non-dynamic MRT reminder per line:

```text
{time:00:02.6} - {spell:42650}
{time:01:33.9} - Use cooldowns
{time:03:06.8} - Burst with {spell:42650}
```

The text after `-` is passed unchanged to DFT and may contain plain text, DFT-supported MRT tokens such as `{spell:42650}`, or both. `{time:00:02.6}` means 2.6 seconds after the encounter starts. Select the encounter ID and `N`, `H`, or `M` difficulty before saving. The default lead time is five seconds: DFT starts the warning bar and TTS at that point, and the bar ends at the configured burst time. Set lead time to `0` for an exact-time reminder.

When exporting from [lorrgs.io](https://lorrgs.io), disable **Dynamic Timer** before copying the note. Phase-relative lines such as `{time:00:54.8,p2}` are not supported because lorrgs phases do not consistently map to DFT encounter phases.

Minutes must be non-negative, seconds must be from `0` inclusive to `60` exclusive, and the reminder body must not be empty. Decimal seconds are supported. Empty lines are ignored. The previous `{M:SS} body` syntax and any other malformed non-empty line prevent the entire board from being saved, preserving the previously saved board.

## Commands

```text
/dftpt           Open the editor
```

Enable or disable scheduling from the checkbox in the WoW addon settings. Disabling does not delete saved reminders.

## Compatibility Workflow

The only supported runtime integration is the DFT public surface used by this addon:

- `DFT.Notify:Schedule`
- `DFT.Notify:CancelByTag`
- `DFT:On("BOSS_ENGAGED", ...)`
- `DFT:On("BOSS_DISENGAGED", ...)`
- `T:NewModule` in DFT
- The DFT options sidebar list, when the host build explicitly includes this module

Before changing either addon, run:

```bash
./scripts/check-dft-update.sh
```

The check fetches the official DreamForge metadata and compares its version with the sibling DFT checkout. It exits non-zero when the metadata is unavailable, malformed, or newer than the local DFT version.

DreamForgeTools is closed source. When source inspection is needed, use the same official download flow used by the website:

```bash
./scripts/fetch-dft.sh
```

This reads `dft-meta.json`, downloads its `downloadUrl` (`DreamForgeTools-latest.zip`), and extracts the addon into a temporary directory. The command prints the exact version and directory for inspection. For a stable location, pass a directory argument:

```bash
./scripts/fetch-dft.sh /tmp/dft-upstream
```

Then inspect the downloaded TOC and the integration code directly, for example:

```bash
rg -n 'NewModule|Notify:Schedule|BOSS_ENGAGED|BOSS_DISENGAGED' /tmp/dft-upstream/DreamForgeTools-*/DreamForgeTools/modules /tmp/dft-upstream/DreamForgeTools-*/DreamForgeTools/core
```

Do not use CurseForge as the automated compatibility source. Its project page is useful as a human reference, but it can return `403`; the official metadata and ZIP are the source used by the DreamForge website.

After a DFT update:

1. Run `./scripts/check-dft-update.sh` and record the official DFT version.
2. Run `./scripts/fetch-dft.sh /tmp/dft-upstream` and inspect the downloaded DFT source for changes to the APIs listed above.
3. Load both addons in a clean client session and test `/dftpt`, the DFT sidebar page, an editor save, and one real or simulated encounter.
4. Only publish this addon after the DFT version, source inspection, and client test pass. If the DFT sidebar list was not updated to include this addon, verify the native WoW settings fallback instead.

## Development

This repository contains the addon folder itself. Use LuaJIT for the local syntax check:

```bash
luajit -b DFTPersonalTactics.lua /tmp/DFTPersonalTactics.luac
```

Do not add a second notification engine or copy DFT's countdown implementation. Keep persistence local to this addon and keep DFT integration at the boundary above.
