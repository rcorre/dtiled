/**
 * Provides functions that treat a 2D array as a rectangular grid of tiles.
 *
 * Authors: <a href="https://github.com/rcorre">rcorre</a>
 * License: <a href="http://opensource.org/licenses/MIT">MIT</a>
 * Copyright: Copyright © 2015, Ryan Roden-Corrent
 */
module dtiled.grid;

import std.range     : only, chain, takeNone, hasLength;
import std.format    : format;
import std.algorithm : all, map, filter;
import std.exception : enforce;
import dtiled.coords;

/// True if T is a static or dynamic array type.
enum isArray2D(T) = is(typeof(T.init[0][0]))              && // 2D random access
                    is(typeof(T.init.length)    : size_t) && // stores count of rows
                    is(typeof(T.init[0].length) : size_t);   // stores count of columns

///
unittest {
  import std.container : Array;

  static assert(isArray2D!(int[][]));
  static assert(isArray2D!(char[3][5]));
  static assert(isArray2D!(Array!(Array!int)));
}

/// Convenience function to wrap a RectGrid around a 2D array.
auto rectGrid(T)(T tiles) if (isArray2D!T) { return RectGrid!T(tiles); }

///
unittest {
  auto dynamicArray = [
    [1,2,3],
    [4,5,6]
  ];
  auto dynamicGrid = rectGrid(dynamicArray);
  assert(dynamicGrid.numRows == 2 && dynamicGrid.numCols == 3);
  static assert(is(dynamicGrid.TileType == int));

  char[3][2] staticArray = [
    [ 'a', 'a', 'a' ],
    [ 'a', 'a', 'a' ],
  ];
  auto staticGrid = rectGrid(staticArray);
  assert(staticGrid.numRows == 2 && staticGrid.numCols == 3);
  static assert(is(staticGrid.TileType == char));
}

struct RectGrid(T) if (isArray2D!T) {
  private T _tiles;

  /// The type used to represent a tile in this grid
  alias TileType = typeof(_tiles[0][0]);

  /// Construct a grid from a 2D tile array. See rectGrid for a constructor with type inference.
  this(T tiles) {
    assertNotJagged(tiles, "RectGrid cannot be a constructed from a jagged array");
    _tiles = tiles;
  }

  /// Number of columns along a grid's x axis.
  auto numCols() { return _tiles[0].length; }

  ///
  unittest {
    auto grid = rectGrid([
      [ 0, 0, 0, 0 ],
      [ 0, 0, 0, 0 ],
    ]);

    assert(grid.numCols == 4);
  }

  /// Number of rows along a grid's y axis.
  auto numRows() { return _tiles.length; }

  unittest {
    auto grid = rectGrid([
      [ 0, 0, 0, 0 ],
      [ 0, 0, 0, 0 ],
    ]);

    assert(grid.numRows == 2);
  }

  /// The total number of tiles in a grid.
  auto numTiles() { return this.numRows * this.numCols; }

  unittest {
    auto grid = rectGrid([
      [ 0, 0, 0, 0 ],
      [ 0, 0, 0, 0 ],
    ]);

    assert(grid.numTiles == 8);
  }

  /**
   * True if the grid coordinate is within the grid bounds.
   */
  bool contains(RowCol coord) {
    return
      coord.row >= 0           &&
      coord.col >= 0           &&
      coord.row < this.numRows &&
      coord.col < this.numCols;
  }

  ///
  unittest {
    // 5x3 map
    auto grid = rectGrid([
      //0  1  2  3  4 col   row
      [ 0, 0, 0, 0, 0 ], // 0
      [ 0, 0, 0, 0, 0 ], // 1
      [ 0, 0, 0, 0, 0 ], // 2
    ]);

    assert( grid.contains(RowCol(0 , 0))); // top left
    assert( grid.contains(RowCol(2 , 4))); // bottom right
    assert( grid.contains(RowCol(1 , 2))); // center
    assert(!grid.contains(RowCol(0 , 5))); // beyond right border
    assert(!grid.contains(RowCol(3 , 0))); // beyond bottom border
    assert(!grid.contains(RowCol(0 ,-1))); // beyond left border
    assert(!grid.contains(RowCol(-1, 0))); // beyond top border
  }

