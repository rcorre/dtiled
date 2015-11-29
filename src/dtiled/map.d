/**
 * A map is essentially a grid with additional information about tile positions and sizes.
 * 
 * Currently, the only map type is `OrthoMap`, but `IsoMap` and `HexMap` may be added in later
 * versions.
 * 
 * An `OrthoMap` represents a map of rectangular (usually square) tiles that are arranged
 * orthogonally. In other words, all tiles in a row are at the same y corrdinate, and all tiles in
 * a column are at the same x coordinate (as opposed to an Isometric map, where there is an offset).
 * 
 * An `OrthoMap` provides all of the functionality as `RectGrid`. 
 * It also stores the size of tiles and provides functions to translate between 'grid coordinates'
 * (row/column) and 'screen coordinates' (x/y pixel positions).
 *
 * Authors: <a href="https://github.com/rcorre">rcorre</a>
 * License: <a href="http://opensource.org/licenses/MIT">MIT</a>
 * Copyright: Copyright © 2015, Ryan Roden-Corrent
 */
module dtiled.map;

import dtiled.coords;
import dtiled.grid;

// need a test here to kickstart the unit tests inside OrthoMap!T
unittest {
  auto map = OrthoMap!int([[1]], 32, 32);
}

/**
 * Generic Tile Map structure that uses a single layer of tiles in an orthogonal grid.
 *
 * This provides a 'flat' representation of multiple tile and object layers.
 * T can be whatever type you would like to use to represent a single tile within the map.
 *
 * An OrthoMap supports all the operations of dtiled.grid for working with RowCol coordinates.
 * Additionally, it stores information about tile size for operations in pixel coordinate space.
 */
struct OrthoMap(Tile) {
  /// The underlying tile grid structure, surfaced with alias this.
  RectGrid!(Tile[][]) grid;
  alias grid this;

  private {
    int _tileWidth;
    int _tileHeight;
  }

  /**
   * Construct an orthogonal tilemap from a rectangular (non-jagged) grid of tiles.
   *
   * Params:
   *  tiles      = tiles arranged in **row major** order, indexed as tiles[row][col].
   *  tileWidth  = width of each tile in pixels
   *  tileHeight = height of each tile in pixels
   */
  this(Tile[][] tiles, int tileWidth, int tileHeight) {
    this(rectGrid(tiles), tileWidth, tileHeight);
  }

  /// ditto
  this(RectGrid!(Tile[][]) grid, int tileWidth, int tileHeight) {
    _tileWidth  = tileWidth;
    _tileHeight = tileHeight;

    this.grid = grid;
  }

  @property {
    /// Width of each tile in pixels
    auto tileWidth()  { return _tileWidth; }
    /// Height of each tile in pixels
    auto tileHeight() { return _tileHeight; }
  }

  /**
   * Get the grid location corresponding to a given pixel coordinate.
   *
   * If the point is out of map bounds, the returned coord will also be out of bounds.
   * Use the containsPoint method to check if a point is in bounds.
   */
  auto coordAtPoint(T)(T pos) if (isPixelCoord!T) {
    import std.math   : floor, lround;

    return RowCol(floor(pos.y / tileHeight).lround,
                  floor(pos.x / tileWidth).lround);
  }

  ///
  unittest {
    struct Vec { float x, y; }

    // 5x3 map, rows from 0 to 4, cols from 0 to 2
    auto tiles = [
      [ 00, 01, 02, 03, 04, ],
      [ 10, 11, 12, 13, 14, ],
      [ 20, 21, 22, 23, 24, ],
    ];
    auto map = OrthoMap!int(tiles, 32, 32);

    assert(map.coordAtPoint(Vec(0   , 0  )) == RowCol(0  , 0 ));
    assert(map.coordAtPoint(Vec(16  , 16 )) == RowCol(0  , 0 ));
    assert(map.coordAtPoint(Vec(32  , 0  )) == RowCol(0  , 1 ));
    assert(map.coordAtPoint(Vec(0   , 45 )) == RowCol(1  , 0 ));
    assert(map.coordAtPoint(Vec(105 , 170)) == RowCol(5  , 3 ));
    assert(map.coordAtPoint(Vec(-10 , 0  )) == RowCol(0  , -1));
    assert(map.coordAtPoint(Vec(-32 , -33)) == RowCol(-2 , -1));
  }

  /**
   * True if the pixel position is within the map bounds.
   */
  bool containsPoint(T)(T pos) if (isPixelCoord!T) {
    return grid.contains(coordAtPoint(pos));
  }

