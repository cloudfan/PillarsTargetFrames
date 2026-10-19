# Pillars Target Frames

Target, target of target and focus frames for World of Warcraft: Forever (`## Interface: 16001`), built on [ClaiibuAPI](https://github.com/cloudfan/ClaiibuAPI) (API level 1; 1.7.0 or newer for the color settings, 1.8.0 for their preset dropdowns with Custom...), which must be installed. The sibling of [Pillars Player Frame](https://github.com/cloudfan/Pillars-PlayerFrame), in the same look.

## Features

- One layout for every frame: name bar, health bar, resource bar and portrait, with a short list of changes per frame. Every bar, the portrait, the cast bar and the combo points can be resized and attached to another bar at any anchor point.
- Your combo points on the target frame (rogues, and druids in cat form), in round totem borders tinted with the Border Tint.
- A cast bar over the resource bar, or a bar of its own that shows only while casting.
- Blizzard's own buffs and debuffs, left where Blizzard places them (Buffs on Top and their sizes are in Edit Mode, under the target and focus frames).
- Dead units get a gray-blue background (`0.4, 0.47, 0.6` at 75%) and a portrait at 30% opacity.
- Shared border, border tint, background, background color, bar texture, font, font size, shadow and colors, each color with presets and Custom... (Blizzard's color picker).

Blizzard's target, target of target and focus frames (the focus frame's own target of target too), and everything on them (art, bars, text, cast bar, flashes, threat number), are made invisible. They keep running underneath: the new frames are their children, so they show when Blizzard's would (the target of target follows Blizzard's own Target of Target setting). The target and focus frames move with Blizzard's in Edit Mode (Blizzard's own highlight is left as it is). The target of target frame has its own box in Edit Mode (through ClaiibuAPI), labeled with its name, and starts where Blizzard's target of target was. Portraits are 3D models held still on their first frame. Blizzard's buff and debuff container (`TargetFrameContent.TargetFrameContentContextual.Auras` on build 70450) is left visible and never touched: on Forever, moving Blizzard's aura buttons blocks its aura code and spreads taint until a client restart (chat's Enter key stops working). The target and focus frames sit just above them by default (Above Blizzard's Buffs), and follow them when Blizzard moves them. The frames cannot draw buff icons of their own either: on build 70450 the client gives addons the target's auras out of combat but refuses every way of reading them in combat (`C_UnitAuras` ID lists and slot functions, `GetBuffDataByIndex`/`GetDebuffDataByIndex`, `AuraUtil.ForEachAura`: "Auras cannot be accessed when secret while tainted"), and the old `UnitBuff`, `UnitDebuff` and `UnitAura` do not exist, so Blizzard's own display is the only one that works in combat. Left-click a frame to target the unit, right-click for its menu. The addon never changes Blizzard's protected frames or Edit Mode's own frames, which keeps them from tainting chat and other Blizzard code.

Nothing the client keeps from addons is shown: there is no threat display, no aura reading of our own, and a reaction, cast time or combo point count the client keeps secret is left out. Health, names and levels can be secret on Forever; they go straight to the bars and text.

Settings are under Options → AddOns → Pillars Target Frames: General, then Focus, Look, Target and Target of Target, and Profiles last (save, delete, export and import).

## Settings

### Per frame (Focus, Target and Target of Target pages)

Each frame has these settings under its prefix: `tf` (Target), `tot` (Target of Target), `ff` (Focus), so `tfHealthWidth`, `totHealthWidth` and so on. The defaults are one layout (the target's); the frames differ only where the last column says.

Focus and Target of Target follow the Target page section by section. Each section on their pages (Health Bar, Resource Bar, Name Bar, Portrait, Cast Bar) starts with an **Override Target's ...** toggle (`ffOverrideHealth`, `totOverridePortrait` and so on). Unchecked, that section uses the Target page's settings; checked, the frame's own settings below it. A toggle starts checked where the frame's own defaults differ: Focus's Portrait; Target of Target's Portrait, Resource Bar and Cast Bar. Enable and the frame's offsets are always the frame's own.

| Key | Type | Default | Differs on | What it changes |
|---|---|---|---|---|
| `Enabled` | Checkbox (asks to reload) | `true` | | Show this frame; unchecked, Blizzard's comes back after a reload. |
| `OverrideHealth`, `OverridePower`, `OverrideName`, `OverridePortrait`, `OverrideCast` | Checkboxes | `false` | Focus and ToT only. On by default: Focus `OverridePortrait`; ToT `OverridePortrait`, `OverridePower`, `OverrideCast` | Use this frame's own settings for that section instead of the Target page's. |
| `AboveBuffs` | Checkbox | `true` | Target and Focus only | The frame sits just above Blizzard's buffs and debuffs (its bottom left at the top left of Blizzard's buff container, combo points and a separate cast bar included), or just below them with Edit Mode's Buffs on Top. Blizzard's container is only used as an anchor, never changed, so the frame follows it. Unchecked, the frame sits in the middle of Blizzard's frame. |
| `OffsetX`, `OffsetY` | Sliders −200 to 200 (−1500 to 1500 on ToT) | `0`, `0` | | Target and Focus: moves the frame from its place above Blizzard's buffs (or inside Blizzard's frame with Above Blizzard's Buffs off). Target of Target: the frame's place on the screen from `Point`, set by dragging it in Edit Mode. |
| `Point`, `Placed` | Anchor, hidden flag | `CENTER`, `false` | ToT only | The screen point the offsets count from. `Placed` is set the first time the frame is put by Blizzard's target of target **Put Back by the Target Frame** clears it. |
| `HealthWidth`, `HealthHeight` | Sliders 20–400, 4–120 | `160`, `24` | | Health bar size; the other bars match it unless they have their own size. |
| `HealthColor` | Dropdown (health color, reaction, class color) | `color` | | Health Color from the Look page, the unit's reaction, or players' class colors. A secret reaction falls back to Health Color. |
| `HealthText`, `HealthTextPoint` | Dropdown (full, abbreviated, percentage, both, none), anchor | `percent`, `CENTER` | | Text on the health bar. |
| `PowerShow` | Checkbox | `true` | ToT: `false` | The resource bar. |
| `PowerOwnSize`, `PowerWidth`, `PowerHeight` | Checkbox, sliders 20–400, 4–120 | `false`, `160`, `24` | | The resource bar's own size; unchecked, the health bar's. |
| `PowerTarget`, `PowerPoint`, `PowerX`, `PowerY` | Dropdown (health, resource, name bar), anchor, sliders −100 to 100 | `health`, `BOTTOM`, `0`, `0` | | Where the resource bar attaches. |
| `PowerText`, `PowerTextPoint` | Dropdown, anchor | `none`, `CENTER` | | Text on the resource bar. |
| `NameShow` | Checkbox | `true` | | The name bar. |
| `NameGradient` | Checkbox | `false` | | In place of the name bar's background and border, a gradient in the Background Color, solid on the side facing the bar it is attached to: from the bottom when attached above a bar (TOP points), from the top below one (BOTTOM points), from the left on a bar's right, from the right on its left. At CENTER the background and border stay. |
| `NameOwnSize`, `NameWidth`, `NameHeight` | Checkbox, sliders | `false`, `160`, `18` | | The name bar's own width (unchecked: the health bar's) and its height. |
| `NameTarget`, `NamePoint`, `NameX`, `NameY` | Dropdown, anchor, sliders | `health`, `TOP`, `0`, `0` | | Where the name bar attaches. |
| `NameTextShow`, `NameTextPoint`, `NameTextX`, `NameTextY` | Checkbox, anchor, sliders | `true`, `LEFT`, `0`, `0` | | The unit's name on the name bar. |
| `NameClassColor` | Checkbox | `false` | | Players' names in their class color instead of Text Color. |
| `LevelShow`, `LevelPoint`, `LevelX`, `LevelY` | Checkbox, anchor, sliders | `true`, `RIGHT`, `0`, `0` | | The level on the name bar, in Blizzard's difficulty colors (?? in red far above you). |
| `PortraitShow`, `PortraitClass` | Checkboxes | `true`, `false` | ToT, Focus: `PortraitShow` `false` | The unit's 3D portrait model, held still, or players' class icon instead. |
| `PortraitOwnSize`, `PortraitWidth`, `PortraitHeight` | Checkbox, sliders 10–200 | `false`, `66`, `66` | | Unchecked, the portrait is square and as tall as the name, health and resource bars together. |
| `PortraitTarget`, `PortraitPoint`, `PortraitX`, `PortraitY` | Dropdown (all bars, health, resource, name bar), anchor, sliders | `bars`, `BOTTOMRIGHT`, `0`, `0` | | Where the portrait goes: by default beside the bars on the right, bottoms lined up. LEFT and RIGHT points put it beside, TOP and BOTTOM above or below. |
| `CastShow` | Checkbox | `true` | ToT: `false` | The cast bar, over the resource bar at its size and place (over the health bar's bottom half without one). |
| `CastSeparate`, `CastHideIdle` | Checkboxes | `false`, `true` | | A cast bar of its own, shown only while casting (or kept as an empty bar). |
| `CastOwnSize`, `CastWidth`, `CastHeight` | Checkbox, sliders | `false`, `160`, `24` | | The separate bar's own size; unchecked, the resource bar's. |
| `CastTarget`, `CastPoint`, `CastX`, `CastY` | Dropdown, anchor, sliders | `power`, `BOTTOM`, `0`, `0` | | Where the separate bar attaches. |
| `CastText` | Checkbox | `true` | | The spell's name on the cast bar. |
| `ComboShow`, `ComboTarget`, `ComboPoint`, `ComboX`, `ComboY` | Checkbox, dropdown, anchor, sliders | `true`, `power`, `BOTTOM`, `0`, `0` | Target only | Your combo points, in the totem ring (`Interface\CharacterFrame\TotemBorder`). |
| `ComboSize`, `ComboSpacing` | Sliders 8–40, −4 to 20 | `16`, `4` | Target only | Size of each point and the space between them. |

Boxes attached to the same side of the same bar stack outward in this order: combo points, then the separate cast bar. The target of target frame shows no buffs or debuffs.

### Look (shared)

| Key | Type | Default | What it changes |
|---|---|---|---|
| `border`, `borderSize`, `borderInset` | Border, slider 1–32, slider −16 to 16 | `solid`, `2`, `0` | One border for every bar and the portrait, drawn outside them; Border Position moves it in or out. |
| `borderTint` | Color (Black, White, Gold, Silver, Bronze, Red, Green, Blue, Purple, Custom..., with opacity) | black | Color of the borders and the combo points' totem rings. |
| `background`, `backgroundColor` | Background, color (Black, Charcoal, Slate, Deep Red, Forest, Umber, Midnight, Custom..., with opacity) | `solid`, charcoal at 80% | The background behind every bar and the portrait. Dead units get `0.4, 0.47, 0.6` at 75%. |
| `barTexture` | Bar texture | `flat` | Texture of every bar. |
| `healthColor`, `manaColor`, `rageColor`, `energyColor`, `focusColor` | Colors | green, blue, red, yellow, orange | Bar colors; other resources keep Blizzard's. |
| `castColor`, `comboColor` | Colors | gold, gold | Cast bar and filled combo points. |
| `font`, `fontSize`, `fontShadow`, `textColor` | Font, slider 6–24, shadow, color | `friz`, `12`, `soft`, white | All text. |

## Slash commands

- `/ptf` or `/pillarstargetframes`: open the settings
- `/ptf <page>`: open a page by the start of its name, such as `/ptf focus`, `/ptf look`, `/ptf target` or `/ptf tot`
- `/ptf profiles`: open the Profiles page
- `/ptf probe`: diagnostics to copy, for bug reports: which frames and client APIs this build has, which of the unit's values are secret, and how casts, combo points and auras are found

## Not yet tested in-game

Written against the Mainline frame layout Forever shares, with fallbacks for the old named frames. `/ptf probe` reports what your build has: `FocusFrame`, the cast duration helpers used when cast times are secret, whether Blizzard's buff container shows, the actions the client blocked this session, and the Edit Mode boxes.

## Install

Copy the `PillarsTargetFrames` folder and the `ClaiibuAPI` folder into:

```
World of Warcraft\_classic_beta_\Interface\AddOns\
```

Restart the client if the addon does not appear in the AddOns list.
