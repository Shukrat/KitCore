# Kit Core

The shared parts of the kits for WoW Forever: the round kit button and the ring of slots around it, opening and closing, slots pinned so they stay out, secure flyouts (they open and their choices work in combat too), opening and closing the kit from its button in combat (floating kits and kits on a screen edge), dragging, keeping the kit on screen, screen-edge layout, the settings panel, the minimap button, slash commands and key bindings (including the game's Quick Keybind Mode: every kit opens fully while it's up, so any slot, corner button or kit button can be bound by hovering it and pressing a key).

A kit hands Kit Core a description (its slots, what each one does, how it paints) and Kit Core runs the rest. [Kit Dock](https://github.com/Shukrat/KitDock) is optional: with it, a kit can join the gold pin and snap to screen edges (or, with `edgesOnly`, only the edges); without it, the kit stands on its own.

From v21 there's a reminder panel shared by every kit. Each kit has its own switch for it (Reminder panel in its settings), so some kits' reminders can be in the panel and others by their kit; drag it anywhere, and tick which of each kit's reminders go there. With a kit closed, those slots sit in the panel, full size, instead of beside the kit; open the kit and they're back in their places, glowing as usual. Closing a kit in combat puts them back in the panel too. Pinned buttons always stay by their kit. A kit can mark a slot `noPanel` (never in the panel) or set `panelDefault`.

From v23 a kit can let its buttons be dragged off it (`bars = true` in its description). In the kit's edit mode every button can be dragged: dropped away from the kit it floats there, always shown, and dropping more on it builds a bar (a row or a column, any length, any number of bars). Dropped on the kit, a button goes back to its place. A button on a bar is the slot itself, moved, so its drawer, corner button, glow and key binding come with it, and the kit closes up round the gap. With `zones`, the kit's own ring and row can be rearranged in edit mode too; the kit hears about it through `OnZones`. Bars and zone order are saved per character. Buttons on bars don't fade when idle and pinning doesn't apply to them.

From v24 the kit's settings window is easier to read and set. Each setting's description is its tooltip (beside the window) instead of a paragraph under it. Settings are grouped into cards, a group can start folded away (`S.Subheader(text, when, { fold = true })`), and up to four short choices show as a row of buttons instead of a menu. A search box in the window's header finds a setting by name or description across every page, and Key bindings is a link at the foot of the list. Kits can add `S.Note` (a line of grey words), `S.Choice` (a choice read and stored by functions), `S.Grid(2)` (checkboxes two to a line) and `S.Table` (a table of the kit's buttons, a row each with a tick box per column, and a name to click for the rest). A kit with `buttonTable = true` sets its buttons' pinning in its own table, on a page of its own (`FirstSettings` adds pages right after General), so Kit Core leaves out its "Pinned buttons" page. Fading is one choice (Never, When closed, When left open, Both) and General gathers fading and combat.

Also from v24, placing things is Kit Core's: one grid and one bar (grid size, Snap, Done) for the reminder panel and any piece a kit registers with `C.RegisterMover(key, { label, frame, test, can, done })`, dragged with `C.Place.Begin` / `C.Place.Stop` and switched with `C.Place.Update`. Pieces snap to the screen's middle lines, to each other and to the kit buttons, or else to the grid. **Move everything** (`C.MoveAll`: at the foot of the settings window's list, by Key bindings, or `move` after the slash command) puts every piece that's in use on the grid at once, and Done ends them all.

From v27 a row of choice buttons can carry column heads: `S.Choice(name, tip, list, get, set, fn, { heads = { "A", "B" } })` puts small gold words over each button, like a table's heads. Rows below it with the same choices line up under them, so only the first row needs heads. A choice can also have a tooltip of its own for its button: `{ value, label, tip, title }` in the list (title defaults to the label). And a kit can add lines under "Settings" at the foot of its right-click menu with `MenuAfterSettings(kit, root)`.

From v29 a colour setting can be a row of coloured squares: `S.Colors(name, tip, list, get, set, fn, opts)` with `list = { { value, label, { r, g, b } }, ... }` draws a square per preset, the one in use marked with a gold edge and an x, and with `opts.custom` (the value that means your own colour), `opts.getRGB()` and `opts.setRGB(r, g, b)` a Custom... button after them that shows your own colour in its square and opens the game's colour picker (Cancel puts back what you had). So a kit needs no separate Pick button or picker code of its own. In the game's own options list it's left out, like `S.Choice`.

From v30 a kit can put a frame of its own in the settings window, for what the other rows can't show (a preview, say): `S.Custom(name, tip, make)`. `make(parent, w)` builds the frame, `w` wide, and returns it with its height set; its `Paint()`, if it has one, runs each time the page is painted, and can change its height. The search box finds it by `name` and `tip`. It's the window's only: the game's options page skips it, so a kit can check `S.window` and give that page plain settings instead.

From v31 a zone can hold small buttons: `small = true` on a zone makes its slots small round buttons and the other zones' full slots, and a slot takes the size of whichever zone it's in, changing as it's dragged from one to another in edit mode (out of combat). Dragged off the kit onto a bar it's a full slot. `only = { slotKey, ... }` keeps a zone to the slots it lists (any other is offered the other zones, and one saved there goes back to the zone it started in). `track = true` on a ring zone puts its name just beyond its buttons, for a ring inside another ring. Warlock Kit's inner ring under the orb uses `small` and `track`: any of its buttons can go there, small, and full slots on the ring, under the line or on a bar.

From v35 edit mode shows where a dragged button will go. Each ring zone owns a band round the kit (`Kit:ZoneBands`): rings one inside another meet halfway between their radii, so the bands never overlap; the innermost starts just outside the kit's icon (a drop on the icon still puts a button back). A drop anywhere in a band, at any angle, goes on that ring (past either end of its buttons, on that end). The bands are shaded (the kit's `circle_mask` and `zone_ring` art), and the one a dragged button would land in lights up. The button under the mouse takes the size it would be there and says where it'll go (the zone's name, a bar, on its own, or back in its place), and a gold ring marks the spot it would take.