  ///
  unittest {
    // 3x5 map, pixel bounds are [0, 0, 160, 96] (32*3 = 96, 32*5 = 160)
    auto grid = [
      [ 00, 01, 02, 03, 04, ],
      [ 10, 11, 12, 13, 14, ],
      [ 20, 21, 22, 23, 24, ],
    ];
    auto map = OrthoMap!int(grid, 32, 32);

    assert( map.containsPoint(PixelCoord(   0,    0))); // top left
    assert( map.containsPoint(PixelCoord( 159,   95))); // bottom right
    assert( map.containsPoint(PixelCoord(  80,   48))); // center
    assert(!map.containsPoint(PixelCoord(   0,   96))); // beyond right border
    assert(!map.containsPoint(PixelCoord( 160,    0))); // beyond bottom border
    assert(!map.containsPoint(PixelCoord(   0, -0.5))); // beyond left border
    assert(!map.containsPoint(PixelCoord(-0.5,    0))); // beyond top border
  }

  /**
   * Get the tile at a given pixel position on the map. Throws if out of bounds.
   * Params:
   *  T = any pixel-positional point (see isPixelCoord).
   *  pos = pixel location in 2D space
   */
  ref Tile tileAtPoint(T)(T pos) if (isPixelCoord!T) {
    assert(containsPoint(pos), "position %d,%d out of map bounds: ".format(pos.x, pos.y));
    return grid.tileAt(coordAtPoint(pos));
  }

  ///
  unittest {
    auto grid = [
      [ 00, 01, 02, 03, 04, ],
      [ 10, 11, 12, 13, 14, ],
      [ 20, 21, 22, 23, 24, ],
    ];

    auto map = OrthoMap!int(grid, 32, 32);

    assert(map.tileAtPoint(PixelCoord(  0,  0)) == 00); // corner of top left tile
    assert(map.tileAtPoint(PixelCoord( 16, 30)) == 00); // inside top left tile
    assert(map.tileAtPoint(PixelCoord(149, 95)) == 24); // inside bottom right tile
  }

  /**
   * Get the pixel offset of the top-left corner of the tile at the given coord.
   *
   * Params:
   *  coord = grid location of tile.
   */
  PixelCoord tileOffset(RowCol coord) {
    return PixelCoord(coord.col * tileWidth,
                      coord.row * tileHeight);
  }

  ///
  unittest {
    // 2 rows, 3 cols, 32x64 tiles
    auto grid = [
      [ 00, 01, 02, ],
      [ 10, 11, 12, ],
    ];
    auto myMap = OrthoMap!int(grid, 32, 64);

    assert(myMap.tileOffset(RowCol(0, 0)) == PixelCoord(0, 0));
    assert(myMap.tileOffset(RowCol(1, 2)) == PixelCoord(64, 64));
  }

  /**
   * Get the pixel offset of the center of the tile at the given coord.
   *
   * Params:
   *  coord = grid location of tile.
   */
  PixelCoord tileCenter(RowCol coord) {
    return PixelCoord(coord.col * tileWidth  + tileWidth  / 2,
                      coord.row * tileHeight + tileHeight / 2);
  }

  ///
  unittest {
    // 2 rows, 3 cols, 32x64 tiles
    auto grid = [
      [ 00, 01, 02, ],
      [ 10, 11, 12, ],
    ];
    auto myMap = OrthoMap!int(grid, 32, 64);

    assert(myMap.tileCenter(RowCol(0, 0)) == PixelCoord(16, 32));
    assert(myMap.tileCenter(RowCol(1, 2)) == PixelCoord(80, 96));
  }
}

/// Foreach over every tile in the map
unittest {
  import std.algorithm : equal;

  auto grid = [
    [ 00, 01, 02, ],
    [ 10, 11, 12, ],
  ];
  auto myMap = OrthoMap!int(grid, 32, 64);

  int[] result;

  foreach(tile ; myMap) result ~= tile;

  assert(result.equal([ 00, 01, 02, 10, 11, 12 ]));
}

/// Use ref with foreach to modify tiles
unittest {
  auto grid = [
    [ 00, 01, 02, ],
    [ 10, 11, 12, ],
  ];
  auto myMap = OrthoMap!int(grid, 32, 64);

  foreach(ref tile ; myMap) tile += 30;

  assert(myMap.tileAt(RowCol(1,1)) == 41);
}

/// Foreach over every (coord, tile) pair in the map
unittest {
  import std.algorithm : equal;

  auto grid = [
    [ 00, 01, 02, ],
    [ 10, 11, 12, ],
  ];
  auto myMap = OrthoMap!int(grid, 32, 64);


  foreach(coord, tile ; myMap) assert(myMap.tileAt(coord) == tile);
}
