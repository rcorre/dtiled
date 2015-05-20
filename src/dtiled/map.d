/**
 * Provides a generic map structure with commonly-needed functionality.
 *
 * While the types provided in dtiled.data are intended to provide the information needed to
 * load a map into a game, a TileMap is a structure intended to be used in-game.
 *
 * Authors: <a href="https://github.com/rcorre">rcorre</a>
 * License: <a href="http://opensource.org/licenses/MIT">MIT</a>
 * Copyright: Copyright © 2015, Ryan Roden-Corrent
 */
module dtiled.map;

import std.range     : only, takeNone, chain;
import std.algorithm : all, map, filter;
import std.exception : enforce;
import dtiled.data;
import dtiled.coords;

/// Types used in examples:
version(unittest) {
  import std.conv : to;

  private struct TestTile { string id; }

  OrthoMap!TestTile testMap(int rows, int cols, int tileWidth, int tileHeight) {
    TestTile[][] tiles;

    foreach(row ; 0..rows) {
      TestTile[] newRow;
      foreach(col ; 0..cols) {
        newRow ~= TestTile(row.to!string ~ col.to!string);
      }
      tiles ~= newRow;
    }

    return OrthoMap!TestTile(tileWidth, tileHeight, tiles);
  }
}

unittest {
  auto map = testMap(5, 10, 32, 64);
  assert(map.numRows    == 5);
  assert(map.numCols    == 10);
  assert(map.tileWidth  == 32);
  assert(map.tileHeight == 64);
}

/**
 * Generic Tile Map structure that uses a single layer of tiles in an orthogonal grid.
 *
 * This provides a 'flat' representation of multiple tile and object layers.
 * T can be whatever type you would like to use to represent a single tile within the map.
 */
struct OrthoMap(Tile) {
  private {
    Tile[][] _tiles;
    int _tileWidth;
    int _tileHeight;
  }

  /**
   * Construct an orthogonal tilemap. The grid must be rectangular (not jagged).
   *
   * Params:
   *  tileWidth = width of each tile in pixels
   *  tileHeight = height of each tile in pixels
   *  tiles = tiles arranged in **row major** order, indexed as tiles[row][col].
   */
  this(int tileWidth, int tileHeight, Tile[][] tiles) {
    _tileWidth  = tileWidth;
    _tileHeight = tileHeight;

    debug {
      import std.algorithm : all;
      assert(tiles.all!(x => x.length == tiles[0].length),
          "all rows of an OrthoMap must have the same length (cannot be jagged array)");
    }

    _tiles = tiles;
  }

  @property {
    /// Number of rows along the tile grid y axis
    auto numRows()    { return _tiles.length; }
    /// Number of columns along the tile grid x axis
    auto numCols()    { return _tiles[0].length; }
    /// Width of each tile in pixels
    auto tileWidth()  { return _tileWidth; }
    /// Height of each tile in pixels
    auto tileHeight() { return _tileHeight; }
    /// Access the underlying tile store
    auto tiles()      { return _tiles; }
  }

  /**
   * Get the grid location corresponding to a given pixel coordinate.
   * Returns outOfBounds if coord lies outside of the map.
   */
  auto gridCoordAt(T)(T pos) if (isPixelCoord!T) {
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
    auto map = testMap(10, 10, 32, 32); // 10x10 map of tiles sized 32x32
    assert(map.gridCoordAt(PixelCoord(0 ,  0)) == RowCol(0, 0));
    assert(map.gridCoordAt(PixelCoord(16, 48)) == RowCol(1, 0));
    assert(map.gridCoordAt(PixelCoord(64, 32)) == RowCol(1, 2));

    // no bounds checking
    assert(map.gridCoordAt(PixelCoord(320, 320)) == RowCol(10, 10));
    // negative indices round down
    assert(map.gridCoordAt(PixelCoord(-16, -48)) == RowCol(-2, -1));
  }

  /**
   * True if the grid coordinate is within the map bounds.
   */
  bool contains(RowCol coord) {
    return coord.row >= 0 && coord.col >= 0 && coord.row < numRows && coord.col < numCols;
  }

  ///
  unittest {
    // 5x3 map, rows from 0 to 4, cols from 0 to 2
    auto map = testMap(5, 3, 32, 32);
    assert( map.contains(RowCol(0 , 0)));  // top left
    assert( map.contains(RowCol(4 , 2)));  // bottom right
    assert( map.contains(RowCol(3 , 1)));  // center
    assert(!map.contains(RowCol(0 , 3)));  // beyond right border
    assert(!map.contains(RowCol(5 , 0)));  // beyond bottom border
    assert(!map.contains(RowCol(0 ,-1))); // beyond left border
    assert(!map.contains(RowCol(-1, 0))); // beyond top border
  }

  /**
   * True if the pixel position is within the map bounds.
   */
  bool contains(T)(T pos) if (isPixelCoord!T) {
    return contains(gridCoordAt(pos));
  }

