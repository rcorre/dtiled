DTiled: D language Tiled map parser.
===

Do you like tilemap-based games?
How about the D programming language?
Would you like to make a tilemapped game in D?

If so, you'll probably need to implement a lot of commonly-needed tilemap
functionality, like mapping between screen coordinates and grid coordinates,
iterating through groups of tiles, loading a map from a file, and more.

I've spent enough time re-implementing or copying my tilemap logic between game
projects that I decided to factor it out into a library.
Here's a quick overview of what dtiled can do:

```d
// row/col coordinates are explicitly specified to avoid nasty bugs
tilemap.tileAt(RowCol(2,3));

// convert between 'grid' (row/column) and 'pixel' (x/y) coordinates
auto tileUnderMouse = tilemap.tileAtPoint(myGameEngine.mousePos);
auto pos = tilemap.tileCenter(RowCol(3,2)).as!MyVectorType;

// no nested for loops! Conveniently foreach over all tiles in a map:
foreach(coord, ref tile ; tilemap) {
  tile.awesomeness += 10; // if your tiles are structs, use ref to modify them
}

// finding the neighbors of a tile is an oft-needed task
auto adjacent = tilemap.adjacentTiles(RowCol(3,3));
auto surrounding = tilemap.adjacentTiles(RowCol(3,3), Diagonals.yes);

// use masks for grabbing tiles in some pattern
uint[3][3] newWallShape = [
  [ 1, 1, 1 ],
  [ 0, 1, 0 ],
  [ 0, 1, 0 ],
];

bool blocked = tilemap
  .maskTilesAround(RowCol(5,5), newWallShape)
  .any!(x => x.obstructed);

// load data for maps created with the Tiled map editor
auto mapData = MapData.load("map.json");
foreach(gid ; mapData.getLayer("ground").data) { ... }
```

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

# Picking a game engine
First things first, dtiled is not a game engine. It cares only about tiles and
maps, and knows nothing about rendering or input events. I expect you already
have an engine of choice for your game. dtiled strives to integrate with your
engine's functionality rather than replace it.

If you don't have an engine, here are a few options:
- [Allegro](http://code.dlang.org/packages/allegro)
- [SDL](http://code.dlang.org/packages/derelict-sdl2)
- [SFML](http://code.dlang.org/packages/dsfml)
- [DGame](http://code.dlang.org/packages/dgame)

The following examples assume you or your engine provide:

- `Vector2!T`: A point with numeric `x` and `y` components
- `Rect2!T`: A rectangle with numeric `x`, `y`, `width`, and `height` components
- `drawBitmapRegion(bmp, pos, rect)`: draw a rectangular subsection `rect` of a
  bitmap/spritesheet `bmp` to the screen at Vector position `pos`
- `getMousePos()`: Get the current mouse position as a Vector.

# Defining our Tile
We'll need to define a type that represents a single tile within the tilemap.

```d
struct Tile { Rect2!int spriteRect; }
```

Well, that was simple. For now, our tile just defines the rectangular region of
a bitmap that should be used to render this tile. That bitmap will be our 'tile
atlas'; something like this:

<img src="https://github.com/rcorre/dtiled-example/blob/master/content/ground.png"/>

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

# Dealing with on-screen positions
Now that we know which region of our tile atlas each tile should be drawn with
(the `Tile.spriteRect` field we populated when loading the map), rendering the
map just requires us to know which position each tile should be rendered to the
screen at. Fortunately, our `OrthoMap` can translate grid coordinates to
on-screen positions:

```d
Bitmap tileAtlas; // assume we load our tile sheet at some point

void drawMap(OrthoMap!Tile tileMap) {
  foreach(coord, tile ; tileMap) {
    // you could use tileCenter to get the offset of the tile's center instead
    auto topLeft = tileMap.tileOffset(coord).as!(Vector2!int);
    drawBitmap(tileAtlas, topLeft, tile.spriteRect);
  }
}
```

Remember that `Vector2!T` is a type I am assuming you or your game library
provides. `tileOffset` (and `tileCenter`) return a simple (x,y) tuple, and
`dtiled.coords` provides a helper `as!T` to convert it to a vector type of your
choice.

We can also go the other way and find out which coordinate or tile lies at a
given screen position. This is useful for, say, figuring out which tile is under
the player's mouse:

```d
auto tileUnderMouse = tileMap.tileAtPoint(mousePos);
// or
auto coordUnderMouse = tileMap.coordAtPoint(mousePos);
```

Just as `tileOffset` returns a general 'vector-ish' type `tileAtPoint` will
accept anything vector-like as an argument (anything that has a numeric `x` or
`y` component). DTiled tries not to make too many assumptions about the types
you want to use.

# The Grid
A grid is a thin wrapper around a 2D array that enforces `RowCol`-based access
and provides grid-related functionality.

The `OrthoMap` we created earlier supports all of this as it is a wrapper around
a `RectGrid`, but you can apply these same functions to any 2D array by wrapping
it with `rectGrid`.

The simplest grid operation is to access a tile by its coordinate:

```d
auto tile = tileMap.tileAt(RowCol(2,3));  // grab the tile at row 2, column 3
```

Now, you may be wondering how `grid.tileAt(RowCol(r,c))` is any different from
`grid[r][c]`. The answer is, its not. At least, not until you get a bit tired
and type `grid[c][r]`. The use of `RowCol` as an index throughout dtiled strives
to avoid these annoying mistakes. As a bonus, `RowCol` is a nice way to pass
around coordinate pairs and provides a few other benefits:

```d
RowCol(2,3).south(5)          // (7,3)
RowCol(2,3).south.east        // (3,4)
RowCol(2,3).adjacent          // [ (1,3), (2,2), (2,4), (3,3) ]
RowCol(0,0).span(RowCol(2,2)) // [ (0,0), (0,1), (1,0), (1,1) ]
```

Here are some other useful things you can do with a grid:

```d
auto neighbors = grid.adjacentTiles(RowCol(2,3));
auto surrounding = grid.adjacentTiles(RowCol(2,3), Diagonals.yes);
auto coords = grid.adjacentCoords(RowCol(2,3)); // coords instead of tiles
```

Nice, but still pretty standard fare. What if you need to select tiles with a
bit more finesse?

Suppose you are making a game where the player can place walls of various
shapes. The player wants to place an 'L' shaped wall at the coordinate (5,3),
and you need to know if every tile the wall would cover is currently empty:

```d
uint[3][3] mask = [
  [ 0, 1, 0 ]
  [ 0, 1, 1 ]
  [ 0, 0, 0 ]
];

auto tilesUnderWall = grid.maskTilesAround(RowCol(5,3), mask);
bool canPlaceWall = tilesUnderWall.all!(x => !x.hasObstruction);
```

`OrthoMap` supports all of this functionality as it is a wrapper around a
`RectGrid`.

# Algorithms
Most of the above was pretty mundane, so lets break out `dtiled.algorithm`.

Suppose your map has some walls on it, represented by a `hasWall` field on your
`Tile`. You want to know if the player is standing in a 'room' entirely enclosed
by walls:

```d
auto room = map.enclosedTiles!(x => x.hasWall)(playerCoord);
if (!room.empty) // player is in a room
```

A more general function is `floodTiles`, which returns a range that lazily
flood-fills tiles meeting a certain condition. By contrast, `enclosedTiles` is
evaluated eagerly to determine if the area is totally enclosed.

gs sometimes it is useful to get coordinates instead of tiles, most functions
that yield tiles have a counterpart that yields coordinates. Instead of
`floodTiles` and `enclosedTiles`, you could use `floodCoords` and
`enclosedCoords`.