  /**
   * Get the tile at a given position in the grid.
   * The coord must be in bounds.
   *
   * Params:
   *  grid = grid from which to retrieve tile.
   *  coord = a row/column pair identifying a point in the tile grid.
   */
  ref auto tileAt(RowCol coord) {
    assert(this.contains(coord), "coord %s not in bounds".format(coord));
    return _tiles[coord.row][coord.col];
  }

  ///
  unittest {
    auto grid = rectGrid([
      [ 00, 01, 02, 03, 04 ],
      [ 10, 11, 12, 13, 14 ],
      [ 20, 21, 22, 23, 24 ],
    ]);

    assert(grid.tileAt(RowCol(0, 0)) == 00); // top left tile
    assert(grid.tileAt(RowCol(2, 4)) == 24); // bottom right tile
    assert(grid.tileAt(RowCol(1, 1)) == 11); // one down/right from the top left

    // tileAt returns a reference:
    grid.tileAt(RowCol(2,2)) = 99;
    assert(grid.tileAt(RowCol(2,2)) == 99);
  }

  /**
   * Get a range that iterates through every coordinate in the grid.
   */
  auto allCoords() {
    return RowCol(0,0).span(RowCol(this.numRows, this.numCols));
  }

  /// Use allCoords to apply range-oriented functions to the coords in the grid.
  unittest {
    import std.algorithm;

    auto myGrid = rectGrid([
      [ 00, 01, 02, 03, 04 ],
      [ 10, 11, 12, 13, 14 ],
      [ 20, 21, 22, 23, 24 ],
    ]);

    auto coords = myGrid.allCoords
      .filter!(x => x.col > 3)
      .map!(x => x.row * 10 + x.col);

    assert(coords.equal([04, 14, 24]));
  }

  /**
   * Get a range that iterates through every tile in the grid.
   */
  auto allTiles() {
    return this.allCoords.map!(coord => this.tileAt(coord));
  }

  /// Use allTiles to apply range-oriented functions to the tiles in the grid.
  unittest {
    import std.algorithm;

    auto myGrid = rectGrid([
      [ 00, 01, 02, 03, 04 ],
      [ 10, 11, 12, 13, 14 ],
      [ 20, 21, 22, 23, 24 ],
    ]);

    assert(myGrid.allTiles.filter!(x => x > 22).equal([23, 24]));
  }

  /// Foreach over every tile in the grid. Supports `ref`.
  int opApply(int delegate(ref TileType) fn) {
    int res = 0;

    foreach(coord ; this.allCoords) {
      res = fn(this.tileAt(coord));
      if (res) break;
    }

    return res;
  }

  /// foreach with coords
  unittest {
    auto myGrid = rectGrid([
      [ 00, 01, 02, 03, 04 ],
      [ 10, 11, 12, 13, 14 ],
      [ 20, 21, 22, 23, 24 ],
    ]);

    int[] actual;
    foreach(tile ; myGrid) { actual ~= tile; }

    assert(actual == [
        00, 01, 02, 03, 04,
        10, 11, 12, 13, 14,
        20, 21, 22, 23, 24]);
  }

  /// Foreach over every (coord,tile) pair in the grid. Supports `ref`.
  int opApply(int delegate(RowCol, ref TileType) fn) {
    int res = 0;

    foreach(coord ; this.allCoords) {
      res = fn(coord, this.tileAt(coord));
      if (res) break;
    }

    return res;
  }

