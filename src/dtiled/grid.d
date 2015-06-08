/**
 * A set of utilities for working with 2D grids of rectangular tiles.
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

/// Types used in examples:
version(unittest) {
  import std.conv : to;

  // create a test grid, where each tile is simply a string of form "rc"
  // where r is the row number and c is the column number
  private TileGrid!string makeTestGrid(int rows, int cols) {
    string[][] tiles;

    foreach(row ; 0..rows) {
      string[] newRow;
      foreach(col ; 0..cols) {
        newRow ~= (row.to!string ~ col.to!string);
      }
      tiles ~= newRow;
    }

    return TileGrid!string(tiles);
  }
}

unittest {
  auto grid = makeTestGrid(5, 10);
  assert(grid.numRows == 5);
  assert(grid.numCols == 10);
  assert(grid.numTiles == 50);
}

/**
 * Represents a grid of rectangular tiles.
 */
struct TileGrid(Tile) {
  private Tile[][] _tiles;

  /// Number of columns along the tile grid x axis
  @property auto numCols() { return _tiles[0].length; }

  /// Number of rows along the tile grid y axis
  @property auto numRows() { return _tiles.length; }

  /// The total number of tiles in the grid.
  @property auto numTiles() { return numRows * numCols; }

  /**
   * Wrap a 2D array in a grid structure. The grid must be rectangular (not jagged).
   *
   * Params:
   *  tiles = tiles arranged in **row major** order, indexed as tiles[row][col].
   */
  this(Tile[][] tiles) {
    assertNotJagged(tiles, "tiles");

    _tiles = tiles;
  }

  /**
   * True if the grid coordinate is within the grid and map bounds.
   */
  bool contains(RowCol coord) {
    return
      coord.row >= 0      &&
      coord.col >= 0      &&
      coord.row < numRows &&
      coord.col < numCols;
  }

  ///
  unittest {
    // 5x3 map, rows from 0 to 4, cols from 0 to 2
    auto grid = makeTestGrid(5, 3);
    assert( grid.contains(RowCol(0 , 0)));  // top left
    assert( grid.contains(RowCol(4 , 2)));  // bottom right
    assert( grid.contains(RowCol(3 , 1)));  // center
    assert(!grid.contains(RowCol(0 , 3)));  // beyond right border
    assert(!grid.contains(RowCol(5 , 0)));  // beyond bottom border
    assert(!grid.contains(RowCol(0 ,-1))); // beyond left border
    assert(!grid.contains(RowCol(-1, 0))); // beyond top border
  }

  /**
   * Get the tile at a given position in the grid. Throws if out of bounds.
   * Params:
   *  coord = a row/column pair identifying a point in the tile grid.
   */
  ref Tile tileAt(RowCol coord) {
    assert(contains(coord), "coord %s not in bounds".format(coord));
    return _tiles[coord.row][coord.col];
  }

  ///
  unittest {
    import std.exception  : assertThrown;

    // the test map looks like:
    // 00 01 02 03 04
    // 10 11 12 13 14
    // 20 21 22 23 24
    auto grid = makeTestGrid(3, 5);

    assert(grid.tileAt(RowCol(0, 0)) == "00"); // top left tile
    assert(grid.tileAt(RowCol(2, 4)) == "24"); // bottom right tile
    assert(grid.tileAt(RowCol(1, 1)) == "11");
  }

  /// Foreach over every tile in the map.
  int opApply(int delegate(ref Tile) fn) {
    int res = 0;

    foreach(coord; RowCol(0, 0).span(RowCol(numRows, numCols))) {
      res = fn(tileAt(coord));
      if (res) break;
    }

    return res;
  }

  ///
  unittest {
    // the test map looks like:
    // 00 01 02 03 04
    // 10 11 12 13 14
    // 20 21 22 23 24
    auto myGrid = makeTestGrid(3, 5);
    string[] actual;

    foreach(tile ; myGrid) { actual ~= tile; }
    assert(actual == [
        "00", "01", "02", "03", "04",
        "10", "11", "12", "13", "14",
        "20", "21", "22", "23", "24"]);
  }