From v38 the bars go on the placing grid, the same one **Move everything** uses. Edit mode shows the grid under the kits, with Grid size and Snap on its bar (the same settings as when placing). A bar dragged by its box, or a button floating on its own, snaps to the screen's middle lines, the kit buttons and the other bars (a guide line shows what it lined up with), or else its left and top edges to the grid, and stays whole on the screen. Hold Shift to place it freely. The bars are also something the placed pieces (the reminder panel, a kit's timers and bars) line up with. Placing and editing a layout run together: **Move everything** also puts the kit it's pressed from into edit mode, so its buttons and bars move along with the timers and the panel. Edit mode's bar is the one bar at the top while both run, and its Done (or Esc) ends both.

From v39 a kit with `cfg.radial` can be used from a controller as a ring round the middle of the screen. Its binding (`CLICK <prefix>Radial:LeftButton`, listed in the kit's `Bindings.xml`), or the macro `/click <prefix>Radial` on a gamepad bar (Settings > Controller makes it), brings the ring up: hold it, tilt a stick at a button, let go; or tap it and use A. The kit's ring zone is the main ring, with a "Below the line" button at the bottom that opens its row; its small zone is the inner ring, opened with X while the stick is centred, so buttons that act at once are never a flick away. X on a slot with a drawer opens the drawer as a ring, turned so the slot's current choice sits under the stick. Y runs a slot's `radialAlt` (Warlock Kit: summon with Fel Domination). B goes back a ring or closes. It's secure throughout, so it works in combat: the header's snippets read the stick with `GetGamePadState()` and `/click` the slot or drawer choice it points at; what's in each ring is pushed to the header as attributes on every refresh, out of combat. While it's up, A, B, X and Y are override bindings on the header (a key bound to bring the ring up is left alone), and the stick it reads is kept off the camera. A macro's `/click` is a single click, so when the ring opens the header also binds whichever pad buttons are held (the gamepad bar slot's button, under any modifiers) to the trigger: letting go of it reaches the trigger, as the game sends a key's release to whatever it's bound to at that moment. The Gamepad UI's triggers and bumpers, the Shift/Ctrl/Alt buttons and stick leans are never taken, since the game has to see those let go.

From v33 the words Kit Core shows go through `KitCore.L`, keyed by their English, in the player's language: Simplified Chinese so far, with anything untranslated showing in English. A kit keeps its own words in its own table (Warlock Kit's `ns.L`, with `Locales\zhCN.lua`). Spell, item and zone names come from the game, not these tables.

Every kit ships its own copy of `KitCore.lua`; the newest copy loaded runs for every kit (see `VERSION` at the top of the file).

Used by: First Aid Kit, Camping Kit, Fishing Kit, Warlock Kit and Shaman Kit.

The minimap button is a LibDataBroker launcher shown by LibDBIcon (from v19), so square minimaps and minimap button-bag addons handle it like any other addon's button. The libraries are in `Libs/`, each under its own licence.

## How a kit uses it

Each kit's `.pkgmeta` pulls this repository into `Libs/KitCore` when a release is built, pinned to a tag:

```yaml
externals:
  Libs/KitCore:
    url: https://github.com/Shukrat/KitCore
    tag: v3
```

The kit's `.toc` loads `Libs\KitCore\Libs\Libs.xml` first (from v19: LibStub, CallbackHandler, LibDataBroker and LibDBIcon, for the minimap button), then `Libs\KitDock\KitDock.lua` (if it uses the dock), then `Libs\KitCore\KitCore.lua`, then its own file, which calls `KitCore.NewKit({ ... })` when it loads. The comment block above `C.NewKit` in `KitCore.lua` lists everything a kit can describe.

The kit ships the art Kit Core uses in its own `media` folder: `circle_mask`, `glow_ring`, `pin_dot`, `slot_border`, `ring_slot_*` and `ring_prof_*`, plus `zone_ring` for a kit that uses `zones` (v23).

## ForeverImmersion

Each kit adds itself to the shared `ForeverUI.elements` list, so ForeverImmersion (and anything else that reads it) lists it as its own element, named after the kit. The frame it's given is `<prefix>Area` (e.g. `CampingKitArea`): an empty frame that follows the bounds of what the kit shows, for the mouseover reveal and the editor's box. Alpha set on it goes to the kit's holder, so the whole kit fades together. Kits show in every situation but Mount until the player changes it there.

## Releasing a new version

1. Raise `VERSION` in `KitCore.lua`.
2. Tag the commit `v<VERSION>` (e.g. `v3`) and push the tag.
3. The Bump kits workflow (`.github/workflows/bump-kits.yml`) opens a pull request in each kit moving its `.pkgmeta` to the new tag. Test each kit, then merge its PR. It needs a `KITS_TOKEN` secret (see the top of the workflow); a new kit goes in its list.

## Local development (Windows)

Clone this repository next to the kits (e.g. `C:\Users\Doug\Claude\KitCore`) and run `link-kits.bat` once. It links each kit's `Libs\KitCore` folder to this one with a directory junction, so an edit here shows up in every kit.

## License

All rights reserved, see `LICENSE`. Releases before this change were MIT and stay MIT.