  /// foreach with coords
  unittest {
    auto myGrid = rectGrid([
      [ 00, 01, 02, 03, 04 ],
      [ 10, 11, 12, 13, 14 ],
      [ 20, 21, 22, 23, 24 ],
    ]);

    foreach(coord, tile ; myGrid) {
      assert(tile == coord.row * 10 + coord.col);
    }
  }

  /**
   * Same as maskTiles, but return coords instead of tiles.
   *
   * Params:
   *  grid = grid to apply mask to
   *  offset = map coordinate on which to align the top-left corner of the mask.
   *  mask = a rectangular array of true/false values indicating which tiles to take.
   *         each true value takes the tile at that grid coordinate.
   *         the mask should be in row major order (indexed as mask[row][col]).
   */
  auto maskCoords(T)(RowCol offset, in T mask) if (isValidMask!T) {
    assertNotJagged(mask, "mask cannot be a jagged array");

    return RowCol(0,0).span(arraySize2D(mask))
      .filter!(x => mask[x.row][x.col]) // remove elements that are 0 in the mask
      .map!(x => x + offset)            // add the offset to get the corresponding map coord
      .filter!(x => this.contains(x));  // remove coords outside of bounds
  }

  /**
   * Select specific tiles from this slice based on a mask.
   *
   * The upper left corner of the mask is positioned at the given offset.
   * Each map tile that is overlaid with a 'true' value is included in the result.
   * The mask is allowed to extend out of bounds - out of bounds coordinates are ignored
   *
   * Params:
   *  grid = grid to apply mask to
   *  offset = map coordinate on which to align the top-left corner of the mask.
   *  mask = a rectangular array of true/false values indicating which tiles to take.
   *         each true value takes the tile at that grid coordinate.
   *         the mask should be in row major order (indexed as mask[row][col]).
   *
   * Examples:
   * Suppose you are making a strategy game, and an attack hits all tiles in a cross pattern.
   * This attack is used on the tile at row 2, column 3.
   * You want to check each tile that was affected to see if any unit was hit:
   * --------------
   * // cross pattern
   * ubyte[][] attackPattern = [
   *   [0,1,0]
   *   [1,1,1]
   *   [0,1,0]
   * ];
   *
   * // get tiles contained by a cross pattern centered at (2,3)
   * auto tilesHit = map.maskTilesAround((RowCol(2, 3), attackPattern));
   *
   * // now do something with those tiles
   * auto unitsHit = tilesHit.map!(tile => tile.unitOnTile).filter!(unit => unit !is null);
   * foreach(unit ; unitsHit) unit.applySomeEffect;
   * --------------
   */
  auto maskTiles(T)(RowCol offset, in T mask) if (isValidMask!T) {
    return this.maskCoords(mask).map!(x => this.tileAt(x));
  }

  /**
   * Same as maskCoords, but centered.
   *
   * Params:
   *  grid = grid to apply mask to
   *  center = map coord on which to position the center of the mask.
   *           if the mask has an even side length, rounds down to compute the 'center'
   *  mask = a rectangular array of true/false values indicating which tiles to take.
   *         each true value takes the tile at that grid coordinate.
   *         the mask should be in row major order (indexed as mask[row][col]).
   */
  auto maskCoordsAround(T)(RowCol center, in T mask) if (isValidMask!T) {
    assertNotJagged(mask, "mask");

    auto offset = center - RowCol(mask.length / 2, mask[0].length / 2);

    return this.maskCoords(offset, mask);
  }

  /**
   * Same as maskTiles, but centered.
   *
   * Params:
   *  center = map coord on which to position the center of the mask.
   *           if the mask has an even side length, rounds down to compute the 'center'
   *  mask = a rectangular array of true/false values indicating which tiles to take.
   *         each true value takes the tile at that grid coordinate.
   *         the mask should be in row major order (indexed as mask[row][col]).
   */
  auto maskTilesAround(T)(RowCol center, in T mask) if (isValidMask!T) {
    return this.maskCoordsAround(center, mask).map!(x => this.tileAt(x));
  }

