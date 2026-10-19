# Pillars Target Frames

A World of Warcraft: Forever addon (`## Interface: 16001`, Lua 5.1) built on ClaiibuAPI: target, target of target, focus and target's pet frames of its own in the Pillars look, with Blizzard's target, target of target and focus frames made invisible. The addon folder is `PillarsTargetFrames/`. Its sibling is cloudfan/Pillars-PlayerFrame (the player frame reskin); keep the two alike in look, settings style and code idiom.

## Layout

- `Settings.lua`: the kit, every default and every page.
- `Core.lua`: `ns.RegisterFeature`, `ns.ApplySettings`, `ns.IsSecret` / `ns.Plain`, the probe and `/ptf`.
- `UnitSkin.lua`: the frames, one `Skin` object per frame, and the event handlers that dispatch to them.
- `Frames.lua`: the four frames (`ns.NewUnitSkin` specs).

## Rules

- **One layout.** Every frame has the same settings under its prefix (`tf` target, `tot` target of target, `ff` focus, `tp` target's pet), built from `LAYOUT` (plus `COMBO_LAYOUT` for the frame with combo points), the short per-frame `OVERRIDES` list and `UnitPage` in `Settings.lua`. Add a per-frame setting there once, never per frame. Shared settings (the Look page) have no prefix. Colors are `page:Color` settings with presets and Custom.
- **Settings pages.** General first, then the other pages in alphabetical order; ClaiibuAPI adds Profiles last. A page is `PAGES["<Name>"] = function(page) ... end` in `Settings.lua`, listed in `PAGE_ORDER`. Never call `kit:AddPage` outside that loop, and never open a page by a fixed number: use `ns.pageIndex["<Name>"]`.
- Keep the README's settings tables (per-frame, then Look) in step with the pages, and its feature text in step with the landing page's `features` list.
- `reload = true` on Enable only: the frames are our own, and Blizzard's are only made invisible (alpha kept at 0, mouse off out of combat on their unprotected pieces only; the buff container `TargetFrameContent.TargetFrameContentContextual.Auras` is left visible). Turning a frame off needs a reload to bring Blizzard's back.
- Forever rules: every Lua file starts with `local addonName, ns = ...`; use `kit.events.On`, never an event frame of our own; read settings only after `kit:OnReady`; check `InCombatLockdown()` before touching protected frames and queue with `kit.events.AfterCombat`; guard secret values with `ns.Plain` / `ns.IsSecret` and pass them straight to status bars, `SetText`, `SetFormattedText` and `SetVertexColor`; no combat log, no `GetSpellInfo`/`GetItemInfo`; never show, hide, move or give attributes to Blizzard's frames; our frames are their children (so they follow Blizzard's visibility and Edit Mode), and the target's pet frame is shown by a unit watch. Target of target and target's pet sit on plain root frames moved by ClaiibuAPI Edit Mode movers (kit:AddEditMode). Never touch Blizzard's protected frames (no EnableMouse, no SetParent, no unit watch changes on them) or Edit Mode's Selection frames, and never change secure frames from inside Edit Mode callbacks: 2.4.0 did, and chat's Enter key was blocked until a client restart. Never touch Blizzard's buff and debuff buttons or their container (no SetPoint, SetScale, SetAlpha, hooks): on Forever it blocks Blizzard's aura code and taints chat until a client restart. Never read auras ourselves. Show nothing the client keeps from addons (threat, secret reactions, raid icons or cast times).
- Check syntax with `luac5.1 -p` on every Lua file before committing.
- Releases: bump `## Version` in `PillarsTargetFrames/PillarsTargetFrames.toc` and run the Release workflow with tag `v<version>`.