  ///
  unittest {
    // 5x3 map, pixel bounds are [0, 0, 96, 160] (32*3 = 96, 32*5 = 160)
    auto map = testMap(5, 3, 32, 32);
    assert( map.contains(PixelCoord(   0,    0))); // top left
    assert( map.contains(PixelCoord(  95,  159))); // bottom right
    assert( map.contains(PixelCoord(  48,   80))); // center
    assert(!map.contains(PixelCoord(  96,    0))); // beyond right border
    assert(!map.contains(PixelCoord(   0,  160))); // beyond bottom border
    assert(!map.contains(PixelCoord(-0.5,    0))); // beyond left border
    assert(!map.contains(PixelCoord(   0, -0.5))); // beyond top border
  }

  /**
   * Get the tile at a given position in the grid. Throws if out of bounds.
   * Params:
   *  coord = a row/column pair identifying a point in the tile grid.
   */
  Tile tileAt(RowCol coord) {
    enforce(contains(coord), "row/col out of map bounds: " ~ coord.toString);
    return _tiles[coord.row][coord.col];
  }

  ///
  unittest {
    import std.exception  : assertThrown;

    // the test map looks like:
    // 00 01 02 03 04
    // 10 11 12 13 14
    // 20 21 22 23 24
    auto map = testMap(3, 5, 32, 32);

    assert(map.tileAt(RowCol(0, 0)).id == "00"); // top left tile
    assert(map.tileAt(RowCol(2, 4)).id == "24"); // bottom right tile
    assert(map.tileAt(RowCol(1, 1)).id == "11");

    // tileAt enforces in-bounds access
    assertThrown(map.tileAt(RowCol(-1, -1))); // row/col out of bounds (< 0)
    assertThrown(map.tileAt(RowCol(3, 1)));   // row out of bounds (> 2)
  }

  /**
   * Get the tile at a given pixel position on the map. Throws if out of bounds.
   * Params:
   *  T = any pixel-positional point (see isPixelCoord).
   *  pos = pixel location in 2D space
   */
  Tile tileAt(T)(T pos) if (isPixelCoord!T) {
    enforce(contains(pos), "position out of map bounds: " ~ pos.toString);
    return tileAt(gridCoordAt(pos));
  }

  ///
  unittest {
    import std.exception  : assertThrown;

    // the test map looks like:
    // 00 01 02 03 04
    // 10 11 12 13 14
    // 20 21 22 23 24
    auto map = testMap(3, 5, 32, 32);

    assert(map.tileAt(PixelCoord(  0,  0)).id == "00"); // corner of top left tile
    assert(map.tileAt(PixelCoord( 16, 30)).id == "00"); // inside top left tile
    assert(map.tileAt(PixelCoord(149, 95)).id == "24"); // inside bottom right tile

    // tileAt enforces in-bounds access
    assertThrown(map.tileAt(PixelCoord(-0.5, 0))); // beyond far left
    assertThrown(map.tileAt(PixelCoord(0, 97)));   // beyond far bottom
  }

  /**
   * Return all tiles that share an edge with the tile at the given coord.
   * Does not include the tile at that coord.
   *
   * Params:
   *  coord = grid location of center tile.
   */
  auto adjacent(RowCol coord) {
    immutable ubyte[][] neighborMask = [
      [0,1,0],
      [1,0,1],
      [0,1,0],
    ];

    return this.mask(coord, neighborMask);
  }

  ///
  unittest {
    // the test map looks like:
    // 00 01 02 03 04
    // 10 11 12 13 14
    // 20 21 22 23 24
    auto myMap = testMap(3, 5, 32, 32);

    void test(RowCol coord, string[] expected ...) {
      import std.array     : array;
      import std.format    : format;
      import std.algorithm : all, canFind;

      auto actual = myMap.adjacent(coord).map!(x => x.id).array;

      assert(expected.all!(id => actual.canFind(id)) && actual.length == expected.length,
          "neighbors incorrect for (%d, %d), expected %s, got %s"
          .format(coord.row, coord.col, expected, actual));
    }

    test(RowCol(1, 1), "01", "12", "21", "10"); // tile not bordering any map edge

    test(RowCol(0, 0), "01", "10");       // top left corner
    test(RowCol(0, 0), "01", "10");       // bottom left
    test(RowCol(0, 4), "03", "14");       // top right
    test(RowCol(2, 4), "23", "14");       // bottom right
    test(RowCol(1, 0), "00", "11", "20"); // center left
    test(RowCol(1, 4), "04", "13", "24"); // center right
    test(RowCol(2, 2), "21", "12", "23"); // bottom center
    test(RowCol(0, 2), "01", "12", "03"); // top center
  }

  /**
   * Return all tiles that share an edge or corner with the tile at the given coord.
   * Does not include the tile at that coord.
   *
   * Params:
   *  coord = grid location of center tile.
   */
  auto around(RowCol coord) {
    immutable ubyte[][] neighborMask = [
      [1,1,1],
      [1,0,1],
      [1,1,1],
    ];

    return this.mask(coord, neighborMask);
  }