  /// More masking examples:
  unittest {
    import std.array : empty;
    import std.algorithm : equal;

    auto myGrid = rectGrid([
      [ 00, 01, 02, 03, 04 ],
      [ 10, 11, 12, 13, 14 ],
      [ 20, 21, 22, 23, 24 ],
    ]);

    uint[3][3] mask1 = [
      [ 1, 1, 1 ],
      [ 0, 0, 0 ],
        [ 0, 0, 0 ],
    ];
    assert(myGrid.maskTilesAround(RowCol(0,0), mask1).empty);
    assert(myGrid.maskTilesAround(RowCol(1,1), mask1).equal([00, 01, 02]));
    assert(myGrid.maskTilesAround(RowCol(2,1), mask1).equal([10, 11, 12]));
    assert(myGrid.maskTilesAround(RowCol(2,4), mask1).equal([13, 14]));

    auto mask2 = [
      [ 0, 0, 1 ],
      [ 0, 0, 1 ],
      [ 1, 1, 1 ],
    ];
    assert(myGrid.maskTilesAround(RowCol(0,0), mask2).equal([01, 10, 11]));
    assert(myGrid.maskTilesAround(RowCol(1,2), mask2).equal([03, 13, 21, 22, 23]));
    assert(myGrid.maskTilesAround(RowCol(2,4), mask2).empty);

    auto mask3 = [
      [ 0 , 0 , 1 , 0 , 0 ],
      [ 1 , 0 , 1 , 0 , 1 ],
      [ 0 , 0 , 0 , 0 , 0 ],
    ];
    assert(myGrid.maskTilesAround(RowCol(0,0), mask3).equal([00, 02]));
    assert(myGrid.maskTilesAround(RowCol(1,2), mask3).equal([02, 10, 12, 14]));

    auto mask4 = [
      [ 1 , 1 , 1 , 0 , 1 ],
    ];
    assert(myGrid.maskTilesAround(RowCol(0,0), mask4).equal([00, 02]));
    assert(myGrid.maskTilesAround(RowCol(2,2), mask4).equal([20, 21, 22, 24]));

    auto mask5 = [
      [ 1 ],
      [ 1 ],
      [ 0 ],
      [ 1 ],
      [ 1 ],
    ];
    assert(myGrid.maskTilesAround(RowCol(0,4), mask5).equal([14, 24]));
    assert(myGrid.maskTilesAround(RowCol(1,1), mask5).equal([01, 21]));
  }

  /**
   * Return all tiles adjacent to the tile at the given coord (not including the tile itself).
   *
   * Params:
   *  coord     = grid location of center tile.
   *  diagonals = if no, include tiles to the north, south, east, and west only.
   *              if yes, also include northwest, northeast, southwest, and southeast.
   */
  auto adjacentTiles(RowCol coord, Diagonals diagonals = Diagonals.no) {
    return coord.adjacent(diagonals)
      .filter!(x => this.contains(x))
      .map!(x => this.tileAt(x));
  }

  ///
  unittest {
    import std.algorithm : equal;
    auto myGrid = rectGrid([
      [ 00, 01, 02, 03, 04 ],
      [ 10, 11, 12, 13, 14 ],
      [ 20, 21, 22, 23, 24 ],
    ]);

    assert(myGrid.adjacentTiles(RowCol(0,0)).equal([01, 10]));
    assert(myGrid.adjacentTiles(RowCol(1,1)).equal([01, 10, 12, 21]));
    assert(myGrid.adjacentTiles(RowCol(2,2)).equal([12, 21, 23]));
    assert(myGrid.adjacentTiles(RowCol(2,4)).equal([14, 23]));

    assert(myGrid.adjacentTiles(RowCol(0,0), Diagonals.yes)
        .equal([01, 10, 11]));
    assert(myGrid.adjacentTiles(RowCol(1,1), Diagonals.yes)
        .equal([00, 01, 02, 10, 12, 20, 21, 22]));
    assert(myGrid.adjacentTiles(RowCol(2,2), Diagonals.yes)
        .equal([11, 12, 13, 21, 23]));
    assert(myGrid.adjacentTiles(RowCol(2,4), Diagonals.yes)
        .equal([13, 14, 23]));
  }
}

