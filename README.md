DTiled: D language Tiled map parser.
===

You know what's great? Tilemap-based games. You know, things like Megaman, Final
Fantasy, Legend of Zelda, ect.

You know what else is great? The D programming language.

This library attempts to bring those two things together by providing
functionality that is commonly needed in any sort of tilemap-based game, easing
the process of making an awesome game in D.

To see the full suite of features offered by dtiled, check out the
[docs](http://rcorre.github.io/dtiled/dtiled.html).

If you're more of the 'see things in action' type, check out the
[Demo](https://github.com/rcorre/dtiled-example). It uses either
[Allegro](http://code.dlang.org/packages/allegro)
or
[DGame](http://code.dlang.org/packages/dgame)
to pop up a window and render a pretty tilemap you can play around with.

If you're still here, keep on reading for a 'crash course' in using dtiled.
I'll try to keep it terse, but there's a fair amount to cover here, so bear with
me.

and a [dub package](http://code.dlang.org/packages/dtiled).

# Picking a game engine
First things first, dtiled is not a game engine. It cares only about tiles and
maps, and knows nothing about rendering or input events. I expect you already
have an engine of choice for your game, so dtiled strives to integrate with your
engine's functionality rather than replace it.

If you don't have an engine, here are a few options:
- [Allegro](http://code.dlang.org/packages/allegro)
- [SDL](http://code.dlang.org/packages/derelict-sdl2)
- [SFML](http://code.dlang.org/packages/dsfml)
- [DGame](http://code.dlang.org/packages/dgame)

For the examples that follow, I'll assume you already have types or functions:

- `Vector2!T`: A point with numeric `x` and `y` components
- `Rect2!T`: A rectangle with numeric `x`, `y`, `width`, and `height` components
- `drawBitmapRegion(bmp, pos, rect)`: draw a rectangular subsection `rect` of a
  bitmap/spritesheet `bmp` to the screen at Vector position `pos`
- `getMousePos()`: Get the current mouse position as a Vector.

# Defining our Tile
We'll need to define a type that represents a single tile within the tilemap.

```d
struct Tile { Rect2!int spriteRegion; }
```

Well, that was simple. For now, our tile just defines the rectangular region of
a bitmap that should be used to render this tile. That bitmap will be our 'tile
atlas'.

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

For now, lets say your map has a single tile layer named 'ground'.
Lets take the data in that file and build an in-game map structure.

```d
auto loadMap(string path) {
  auto mapData = MapData.load(path);

  auto buildTile(TiledGid gid) {
    // each GID uniquely maps to a single tile within a single tileset
    // in our case, this will always return our only have a single tileset
    // if you use more than one tileset, this will choose the appropriate
    // tileset based on the GID.
    auto tileset = data.getTileset(gid);

    // find which region in the 'tile atlas' this GID is mapped to.
    // this will be the `region` argument to our `drawBitmapRegion` function
    auto region = Rect2!int(tileset.tileOffsetX(gid),
                            tileset.tileOffsetY(gid),
                            tileset.tileWidth,
                            tileset.tileHeight);

    return Tile(region);
  }

  auto tiles = data.getLayer("ground") // grab the layer named ground
    .data                              // iterate over the GIDs in that layer
    .map!(x => buildTile(x))           // build a Tile based on the GID
    .chunks(data.numCols)              // chunk into rows
    .map!(x => x.array)                // create an array from each row
    .array;                            // create an array of all the row arrays

  // our map wraps the 2D tile array, also storing information about tile size.
  return OrthoMap!Tile(tiles, mapData.tileWidth, mapData.tileHeight);
}
```

`OrthoMap!T` is a type dtiled provides to represent an 'Orthogonal' map. Later
versions of dtiled may also support isometric and hexagonal maps, but this will
do for our needs.

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


- what tilemap does a given tile belong to?
- what region of the tile atlas bitmap should be used to draw this tile?
- where the tile should be positioned on the screen?

It does _not_ actually render the map as I do not want to tie users to a
particular graphics library, and you have likely already picked one to render
the rest of your game.

D has bindings to a number of libraries that can render your map like:

There are also higher-level options like