  ///
  unittest {
    // the test map looks like:
    // 00 01 02 03 04
    // 10 11 12 13 14
    // 20 21 22 23 24
    auto myMap = testMap(3, 5, 32, 32);

    void test(RowCol coord, string[] expected ...) {
      import std.array     : array;
      import std.format    : format;
      import std.algorithm : all, canFind;

      auto actual = myMap.around(coord).map!(x => x.id).array;

      assert(expected.all!(id => actual.canFind(id)) && actual.length == expected.length,
          "surrounding tiles incorrect for (%d, %d), expected %s, got %s"
          .format(coord.row, coord.col, expected, actual));
    }

    test(RowCol(1, 1), "00", "02", "22", "20", "01", "12", "21", "10");
    test(RowCol(0, 0), "01", "10", "11");
    test(RowCol(2, 1), "20", "10", "11", "12", "22");
  }

  /**
   * Select specific tiles from within a rectangular region as defined by a mask.
   *
   * The mask's center is aligned with the given origin coordinate on the map.
   * Each map tile that is overlaid with a 'true' value is included in the result.
   * The mask is allowed to extend out of bounds.
   *
   * Params:
   *  T = type of mask marker. Anything that is convertible to bool
   *  origin = coordinate on the map to position the center of the mask.
   *  mask = a rectangular array of 0s and 1s indicating which tiles to take.
   *         each true value takes the tile at that grid coordinate relative to origin.
   *         the center of the mask is determined by its length / 2 in each dimension.
   *         the mask should be in row major order (indexed as mask[row][col]).
   *
   * Examples:
   * Suppose you are making a strategy game, and an attack hits all tiles in a cross pattern.
   * This attack is used on the tile at row 2, column 3.
   * You want to check each tile that was affected to see if any unit was hit:
   * --------------
   * // cross pattern
   * ubyte[][] mask = [
   *  [0,1,0]
   *  [1,1,1]
   *  [0,1,0]
   * ]
   *
   * // tiles contained by a cross pattern centered at (2,3)
   * auto tilesHit = map.mask(RowCol(2, 3), mask);
   *
   * // now do something with those tiles
   * auto unitsHit = tilesHit.map!(tile => tile.unitOnTile).filter!(unit => unit !is null);
   * --------------
   */
  auto mask(T)(RowCol origin, in T[][] mask) if (is(typeof(cast(bool) T.init))) {
    auto nRows = mask.length;
    assert(nRows > 0, "a mask cannot be empty");

    auto nCols = mask[0].length;
    assert(mask.all!(x => x.length == nCols), "a mask cannot be a jagged array");

    auto start = RowCol(0, 0);
    auto end = RowCol(nRows - 1, nCols - 1);
    auto offset = origin - RowCol(nRows / 2, nCols / 2);

    return start.span(end)
      .filter!(x => mask[x.row][x.col]) // remove elements that are 0 in the mask
      .map!(x => x + offset)            // adjust mask coordinate to map coordinate
      .filter!(x => this.contains(x))   // remove out of bounds coords
      .map!(x => this.tileAt(x));       // grab the tile for each coord
  }

  /// More masking examples:
  unittest {
    // the test map looks like:
    // 00 01 02 03 04
    // 10 11 12 13 14
    // 20 21 22 23 24
    auto myMap = testMap(3, 5, 32, 32);

    void test(T)(RowCol origin, T[][] mask, string[] expected ...) {
      import std.array     : array;
      import std.format    : format;
      import std.algorithm : all, canFind;

      auto actual = myMap.mask(origin, mask).map!(x => x.id).array;
      assert(expected.all!(id => actual.canFind(id)) && actual.length == expected.length,
          "mask incorrect: %s (%d, %d), expected %s, got %s"
          .format(mask, origin.row, origin.col, expected, actual));
    }

    auto mask1 = [
      [ 1, 1, 1 ],
      [ 0, 0, 0 ],
      [ 0, 0, 0 ],
    ];

    auto mask2 = [
      [ 0, 0, 1 ],
      [ 0, 0, 1 ],
      [ 1, 1, 1 ],
    ];

    auto mask3 = [
      [ 0 , 0 , 1 , 0 , 0 ],
      [ 1 , 0 , 1 , 0 , 1 ],
      [ 0 , 0 , 0 , 0 , 0 ],
    ];

    auto mask4 = [
      [ 1 , 1 , 1 , 0 , 1 ],
    ];

    auto mask5 = [
      [ 1 ],
      [ 1 ],
      [ 0 ],
      [ 1 ],
      [ 1 ],
    ];

    test(RowCol(1, 1), mask1, "00", "01", "02");
    test(RowCol(1, 1), mask2, "02", "12", "22", "21", "20");
    test(RowCol(1, 2), mask3, "10", "02", "12", "14");
    test(RowCol(1, 2), mask4, "10", "11", "12", "14");

    // it is fine if part of the mask extends out of bounds
    test(RowCol(1, 0), mask1, "00", "01");
    test(RowCol(2, 4), mask2); // all tiles in area are out of bounds
    test(RowCol(1, 2), mask5, "02", "22");
  }
}
