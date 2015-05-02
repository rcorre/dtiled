DTiled: D language Tiled map parser.
===

DTiled is a small utility to parse [Tiled](mapeditor.org) maps for use in D.
It currently supports Tiled's JSON format.

# What is DTiled?
Currently, DTiled is a pretty thin wrapper around the data exported by Tiled.

It includes a few helper functions that make it easier to get information about
the tiles in your map.

Currently, DTiled is intended as a tilemap loader rather than an in-game tilemap
implementation.

For any non-trivial use of a tilemap, you likely have your own structure to
represent the map in-game, DTiled is simply a helpful way to populate your map
structure from a json file exported

# What isn't DTiled?
DTiled is not a tilemap renderer.

DTiled describes _how_ to render your map by answering questions like:

- what tilemap does a given tile belong to?
- what region of the tile atlas bitmap should be used to draw this tile?
- where the tile should be positioned on the screen?

It does _not_ actually render the map as I do not want to tie users to a
particular graphics library, and you have likely already picked one to render
the rest of your game.

D has bindings to a number of libraries that can render your map like:
- [Allegro](http://code.dlang.org/packages/allegro)
- [SDL](http://code.dlang.org/packages/derelict-sdl2)
- [SFML](http://code.dlang.org/packages/dsfml)

There are also higher-level options like
[DGame](http://code.dlang.org/packages/dgame).

I have created a simple example using
[DTiled with Allegro](https://github.com/rcorre/dtiled-example).
If you create an example using your own favorite rendering library, let me know!

# Development
DTiled is currently considered alpha, as I may change up the API if I decide on
something I feel is cleaner of more useful.

DTiled's API may expand to provide higher-level helpers that consolidate the
most useful information about a tilemap.
This might take the form of a range-based API that iterates over all the tiles
in

In the future, DTiled _might_ expand to provide a generic TileMap structure that
actually is intended for in-game use, and would help support common needs like
querying which tile is at a given pixel position. It might even enable rendering
via callbacks, allowing users to choose what actually does the rendering.

# Tips
Tired of clicking export all the time in the Tiled editor?
Tiled has an `--export-map` flag that can be used from the command line!
Include a step in your build process to translate all `tmx` files to `json`
files.