// NOTE: declared outside of struct due to issues with alias parameters on templated structs.
// See https://issues.dlang.org/show_bug.cgi?id=11098
/**
 * Generate a mask from a region of tiles based on a condition.
 *
 * For each tile in the grid, sets the corresponding element of mask to the result of fn(tile).
 * If a coordinate is out of bounds (e.g. if you are generating a mask from a slice that extends
 * over the map border) the mask value is the init value of the mask's element type.
 *
 * Params:
 *  fn = function that generates a mask entry from a tile
 *  grid = grid to generate mask from
 *  offset = map coord from which to start the top-left corner of the mask
 *  mask = rectangular array to populate with generated mask values.
 *         must match the size of the grid
 */
void createMask(alias fn, T, U)(T grid, RowCol offset, ref U mask)
  if(__traits(compiles, { mask[0][0] = fn(grid.tileAt(RowCol(0,0))); }))
{
  assertNotJagged(mask, "mask");

  foreach(coord ; RowCol(0,0).span(arraySize2D(mask))) {
    auto mapCoord = coord + offset;

    mask[coord.row][coord.col] = (grid.contains(mapCoord)) ?
      fn(grid.tileAt(mapCoord)) : // in bounds, apply fn to generate mask value
      typeof(mask[0][0]).init;    // out of bounds, use default value
  }
}

/**
 * Same as createMask, but specify the offset of the mask's center rather than the top-left corner.
 *
 * Params:
 *  fn = function that generates a mask entry from a tile
 *  grid = grid to generate mask from
 *  center = center position around which to generate mask
 *  mask = rectangular array to populate with generated mask values.
 *         must match the size of the grid
 */
void createMaskAround(alias fn, T, U)(T grid, RowCol center, ref U mask)
  if(__traits(compiles, { mask[0][0] = fn(grid.tileAt(RowCol(0,0))); }))
{
  assertNotJagged(mask, "mask");

  auto offset = center - RowCol(mask.length / 2, mask[0].length / 2);
  grid.createMask!fn(offset, mask);
}

///
unittest {
  auto myGrid = rectGrid([
      [ 00, 01, 02, 03, 04 ],
      [ 10, 11, 12, 13, 14 ],
      [ 20, 21, 22, 23, 24 ],
  ]);

  uint[3][3] mask;

  myGrid.createMaskAround!(tile => tile > 10)(RowCol(1,1), mask);

  assert(mask == [
      [0, 0, 0],
      [0, 1, 1],
      [1, 1, 1],
  ]);

  myGrid.createMaskAround!(tile => tile < 24)(RowCol(2,4), mask);

  assert(mask == [
      [1, 1, 0],
      [1, 0, 0],
      [0, 0, 0],
  ]);
}

private:
// assertion helper for input array args
void assertNotJagged(T)(in T array, string msg) {
  assert(array[].all!(x => x.length == array[0].length), msg);
}

// get a RowCol representing the size of a 2D array (assumed non-jagged).
auto arraySize2D(T)(in T array) {
  return RowCol(array.length, array[0].length);
}

enum isValidMask(T) = is(typeof(cast(bool) T.init[0][0]))   && // must have boolean elements
                      is(typeof(T.init.length)    : size_t) && // must have row count
                      is(typeof(T.init[0].length) : size_t);   // must have column count

unittest {
  static assert(isValidMask!(int[][]));
  static assert(isValidMask!(uint[][3]));
  static assert(isValidMask!(uint[3][]));
  static assert(isValidMask!(uint[3][3]));

  static assert(!isValidMask!int);
  static assert(!isValidMask!(int[]));
}
