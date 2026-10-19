# Pillars Target Frames

A World of Warcraft: Forever addon (`## Interface: 16001`, Lua 5.1) built on ClaiibuAPI: a reskin of Blizzard's target, target of target and focus frames, laid out like Blizzard's target frame. The addon folder is `PillarsTargetFrames/`. Its sibling is cloudfan/Pillars-PlayerFrame (the player frame reskin); keep the two alike in look, settings style and code idiom.

## Layout

- `Settings.lua`: the kit, every default and every page.
- `Core.lua`: `ns.RegisterFeature`, `ns.ApplySettings`, `ns.IsSecret` / `ns.Plain`, the probe and `/ptf`.
- `UnitSkin.lua`: the reskin, one `Skin` object per frame, and the event handlers that dispatch to them.
- `Frames.lua`: the three frames (`ns.NewUnitSkin` specs).

## Rules

- **Per-frame settings.** Every frame has the same settings under its prefix (`tf` target, `tot` target of target, `ff` focus), built from `UNIT_DEFAULTS` (with `UNIT_OVERRIDES`) and `UnitPage` in `Settings.lua`. Add a per-frame setting there once, never per frame. Shared settings (the Look page) have no prefix.
- **Settings pages.** General first, then the other pages in alphabetical order; ClaiibuAPI adds Profiles last. A page is `PAGES["<Name>"] = function(page) ... end` in `Settings.lua`, listed in `PAGE_ORDER`. Never call `kit:AddPage` outside that loop, and never open a page by a fixed number: use `ns.pageIndex["<Name>"]`.
- Keep the README's settings tables (per-frame, then Look) in step with the pages, and its feature text in step with the landing page's `features` list.
- `reload = true` on every setting that moves, resizes or re-textures Blizzard's bars, and on Enable.
- Forever rules: every Lua file starts with `local addonName, ns = ...`; use `kit.events.On`, never an event frame of our own; read settings only after `kit:OnReady`; check `InCombatLockdown()` before touching protected frames and queue with `kit.events.AfterCombat`; guard secret values with `ns.Plain` / `ns.IsSecret` and pass them straight to status bars, `SetText`, `SetFormattedText` and `SetVertexColor`; no combat log, no `GetSpellInfo`/`GetItemInfo`; reskin Blizzard's frames, never replace, move, show, hide or give attributes to them. Blizzard's buffs, debuffs, cast bars and threat number are left alone.
- Check syntax with `luac5.1 -p` on every Lua file before committing.
- Releases: bump `## Version` in `PillarsTargetFrames/PillarsTargetFrames.toc` and run the Release workflow with tag `v<version>`.
