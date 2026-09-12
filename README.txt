MythInc Unit Frames 0.8.17-alpha

Requires standalone oUF 14.0.2 on WoW Retail 12.1.

MythInc Unit Frames is a lightweight oUF layout focused on readable unit frames,
protected aura handling, and straightforward configuration.

Current features
- Player, Target, Focus, Pet, Target of Target, Party, and Boss frames
- Shared Party and Boss group layouts with vertical/horizontal growth and spacing
- Optional Player frame inside the Party group
- Frame movers plus proportional live resize handles while unlocked
- Floating Lock Movers button when any movers are unlocked
- Per-frame size, power-bar height, portrait, fonts, colors, and opacity controls
- Tracked Buff whitelist with Seen Buff discovery
- Automatic combat debuffs and external defensive buffs
- Protected dispel highlighting with a 5 px dispel-color border and black outline
- Independent aura positioning, icon size/count/spacing, growth, and text controls
- Saved mover positions and settings

Commands
/miuf or /miuf config   Open configuration
/miuf unlock            Unlock frame movers
/miuf lock              Lock frame movers
/miuf auraunlock        Unlock aura movers
/miuf auralock          Lock aura movers
/miuf size <type> <w> <h>
/miuf reset             Restore defaults
/miuf version           Show the installed addon version

0.8.17-alpha cleanup pass
- Refactored Party/Boss anchoring to use one shared group-layout helper.
- Removed redundant pre-spawn layout/mover calls while retaining compatibility helpers.
- Cleaned group-layout naming in configuration code.
- Moved repeated slider enable/disable logic into one helper.
- Replaced the accumulated development-history README with current documentation.
- No intentional feature, SavedVariables, aura, mover, or protected-frame behavior changes.
