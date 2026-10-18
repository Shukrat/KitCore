# Kit Core

The shared parts of the kits for WoW Forever: the round kit button and the ring of slots around it, opening and closing, slots pinned so they stay out, secure flyouts (they open and their choices work in combat too), opening and closing the kit from its button in combat (floating kits and kits on a screen edge), dragging, keeping the kit on screen, screen-edge layout, the settings panel, the minimap button, slash commands and key bindings.

A kit hands Kit Core a description (its slots, what each one does, how it paints) and Kit Core runs the rest. [Kit Dock](https://github.com/Shukrat/KitDock) is optional: with it, a kit can join the gold pin and snap to screen edges (or, with `edgesOnly`, only the edges); without it, the kit stands on its own.

Every kit ships its own copy of `KitCore.lua`; the newest copy loaded runs for every kit (see `VERSION` at the top of the file).

Used by: First Aid Kit, Camping Kit, Fishing Kit and Warlock Kit.

## How a kit uses it

Each kit's `.pkgmeta` pulls this repository into `Libs/KitCore` when a release is built, pinned to a tag:

```yaml
externals:
  Libs/KitCore:
    url: https://github.com/Shukrat/KitCore
    tag: v3
```

The kit's `.toc` loads `Libs\KitDock\KitDock.lua` (if it uses the dock), then `Libs\KitCore\KitCore.lua`, then its own file, which calls `KitCore.NewKit({ ... })` when it loads. The comment block above `C.NewKit` in `KitCore.lua` lists everything a kit can describe.

The kit ships the art Kit Core uses in its own `media` folder: `circle_mask`, `glow_ring`, `glow_square`, `pin_dot`, `slot_border`, `ring_slot_*` and `ring_prof_*`.

## Releasing a new version

1. Raise `VERSION` in `KitCore.lua`.
2. Tag the commit `v<VERSION>` (e.g. `v3`) and push the tag.
3. In each kit, bump the `tag:` in `.pkgmeta` once you've tested it.

## Local development (Windows)

Clone this repository next to the kits (e.g. `C:\Users\Doug\Claude\KitCore`) and run `link-kits.bat` once. It links each kit's `Libs\KitCore` folder to this one with a directory junction, so an edit here shows up in every kit.

## License

MIT, see `LICENSE`.
