/**
 * Provides a generic map structure with commonly-needed functionality.
 *
 * While the types provided in dtiled.data are intended to provide the information needed to
 * load a map into a game, a TileMap is a structure intended to be used in-game.
 *
 * A  map structure is like a grid structure with additional of logic to work with pixel coords.
 *
 * Authors: <a href="https://github.com/rcorre">rcorre</a>
 * License: <a href="http://opensource.org/licenses/MIT">MIT</a>
 * Copyright: Copyright © 2015, Ryan Roden-Corrent
 */
module dtiled.map;

import dtiled.grid;
import dtiled.coords;

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
  Tile[][] grid; /// The underlying tile grid structure, surfaced with alias this.
  alias grid this;

  private {
    int _tileWidth;
    int _tileHeight;
  }

  /**
   * Construct an orthogonal tilemap. The grid must be rectangular (not jagged).
   *
   * Params:
   *  tiles      = tiles arranged in **row major** order, indexed as tiles[row][col].
   *  tileWidth  = width of each tile in pixels
   *  tileHeight = height of each tile in pixels
   */
  this(Tile[][] tiles, int tileWidth, int tileHeight) {
    _tileWidth  = tileWidth;
    _tileHeight = tileHeight;

    debug {
      import std.algorithm : all;
      assert(tiles.all!(x => x.length == tiles[0].length),
          "all rows of an OrthoMap must have the same length (cannot be jagged array)");
    }

    this.grid = tiles;
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
    import std.traits : isFloatingPoint, Select;
    // if T is not floating, cast to float for operation
    alias F = Select!(isFloatingPoint!T, T, float);

    RowCol coord;
    coord.col = floor(pos.x / cast(F) tileWidth).lround;
    coord.row = floor(pos.y / cast(F) tileHeight).lround;
    return coord;
  }

  ///
  unittest {
    // 5x3 map, rows from 0 to 4, cols from 0 to 2
    auto grid = [
      [ 00, 01, 02, 03, 04, ],
      [ 10, 11, 12, 13, 14, ],
      [ 20, 21, 22, 23, 24, ],
    ];
    auto map = OrthoMap!int(grid, 32, 32);

    assert( map.contains(RowCol(0 , 0))); // top left
    assert( map.contains(RowCol(4 , 2))); // bottom right
    assert( map.contains(RowCol(3 , 1))); // center
    assert(!map.contains(RowCol(0 , 3))); // beyond right border
    assert(!map.contains(RowCol(5 , 0))); // beyond bottom border
    assert(!map.contains(RowCol(0 ,-1))); // beyond left border
    assert(!map.contains(RowCol(-1, 0))); // beyond top border
  }

  /**
   * True if the pixel position is within the map bounds.
   */
  bool containsPoint(T)(T pos) if (isPixelCoord!T) {
    return grid.contains(coordAtPoint(pos));
  }

  ///
  unittest {
    // 5x3 map, pixel bounds are [0, 0, 96, 160] (32*3 = 96, 32*5 = 160)
    auto grid = [
      [ 00, 01, 02, 03, 04, ],
      [ 10, 11, 12, 13, 14, ],
      [ 20, 21, 22, 23, 24, ],
    ];
    auto map = OrthoMap!int(grid, 32, 32);

    assert( map.containsPoint(PixelCoord(   0,    0))); // top left
    assert( map.containsPoint(PixelCoord(  95,  159))); // bottom right
    assert( map.containsPoint(PixelCoord(  48,   80))); // center
    assert(!map.containsPoint(PixelCoord(  96,    0))); // beyond right border
    assert(!map.containsPoint(PixelCoord(   0,  160))); // beyond bottom border
    assert(!map.containsPoint(PixelCoord(-0.5,    0))); // beyond left border
    assert(!map.containsPoint(PixelCoord(   0, -0.5))); // beyond top border
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
    auto myMap = OrthoMap(grid, 32, 64);

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
    auto myMap = testMap(grid, 32, 64);

    assert(myMap.tileCenter(RowCol(0, 0)) == PixelCoord(16, 32));
    assert(myMap.tileCenter(RowCol(1, 2)) == PixelCoord(80, 96));
  }
}
