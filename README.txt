MythInc Unit Frames 0.10.0-alpha

Native unit frames for World of Warcraft Retail, targeting interface 120100
(12.1). Uses Blizzard's secure frames and aura containers. No oUF is required.

Installation
------------
Place MythIncUnitFrames in your Retail Interface\AddOns directory. The folder
must directly contain MythIncUnitFrames.toc, the Lua files, and Artwork, without
an extra nested repository folder. Enable MythInc Unit Frames in the AddOns
list. Settings are stored in MythIncUnitFramesDB.

Supported frames
----------------
Player, Target, Focus, Pet, Target of Target, Party, Boss (up to five), and Raid.
All except Raid are enabled by default. Party can optionally include the player
and is hidden in raids. Party/Boss support horizontal or vertical layouts,
growth direction, and spacing. Raid uses six groups of five, or eight groups
with Legacy 40-player groups enabled, with horizontal/vertical arrangements
and touching members and subgroups.

Configuration and movement
--------------------------
Open /miuf, select Frames and a unit type, then Layout, Text, Appearance,
Indicators, or Auras. Unsupported controls are hidden. The window is draggable
and scales down to fit the screen. Myth Inc artwork appears in the header and
addon-list icon.

GUI edits and mover position/size changes are staged. Apply Changes saves them;
Revert Changes restores saved settings. Closing the window does not apply or
discard pending edits; they remain in the current session. Frame, aura, and
Reset All buttons stage resets. Raid also has Revert Raid Changes.

Unlock Frames enables global frame movers and resize handles.
Party, Boss, and Raid have group previews for layout work. Aura movers have
a separate lock state and position aura groups relative to their frames.
The floating Lock Movers button locks both kinds. Locking does not commit
edits: use Apply Changes to save. Configure and move frames outside combat.

Appearance and text
-------------------
Per-type controls cover width, height, power-bar height, bar texture, health
and power color presets, and background/border opacity. Optional portraits
support left/right placement and proportional width; Raid has no portraits.
Text controls provide built-in fonts, font size, name/health-text visibility,
and separate X/Y offsets. Health text shows a percentage or available Offline,
Ghost, Dead, or AFK status. Party/Raid members have automatic range fading.

Auras
-----
Buffs and debuffs: Player, Target, Focus, Target of Target, and Party.
Defensives: Player and Party, using Blizzard's big/external defensive filters.
Raid: debuffs only. Pet and Boss: no aura display or aura controls.

Supported aura types have enable, cooldown-text, icon-size, maximum-count,
spacing, top/bottom anchor, left/right growth, and X/Y offset controls.
Enable Buff Filtering is per frame type: on shows your buffs from the
profile-wide tracked list; off shows all helpful buffs. It defaults off for
Target and on for other supported buff frames. An empty tracked list shows
no normal buffs while filtering is enabled.

Manage Tracked Buffs adds observed buffs or removes tracked buffs. Discovery
examines your buffs on selected units outside combat. Tracking edits are staged;
Clear Seen History immediately clears shared discovery history across profiles.
Player, Party, Target of Target, and Raid debuffs use built-in exclusions and
omit player/player-pet debuffs; Target/Focus use the general harmful filter.
Player, Party, Focus, and Raid have dispel highlighting. Party defensive
displays are hidden when the member is not visible to the client.

Indicators
----------
Raid markers are configurable on all frame types. Role icons are available
for Player, Party, and Raid. Party/Raid leader icons have visibility, size,
and offset controls; Party defaults on and Raid off. When Party excludes the
player, its leader icon can appear on the separate Player frame. Player also
has a configurable resting indicator.

Ready-check, incoming-summon, and incoming-resurrection indicators are automatic
on Player, Target, Focus, Target of Target, Party, and Raid. Shared size/offset
controls are available, but no individual enable switches. Preview temporarily
shows a ready-check icon on an available live frame or group preview; it is not
saved and clears on leaving that view.

Castbars and click-casting
-------------------------
Player, Target, Focus, and Boss have attached castbars for casts, channels,
and empowered channels, with spell text and interruptibility where available.
There are no separate castbar configuration or movement controls.

Frames register with ClickCastFrames for compatible addons such as Clique.
Configure bindings in that addon; MIUF has no built-in binding editor.

Profiles
--------
Profiles are shared in the addon database; each character remembers its choice.
Create New starts from defaults. Copy Current copies saved settings: apply
pending edits first if they should be included. Rename Selected and Delete
Selected manage profiles. Default cannot be renamed/deleted; the active profile
cannot be deleted. Characters using a deleted profile fall back to Default.
Use Profile requires no pending edits and reloads the UI. Profile operations
are unavailable in combat. Seen-buff history is shared; tracked buffs,
appearance, layouts, positions, and enable states belong to each profile.

Limitations and reloads
----------------------
- Most Apply Changes operations update live outside combat. Changing Raid's
  Legacy 40-player capacity or switching profiles reloads the UI. Apply also
  reloads if live application fails or cannot complete.
- Protected layout/visibility work may wait until combat ends. Apply and Revert
  are unavailable during combat; Blizzard controls restricted aura data.
- The profile picker displays ten entries. The buff manager displays up to 24
  seen and 24 tracked buffs. These lists currently have no pagination.
- Blizzard's Player, Pet, Target, Focus, Party, and Boss frames are suppressed
  independently of MIUF's enable switches. Disabling a MIUF type does not
  restore its Blizzard counterpart. Blizzard's raid container is suppressed
  only while MIUF Raid is enabled; the Blizzard raid manager is retained.
- This is an alpha. Combat, vehicles, group changes, artwork, UI scaling, and
  raid layouts still warrant testing in game.

Slash commands
--------------
/miuf                    Toggle configuration (also: config or options)
/miuf help               Print command help
/miuf version            Print installed addon version
/miuf unlock             Unlock frame movers
/miuf lock               Lock frame movers; review pending edits in the GUI
/miuf auraunlock         Unlock aura movers
/miuf auralock           Lock aura movers
/miuf size <type> <w> <h> Immediately save/apply a frame type's size
/miuf reset              Immediately reset the current profile and seen history

Size types: player, target, focus, pet, targettarget, party, boss, raid.
Example: /miuf size player 250 54
The command accepts integer widths 100-600 and heights 24-150; the Raid GUI
allows smaller frames (50 wide, 18 high). Size and reset are blocked in combat.
Unlike GUI edits, these commands do not wait for Apply Changes. Prefer the GUI
for a reset you can review or revert before applying.
