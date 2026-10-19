# Pillars Target Frames

A reskin of Blizzard's target, target of target and focus frames for World of Warcraft: Forever (`## Interface: 16001`), built on [ClaiibuAPI](https://github.com/cloudfan/ClaiibuAPI) (API level 1), which must be installed. The sibling of [Pillars Player Frame](https://github.com/cloudfan/Pillars-PlayerFrame), in the same look.

## Features

The target, target of target and focus frames, each laid out like Blizzard's target frame: a portrait beside a name bar, the health bar and the resource bar. Blizzard's look: a round portrait (Blizzard's picture, the 3D model or the class icon) in a ring, the name bar in the unit's reaction color (hostile red, neutral yellow, friendly green, other players blue), and the level in a circle on the portrait's corner in Blizzard's difficulty colors (?? in red far above you). Elite units and world bosses get a gold ring, rares silver, in place of Blizzard's dragon; units tapped by someone else go gray; raid target icons sit on top of the portrait. Health and resource text (full, abbreviated, percentage or both, secret values included), incoming heals after the health, and Dead, Ghost and Offline on the health bar. One bar texture (Blizzard's by default), border, border tint, font and shadow for all three frames; each frame has its own sizes, font size and colors.

The frames stay Blizzard's: they show when Blizzard shows them, keep Blizzard's buffs, debuffs, cast bars and threat number, and move with Edit Mode (whose highlight covers the reskinned frame). Left-click targets the unit, right-click opens its menu. Turning a frame off takes effect after a reload. Blizzard's focus frame's own target of target is left as Blizzard's.

Settings are under Options → AddOns → Pillars Target Frames: General, then Focus, Look, Target and Target of Target, and Profiles last.

## Settings

### Per frame (Focus, Target and Target of Target pages)

Each frame has these settings under its prefix: `tf` (Target), `tot` (Target of Target), `ff` (Focus), so `tfHealthWidth`, `totHealthWidth`, `ffHealthWidth`. Defaults are the target's and focus's, with the target of target's where it differs. Settings marked ⟳ ask you to reload the UI when changed.

| Key | Type | Default (target, focus / target of target) | What it changes |
|---|---|---|---|
| `Enabled` ⟳ | Checkbox | `true` | Reskins the frame. |
| `OffsetX`, `OffsetY` ⟳ | Sliders −100 to 100 | `0`, `0` | Moves the bars inside Blizzard's frame, for instance away from its buffs. Move the whole frame in Edit Mode. |
| `HealthWidth` ⟳ | Slider 40–400 | `150` / `80` | Width of the health bar; the name and resource bars match it. |
| `HealthHeight`, `PowerHeight` ⟳ | Sliders 6–80, 2–40 | `26`, `10` / `12`, `6` | Heights of the health and resource bars. |
| `NameHeight` | Slider 8–40 | `18` / `14` | Height of the name bar. |
| `FontSize` | Slider 6–24 | `12` / `10` | Size of all text on the frame. |
| `HealthColor` | Dropdown: Reaction, Class Color (players; reaction for NPCs), Green, Red, Blue, Orange, Yellow, Purple, Cyan, White, Gray, Pale Blue | `green` | Health bar color. Green is Blizzard's. Dead and offline units are gray. |
| `HealthTapped` | Checkbox | `true` | Gray health and name bar for a unit tapped by someone else. |
| `HealthText`, `HealthTextAnchor` | Dropdown (full, abbreviated, percentage, both, none), anchor | `both` / `none`, `CENTER` | Text on the health bar; Dead, Ghost or Offline instead when that applies. |
| `PowerText` | Dropdown | `none` | Text on the resource bar. |
| `HealPredict` | Checkbox | `true` | Incoming heals as a bar after the health, clipped to the health bar. Blizzard's own heal and absorb display is hidden. |
| `NameBar` | Dropdown (reaction, class color, background only) | `reaction` | Color of the name bar, in the bar texture: Blizzard's reaction color (`UnitSelectionColor`), players' class color, or only the name bar background. |
| `NameText`, `NameAnchor` | Dropdown (name and realm, name only, none), anchor | `short`, `CENTER` / `LEFT` | The unit's name on the name bar. |
| `NameColor`, `NameClassColor` | Color, checkbox | gold `#FFD100`, `false` | Color of the name, or players' class color. |
| `Level`, `LevelPos` | Checkbox, dropdown (on the portrait, on the name bar) | `true` / `false`, `badge` | The level: in a circle on the portrait's outer bottom corner, or on the name bar on the portrait's side. Without a portrait it goes on the name bar. |
| `LevelColor` | Checkbox | `true` | Enemies' levels in Blizzard's difficulty colors; ?? in red for a level far above yours; gold for units you cannot attack. |
| `Portrait` | Dropdown (portrait, 3D model, class icon, none) | `portrait` | Blizzard's portrait picture, the 3D model (always square; the picture while the unit is out of sight), the class icon for players (the picture for NPCs), or none. |
| `PortraitShape` | Dropdown (round, square) | `round` | Round: a ring in the Border Tint, Border Size thick. Square: the name bar's background and the shared border. |
| `PortraitSide` | Dropdown (right, left) | `right` / `left` | Which side of the bars the portrait is on, as Blizzard has it. |
| `PortraitFit`, `PortraitSize` | Checkbox, slider 16–140 | `true`, `60` | Make the portrait as tall as the three bars together, or its own size. |
| `Classification` | Checkbox | `true` | Gold ring or border for elites and world bosses, silver for rares. |
| `RaidIcon`, `RaidIconSize` | Checkbox, slider 8–48 | `true`, `20` / `14` | The raid target icon on top of the portrait (of the name bar without one). |

