# Group Guard

A small World of Warcraft addon that shows a large green or red indicator for a selected raid subgroup. Green appears only when you are in a raid and your character plus the other four configured players are exactly the five people in that subgroup. Outside a raid, or when a member is missing, moved, extra, or ambiguous, the indicator stays red.

The addon only reads the local raid roster. It does not send chat messages or communicate with other addons.

## Setup

1. Copy the `GroupGuard` folder into the WoW edition's `Interface/AddOns` folder.
2. Fully restart WoW after installing it.
3. In game, enter `/gg set YourName, Friend1, Friend2, Friend3, Friend4` and replace the examples with the five actual character names, including your own.
4. Include realms for cross-realm names when needed, for example `Friend-Realm Name`.
5. Choose the target subgroup with `/gg group <1-8>` before raiding. No subgroup is assumed.

The roster, target group, indicator visibility, and position are saved per character. Hold Shift and drag the indicator to move it. The addon remains enabled in the AddOns manager, but the indicator can be hidden in-game.

## Commands

- `/gg set Name1, Name2, Name3, Name4, Name5` saves exactly five names.
- `/gg group <1-8>` sets the target raid subgroup; `/gg group` shows the current setting.
- `/gg on` or `/gg off` enables or hides the indicator without disabling the addon.
- `/gg toggle` switches the indicator visibility.
- `/gg status` prints the current safety result.
- `/gg roster` prints the saved names.
- `/gg clear` clears the saved roster.
- `/gg help` lists setup guidance.

## Releases

Download the latest version from [CurseForge](https://www.curseforge.com/wow/addons/groupguard).