  /// Foreach over every [coordinate,tile] pair in the map.
  int opApply(int delegate(RowCol, ref Tile) fn) {
    int res = 0;

    foreach(coord; RowCol(0, 0).span(RowCol(numRows, numCols))) {
      res = fn(coord, tileAt(coord));
      if (res) break;
    }

    return res;
  }

  ///
  unittest {
    import std.format : format;
    // the test map looks like:
    // 00 01 02
    // 10 11 12
    auto myGrid = makeTestGrid(2, 3);

    foreach(coord, tile ; myGrid) {
      assert(tile == "%d%d".format(coord.row, coord.col));
    }
  }

  /**
   * Same as maskTiles, but return coords instead of tiles.
   */
  auto maskCoords(T)(RowCol offset, in T[][] mask) if (is(typeof(cast(bool) T.init))) {
    assertNotJagged(mask, "mask");

    return RowCol(0,0).span(arraySize2D(mask))
      .filter!(x => mask[x.row][x.col]) // remove elements that are 0 in the mask
      .map!(x => x + offset)            // add the offset to get the corresponding map coord
      .filter!(x => contains(x));       // remove coords outside of bounds
  }

  /**
   * Select specific tiles from this slice based on a mask.
   *
   * The upper left corner of the mask is positioned at the given offset.
   * Each map tile that is overlaid with a 'true' value is included in the result.
   * The mask is allowed to extend out of bounds - out of bounds coordinates are ignored
   *
   * Params:
   *  T = type of mask marker. Anything that is convertible to bool
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
  auto maskTiles(T)(in T[][] mask) if (is(typeof(cast(bool) T.init))) {
    return maskCoords(mask).map!(x => tileAt(x));
  }

  /**
   * Same as maskCoords, but centered.
   *
   * Params:
   *  center = map coord on which to position the center of the mask.
   *           if the mask has an even side length, rounds down to compute the 'center'
   *  mask = a rectangular array of true/false values indicating which tiles to take.
   *         each true value takes the tile at that grid coordinate.
   *         the mask should be in row major order (indexed as mask[row][col]).
   */
  auto maskCoordsAround(T)(RowCol center, in T[][] mask) if (is(typeof(cast(bool) T.init))) {
    assertNotJagged(mask, "mask");

    auto offset = center - RowCol(mask.length / 2, mask[0].length / 2);

    return maskCoords(offset, mask);
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
  auto maskTilesAround(T)(RowCol center, in T[][] mask) if (is(typeof(cast(bool) T.init))) {
    return maskCoordsAround(center, mask).map!(x => tileAt(x));
  }

  /// More masking examples:
  unittest {
    import std.array : empty;
    import std.algorithm : equal;
    // the test map looks like:
    // 00 01 02 03 04
    // 10 11 12 13 14
    // 20 21 22 23 24
    auto myGrid = makeTestGrid(3, 5);

    auto mask1 = [
      [ 1, 1, 1 ],
      [ 0, 0, 0 ],
      [ 0, 0, 0 ],
    ];
    assert(myGrid.maskTilesAround(RowCol(0,0), mask1).empty);
    assert(myGrid.maskTilesAround(RowCol(1,1), mask1).equal(["00", "01", "02"]));
    assert(myGrid.maskTilesAround(RowCol(2,1), mask1).equal(["10", "11", "12"]));
    assert(myGrid.maskTilesAround(RowCol(2,4), mask1).equal(["13", "14"]));

    auto mask2 = [
      [ 0, 0, 1 ],
      [ 0, 0, 1 ],
      [ 1, 1, 1 ],
    ];
    assert(myGrid.maskTilesAround(RowCol(0,0), mask2).equal(["01", "10", "11"]));
    assert(myGrid.maskTilesAround(RowCol(1,2), mask2).equal(["03", "13", "21", "22", "23"]));
    assert(myGrid.maskTilesAround(RowCol(2,4), mask2).empty);

    auto mask3 = [
      [ 0 , 0 , 1 , 0 , 0 ],
      [ 1 , 0 , 1 , 0 , 1 ],
      [ 0 , 0 , 0 , 0 , 0 ],
    ];
    assert(myGrid.maskTilesAround(RowCol(0,0), mask3).equal(["00", "02"]));
    assert(myGrid.maskTilesAround(RowCol(1,2), mask3).equal(["02", "10", "12", "14"]));

    auto mask4 = [
      [ 1 , 1 , 1 , 0 , 1 ],
    ];
    assert(myGrid.maskTilesAround(RowCol(0,0), mask4).equal(["00", "02"]));
    assert(myGrid.maskTilesAround(RowCol(2,2), mask4).equal(["20", "21", "22", "24"]));

    auto mask5 = [
      [ 1 ],
      [ 1 ],
      [ 0 ],
      [ 1 ],
      [ 1 ],
    ];
    assert(myGrid.maskTilesAround(RowCol(0,4), mask5).equal(["14", "24"]));
    assert(myGrid.maskTilesAround(RowCol(1,1), mask5).equal(["01", "21"]));
  }

  /**
   * Return all tiles adjacent to the tile at the given coord (not including the tile itself).
   *
   * Params:
   *  coord = grid location of center tile.
   *  diagonal = if no, include tiles to the north, south, east, and west only.
   *             if yes, additionaly include northwest, northeast, southwest, and southeast.
   */
  auto adjacentTiles(RowCol coord, Diagonals diagonals = Diagonals.no) {
    return coord.adjacent(diagonals)
      .filter!(x => contains(x))
      .map!(x => tileAt(x));
  }

  ///
  unittest {
    import std.algorithm : equal;
    // the test map looks like:
    // 00 01 02 03 04
    // 10 11 12 13 14
    // 20 21 22 23 24
    auto myGrid = makeTestGrid(3, 5);

    assert(myGrid.adjacentTiles(RowCol(0,0)).equal(["01", "10"]));
    assert(myGrid.adjacentTiles(RowCol(1,1)).equal(["01", "10", "12", "21"]));
    assert(myGrid.adjacentTiles(RowCol(2,2)).equal(["12", "21", "23"]));
    assert(myGrid.adjacentTiles(RowCol(2,4)).equal(["14", "23"]));

    assert(myGrid.adjacentTiles(RowCol(0,0), Diagonals.yes)
        .equal(["01", "10", "11"]));
    assert(myGrid.adjacentTiles(RowCol(1,1), Diagonals.yes)
        .equal(["00", "01", "02", "10", "12", "20", "21", "22"]));
    assert(myGrid.adjacentTiles(RowCol(2,2), Diagonals.yes)
        .equal(["11", "12", "13", "21", "23"]));
    assert(myGrid.adjacentTiles(RowCol(2,4), Diagonals.yes)
        .equal(["13", "14", "23"]));
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
void createMask(alias fn, Tile, T)(TileGrid!Tile grid, RowCol offset, ref T mask)
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
void createMaskAround(alias fn, Tile, T)(TileGrid!Tile grid, RowCol center, ref T mask)
  if(__traits(compiles, { mask[0][0] = fn(grid.tileAt(RowCol(0,0))); }))
{
  assertNotJagged(mask, "mask");

  auto offset = center - RowCol(mask.length / 2, mask[0].length / 2);
  createMask!fn(grid, offset, mask);
}

///
unittest {
  import std.conv;
  // the test map looks like:
  // 00 01 02 03 04
  // 10 11 12 13 14
  // 20 21 22 23 24
  auto myGrid = makeTestGrid(3, 5);

  uint[3][3] mask;

  myGrid.createMaskAround!(tile => tile.to!int > 10)(RowCol(1,1), mask);

  assert(mask == [
      [0, 0, 0],
      [0, 1, 1],
      [1, 1, 1],
  ]);

  myGrid.createMaskAround!(tile => tile.to!int < 24)(RowCol(2,4), mask);

  assert(mask == [
      [1, 1, 0],
      [1, 0, 0],
      [0, 0, 0],
  ]);
}

// assertion helper for input array args
private void assertNotJagged(T)(in T array, string name) {
  assert(array[].all!(x => x.length == array[0].length),
      "param %s must be a rectangular (non-jagged) array".format(name));
}

// get a RowCol representing the size of a 2D array (assumed non-jagged).
private auto arraySize2D(T)(in T array) {
  return RowCol(array.length, array[0].length);
}