### Look (shared)

| Key | Type | Default | What it changes |
|---|---|---|---|
| `barTexture` ⟳ | Bar texture | `blizzard` | Texture of the health, resource and name bars. |
| `border`, `borderSize`, `borderTint` | Border, slider 1–32, tint | `solid`, `2`, `black` | One border for the bars, name bar and square portrait, drawn outside them; the size and tint also make the round portrait's ring and the level circle. |
| `borderInset` | Slider −16 to 16 | `0` | Border Position: moves the borders in (positive) or out (negative) to close a gap between a bar and a textured border. |
| `font`, `fontShadow` | Font, shadow | `friz`, `soft` | One font and shadow for all text. |
| `healthBackground`, `healthBgColor`, `healthBgOpacity` | Background, dropdown, slider 0–100% | `solid`, `black`, `50` | Health bar background. Colors: Default (the background's own), Black, Charcoal, Slate, Deep Red, Forest, Umber, Midnight, Smoke. |
| `powerBackground`, `powerBgColor`, `powerBgOpacity` | Background, dropdown, slider 0–100% | `solid`, `black`, `50` | Resource bar background. |
| `nameBackground`, `nameBgColor`, `nameBgOpacity` | Background, dropdown, slider 0–100% | `solid`, `charcoal`, `90` | Name bar and square portrait background; the opacity is also the name bar color's. |
| `manaColor`, `rageColor`, `energyColor`, `focusColor` | Dropdowns | `blue`, `red`, `yellow`, `orange` | Resource bar colors; other resources keep Blizzard's. |
| `healPredictColor`, `healPredictOpacity` | Dropdown, slider 10–100% | `paleblue`, `60` | Incoming heal bar color. Pale Blue is `#B3EBFF`. |

## Slash commands

- `/ptf` or `/pillarstargetframes`: open the settings
- `/ptf <page>`: open a page by the start of its name, such as `/ptf focus`, `/ptf look`, `/ptf target` or `/ptf tot`
- `/ptf profiles`: open the Profiles page
- `/ptf probe`: diagnostics to copy, for bug reports: which frames, bars and client APIs this build has, and which of the unit's values are secret

## Not yet tested in-game

Written against the Mainline frame layout Forever shares (`TargetFrame.TargetFrameContent`, `TargetFrame.totFrame`, `FocusFrame`) with fallbacks for the old named frames. `FocusFrame` may not exist on every Forever build; the Focus page then does nothing and `/ptf probe` says so. Health, names, reactions, levels and raid icons can be secret on Forever: the probe shows which are on your build, and secret ones go straight to the client (the reaction color through `UnitSelectionColor`, text through `SetFormattedText`) or fall back (no raid icon, gold level).

## Install

Copy the `PillarsTargetFrames` folder and the `ClaiibuAPI` folder into:

```
World of Warcraft\_classic_beta_\Interface\AddOns\
```

Restart the client if the addon does not appear in the AddOns list.
