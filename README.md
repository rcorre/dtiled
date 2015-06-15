DTiled: D language Tiled map parser.
===

DTiled is a small utility to parse maps using D.
It currently supports Tiled's JSON format.

DTiled has [docs](http://rcorre.github.io/dtiled/dtiled.html)
and a [dub package](http://code.dlang.org/packages/dtiled).

# Grids
Lets start with the module `dtiled.grid`, which provides functions that treat a
2D array as a grid of tiles.

For example, you can get the tile at (row 2, column 3):

```d
MyTileType[][] myGrid;
auto tile = myGrid.tileAt(RowCol(2,3))
```

You may be thinking, "couldn't I just use `myGrid[2][3]`"?
Sure, you can use `myGrid[row][col]` all you want, up until you cause a nasty
bug with a careless `myGrid[col][row]`;

Use of the `RowCol` struct throughout `dtiled.grid` avoids this confusion.
`RowCol` also provides a few nice benefits:

```d
RowCol(2,3).south(5)   // (7,3)
RowCol(2,3).south.east // (3,4)
RowCol(2,3).adjacent   // [ (1,3), (2,2), (2,4), (3,3) ]
```

Lets get back to some of the other useful things you can do with a grid.

You will often want to iterate over the grid as a single 'flat' range:

```d
foreach(tile ; grid.tiles) { }            // just tiles
foreach(coord, tile ; grid.tiles) { }     // tiles and coords
foreach(coord, ref tile ; grid.tiles) { } // use ref to modify value-typed tiles
```

Sometimes, you need the neighbors of the tile at a certain coordinate:

```d
auto neighbors = grid.adjacentTiles(RowCol(2,3));
auto surrounding = grid.adjacentTiles(RowCol(2,3), Diagonals.yes);
auto coords = grid.adjacentCoords(RowCol(2,3)); // coords instead of tiles
```

If you need to extract tiles in some sort of pattern, you can use a 'mask'.
For example, suppose you are making a game where the player can place walls of
various shapes. The player is trying to place an 'L' shaped wall at the
coordinate (5,3), and you need to know if every tile the wall would cover is
currently empty.

```d
uint[3][3] mask = [
  [ 0, 1, 0 ]
  [ 0, 1, 1 ]
  [ 0, 0, 0 ]
];

auto tilesUnderWall = grid.maskTilesAround(RowCol(5,3), mask);
bool canPlaceWall = tilesUnderWall.all!(x => !x.hasObstruction);
```

# Making a game with DTiled
DTiled is not a game engine.  Instead, DTiled is a tilemap-oriented library
designed to work seamlessly with the game engine of your choice.

D has a number of game engine options available, such as:
- [Allegro](http://code.dlang.org/packages/allegro)
- [SDL](http://code.dlang.org/packages/derelict-sdl2)
- [SFML](http://code.dlang.org/packages/dsfml)
- [DGame](http://code.dlang.org/packages/dgame)

Most likely, your game will have a single top-level map structure, provided by
`dtiled.map`. Currently, the only map type is an 'Orthogonal' `OrthoMap`, though
later DTiled may support Isometric and Hexagonal map types.

A map is a wrapper around a 2D tile array with additional information about tile
positioning and size. It supports all the functionality provided by
`dtiled.grid`, plus additional operations like figuring out which tile lies
at a given pixel position:

```d
OrthogonalMap!MyTileType tileMap;
// ...
auto mousePos = myGameEngine.mousePos;
auto tileUnderMouse = tileMap.tileAtPoint(mousePos);
// you could get a coord instead of a tile:
auto coordUnderMouse = tileMap.coordAtPoint(mousePos);
```

In order to work with the engine of your choice, functions that deal with 'pixel
coordinates' like `tileUnderMouse` will accept anything 'vector-like' (anything
with numeric `x` and `y` components).

Chances are your will want to render your map to a display. Assuming your game
engine knows how to render a rectangular section of a bitmap, `dtiled.map` makes
this easy:

```d
auto tileAtlas = myGameEngine.loadBitmap("tilesheet.png");

foreach(coord, ref tile ; tileMap) {
  // get the top-left drawing position on the display
  // tileOffset returns a simple (x,y) tuple.
  // it can be converted to a vector type of your choice with `as`
  auto screenPos = tileMap.tileOffset(coord).as!Vector2i; 

  // it is assumed that spriteOffset is a property on your tile type.
  // see the section on map loading for info on how to get this information
  auto spriteRect = Rect(tile.spriteOffset, map.tileWidth, map.tileHeight);

  myGameEngine.drawBitmapRegion(screenPos, spriteRect);
}
```

# Loading a map
Unless your map is procedurally generated, you will probably want to create map
files with some application and load them in your game.

DTiled can help you load maps created with [Tiled](http://mapeditor.org), a
popular open-source tilemap editor.

Create your map in Tiled, export it to json using the in-editor menu or the
`--export-map` command-line switch, and use `dtiled.data` to interpret the json
map file. Currently DTiled only supports Tiled's JSON format. Support for tmx
and csv may be added, but the json format should provide all necessary
information.

Lets look at a simple example. You use Tiled to create a map with a single tile
layer named 'ground' and want to load it in your game.

First, you will need to create a type 

```d
auto mapData = 
```

- what tilemap does a given tile belong to?
- what region of the tile atlas bitmap should be used to draw this tile?
- where the tile should be positioned on the screen?

It does _not_ actually render the map as I do not want to tie users to a
particular graphics library, and you have likely already picked one to render
the rest of your game.

D has bindings to a number of libraries that can render your map like:

There are also higher-level options like

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
Tiled has an flag that can be used from the command line!
Include a step in your build process to translate all `tmx` files to `json`
files.
