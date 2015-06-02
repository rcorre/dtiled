/**
 * A set of utilities for working with 2D grids of rectangular tiles.
 *
 * Authors: <a href="https://github.com/rcorre">rcorre</a>
 * License: <a href="http://opensource.org/licenses/MIT">MIT</a>
 * Copyright: Copyright © 2015, Ryan Roden-Corrent
 */
module dtiled.grid;

import std.range     : only, takeNone, chain;
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
}

/**
 * Represents a grid of rectangular tiles.
 */
struct TileGrid(Tile) {
  const {
    RowCol sliceOffset; /// coord of the top-left corner of this slice
    size_t numRows;     /// Number of rows along the tile grid y axis
    size_t numCols;     /// Number of cols along the tile grid x axis
  }

  private Tile[][] _tiles;

  /**
   * Wrap a 2D array in a grid structure. The grid must be rectangular (not jagged).
   *
   * Params:
   *  tiles = tiles arranged in **row major** order, indexed as tiles[row][col].
   */
  this(Tile[][] tiles) {
    // set the bounds to the entire size of the array
    this(tiles, RowCol(0, 0), tiles.length, tiles[0].length);
  }

  // internal slice constructor
  private this(Tile[][] tiles, RowCol sliceOffset, size_t nRows, size_t nCols) {
    assert(tiles.all!(x => x.length == tiles[0].length),
        "all rows of an OrthoMap must have the same length (cannot be jagged array)");

    _tiles = tiles;
    this.sliceOffset = sliceOffset;
    this.numRows = nRows;
    this.numCols = nCols;
  }

  private {
    bool sliceContains(RowCol coord) {
      return
        coord.row >= 0 && coord.row < numRows && // row in slice bounds
        coord.col >= 0 && coord.col < numCols;   // col in slice bounds
    }

    bool sourceContains(RowCol coord) {
      auto absCoord = coord + sliceOffset; // coord relative to source
      return
        absCoord.row >= 0 && absCoord.row < _tiles.length &&  // row in source bounds
        absCoord.col >= 0 && absCoord.col < _tiles[0].length; // col in source bounds
    }

    void enforceBounds(RowCol coord) {
      enforce(sliceContains(coord),
        "%s is out of slice bounds [%s,%s)"
        .format(coord + sliceOffset, RowCol(0,0), RowCol(numRows, numCols)));

      enforce(sourceContains(coord),
        "%s is out of source bounds [%s,%s)"
        .format(coord, RowCol(0,0), RowCol(_tiles.length, _tiles[0].length)));
    }
  }

  /**
   * True if the grid coordinate is within the grid and map bounds.
   */
  bool contains(RowCol coord) {
    return sliceContains(coord) && sourceContains(coord);
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
    enforceBounds(coord);
    auto relativeCoord = coord + sliceOffset;
    return _tiles[relativeCoord.row][relativeCoord.col];
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

    // tileAt enforces in-bounds access
    assertThrown(grid.tileAt(RowCol(-1, -1))); // row/col out of bounds (< 0)
    assertThrown(grid.tileAt(RowCol(3, 1)));   // row out of bounds (> 2)
  }

  /// Foreach over every tile in the map.
  int opApply(int delegate(ref Tile) fn) {
    int res = 0;

    foreach(coord; RowCol(0, 0).span(RowCol(numRows, numCols))) {
      if (!sourceContains(coord)) continue;
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

    // foreach over a subsection of a large grid
    actual = [];
    foreach(tile ; myGrid.sliceAround(RowCol(1,1), 3)) { actual ~= tile; }
    assert(actual == [
        "00", "01", "02",
        "10", "11", "12",
        "20", "21", "22"]);

    // tiles out of bounds are not included
    actual = [];
    foreach(tile ; myGrid.sliceAround(RowCol(0,0), 3)) { actual ~= tile; }
    assert(actual == [
        "00", "01",
        "10", "11"]);
  }

  /// Foreach over every [coordinate,tile] pair in the map.
  int opApply(int delegate(RowCol, ref Tile) fn) {
    int res = 0;

    foreach(coord; RowCol(0, 0).span(RowCol(numRows, numCols))) {
      if (!sourceContains(coord)) continue;
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
   * Create a slice of the grid covering the region [start, end$(RPAREN).
   *
   * Params:
   *  start = northwest corner of slice, inclusive.
   *  end = southeast corner of slice, exclusive.
   */
  @nogc
  auto opSlice(RowCol start, RowCol end) {
    auto relStart = start + sliceOffset;
    auto size = end - start;
    return TileGrid!Tile(_tiles, relStart, size.row, size.col);
  }

  ///
  unittest {
    import std.exception : assertThrown;
    // the test map looks like:
    // 00 01 02 03 04
    // 10 11 12 13 14
    // 20 21 22 23 24
    auto myGrid = makeTestGrid(3, 5);

    // slice from upper left corner to 1,1
    auto slice1 = myGrid[RowCol(0,0)..RowCol(2, 2)];
    assert(slice1.numRows == 2 && slice1.numCols == 2);
    assert(slice1.tileAt(RowCol(0,0)) == "00");
    assert(slice1.tileAt(RowCol(1,1)) == "11");
    assertThrown(slice1.tileAt(RowCol(-1,-1)));
    assertThrown(slice1.tileAt(RowCol(2,2)));

    //// slice from 1,1 to lower right corner
    auto slice2 = myGrid[RowCol(1,1)..RowCol(3, 5)];
    assert(slice2.numRows == 2 && slice1.numCols == 2);
    assert(slice2.tileAt(RowCol(0,0)) == "11");
    assert(slice2.tileAt(RowCol(1,3)) == "24");
    assertThrown(slice2.tileAt(RowCol(2,3)));
  }

  /**
   * Create a slice from a rectangular subsection of the map centered at origin.
   *
   * Params:
   *  origin = Center coordinate of region.
   *  numRows = Vertical size of rect.
   *  numCols = Horizontal size of rect.
   */
  @nogc
  auto sliceAround(RowCol origin, size_t numRows, size_t numCols) {
    auto start = origin - RowCol(numRows / 2, numCols / 2);
    auto end = start + RowCol(numRows, numCols);

    return this[start .. end];
  }

  ///
  unittest {
    import std.exception : assertThrown;
    // the test map looks like:
    // 00 01 02 03 04
    // 10 11 12 13 14
    // 20 21 22 23 24
    auto myGrid = makeTestGrid(3, 5);

    // region of size 1 centered at 1,1
    auto slice1 = myGrid.sliceAround(RowCol(1,2), 1, 5);
    assert(slice1.numRows == 1 && slice1.numCols == 5);
    assert(slice1.tileAt(RowCol(0,0)) == "10");
    assert(slice1.tileAt(RowCol(0,1)) == "11");
    assert(slice1.tileAt(RowCol(0,4)) == "14");
    assertThrown(slice1.tileAt(RowCol(-1,-1)));
    assertThrown(slice1.tileAt(RowCol(1,1)));
  }

  /**
   * Create a slice from a square subsection of the grid centered at origin.
   *
   * Params:
   *  origin = Center coordinate of region.
   *  size = Number of tiles along each side of the square.
   */
  @nogc
  auto sliceAround(RowCol origin, size_t size) {
    return sliceAround(origin, size, size);
  }

  ///
  unittest {
    import std.exception : assertThrown;
    // the test map looks like:
    // 00 01 02 03 04
    // 10 11 12 13 14
    // 20 21 22 23 24
    auto myGrid = makeTestGrid(3, 5);

    // region of size 1 centered at 1,1
    auto slice1 = myGrid.sliceAround(RowCol(1,1), 3);
    assert(slice1.numRows == 3 && slice1.numCols == 3);
    assert(slice1.tileAt(RowCol(0,0)) == "00");
    assert(slice1.tileAt(RowCol(1,1)) == "11");
    assert(slice1.tileAt(RowCol(2,1)) == "21");
    assertThrown(slice1.tileAt(RowCol(-1,-1)));
    assertThrown(slice1.tileAt(RowCol(3,1)));

    //// slice centered at 0,4 that extends partially out of bounds
    auto slice2 = myGrid.sliceAround(RowCol(0, 4), 3);
    assert(slice1.numRows == 3 && slice1.numCols == 3);
    assert(slice2.tileAt(RowCol(1,0)) == "03");
    assert(slice2.tileAt(RowCol(2,1)) == "14");
    assertThrown(slice2.tileAt(RowCol(0,0)));
    assertThrown(slice2.tileAt(RowCol(2,2)));
  }

  /**
   * Select specific tiles from this slice based on a mask.
   *
   * The mask must be the same size as the grid.
   * As you often want to apply this to a subsection of the map, it works well in combination with
   * opSlice or sliceAround.
   * Each map tile that is overlaid with a 'true' value is included in the result.
   *
   * Params:
   *  T = type of mask marker. Anything that is convertible to bool
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
   * auto tilesHit = map.sliceAround((RowCol(2, 3), 1).mask(attackPattern));
   *
   * // now do something with those tiles
   * auto unitsHit = tilesHit.map!(tile => tile.unitOnTile).filter!(unit => unit !is null);
   * --------------
   */
  auto mask(T)(in T[][] mask) if (is(typeof(cast(bool) T.init))) {
    assert(mask.length    == numRows, "a mask must be the same size as the grid");
    assert(mask[0].length == numCols, "a mask must be the same size as the grid");
    assert(mask.all!(x => x.length == mask[0].length), "a mask cannot be a jagged array");

    return RowCol(0,0).span(RowCol(numRows, numCols))
      .filter!(x => mask[x.row][x.col]) // remove elements that are 0 in the mask
      .filter!(x => sourceContains(x))  // remove coords outside of source map
      .map!(x => tileAt(x));            // grab tiles at those coords
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
    assert(myGrid.sliceAround(RowCol(0,0), 3).mask(mask1).empty);
    assert(myGrid.sliceAround(RowCol(1,1), 3).mask(mask1).equal(["00", "01", "02"]));
    assert(myGrid.sliceAround(RowCol(2,1), 3).mask(mask1).equal(["10", "11", "12"]));
    assert(myGrid.sliceAround(RowCol(2,4), 3).mask(mask1).equal(["13", "14"]));

    auto mask2 = [
      [ 0, 0, 1 ],
      [ 0, 0, 1 ],
      [ 1, 1, 1 ],
    ];
    assert(myGrid.sliceAround(RowCol(0,0), 3).mask(mask2).equal(["01", "10", "11"]));
    assert(myGrid.sliceAround(RowCol(1,2), 3).mask(mask2).equal(["03", "13", "21", "22", "23"]));
    assert(myGrid.sliceAround(RowCol(2,4), 3).mask(mask2).empty);

    auto mask3 = [
      [ 0 , 0 , 1 , 0 , 0 ],
      [ 1 , 0 , 1 , 0 , 1 ],
      [ 0 , 0 , 0 , 0 , 0 ],
    ];
    assert(myGrid.sliceAround(RowCol(0,0), 3, 5).mask(mask3).equal(["00", "02"]));
    assert(myGrid.sliceAround(RowCol(1,2), 3, 5).mask(mask3).equal(["02", "10", "12", "14"]));

    auto mask4 = [
      [ 1 , 1 , 1 , 0 , 1 ],
    ];
    assert(myGrid.sliceAround(RowCol(0,0), 1, 5).mask(mask4).equal(["00", "02"]));
    assert(myGrid.sliceAround(RowCol(2,2), 1, 5).mask(mask4).equal(["20", "21", "22", "24"]));

    auto mask5 = [
      [ 1 ],
      [ 1 ],
      [ 0 ],
      [ 1 ],
      [ 1 ],
    ];
    assert(myGrid.sliceAround(RowCol(0,4), 5, 1).mask(mask5).equal(["14", "24"]));
    assert(myGrid.sliceAround(RowCol(1,1), 5, 1).mask(mask5).equal(["01", "21"]));
  }

  /**
   * Return all tiles adjacent to the tile at the given coord (not including the tile itself).
   *
   * Params:
   *  coord = grid location of center tile.
   *  diagonal = if no, include tiles to the north, south, east, and west only.
   *             if yes, additionaly include northwest, northeast, southwest, and southeast.
   */
  auto tilesAdjacent(RowCol coord, IncludeDiagonal diagonal = IncludeDiagonal.no) {
    return coord.adjacent(diagonal)
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

    assert(myGrid.tilesAdjacent(RowCol(0,0)).equal(["01", "10"]));
    assert(myGrid.tilesAdjacent(RowCol(1,1)).equal(["01", "10", "12", "21"]));
    assert(myGrid.tilesAdjacent(RowCol(2,2)).equal(["12", "21", "23"]));
    assert(myGrid.tilesAdjacent(RowCol(2,4)).equal(["14", "23"]));

    assert(myGrid.tilesAdjacent(RowCol(0,0), IncludeDiagonal.yes)
        .equal(["01", "10", "11"]));
    assert(myGrid.tilesAdjacent(RowCol(1,1), IncludeDiagonal.yes)
        .equal(["00", "01", "02", "10", "12", "20", "21", "22"]));
    assert(myGrid.tilesAdjacent(RowCol(2,2), IncludeDiagonal.yes)
        .equal(["11", "12", "13", "21", "23"]));
    assert(myGrid.tilesAdjacent(RowCol(2,4), IncludeDiagonal.yes)
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
 *  mask = rectangular array to populate with generated mask values.
 *         must match the size of the grid
 */
void createMask(alias fn, Tile, T)(TileGrid!Tile grid, ref T mask)
  if(__traits(compiles, { mask[0][0] = fn(grid.tileAt(RowCol(0,0))); }))
{
  foreach(coord ; RowCol(0, 0).span(RowCol(grid.numRows, grid.numCols))) {
    mask[coord.row][coord.col] = (grid.sourceContains(coord)) ?
      fn(grid.tileAt(coord)) :   // in bounds, apply fn to generate mask value
      typeof(T.init[0][0]).init; // out of bounds, use default value
  }
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

  myGrid.sliceAround(RowCol(1,1), 3).createMask!(tile => tile.to!int > 10)(mask);

  assert(mask == [
      [0, 0, 0],
      [0, 1, 1],
      [1, 1, 1],
  ]);

  myGrid.sliceAround(RowCol(2,4), 3).createMask!(tile => tile.to!int < 24)(mask);

  assert(mask == [
      [1, 1, 0],
      [1, 0, 0],
      [0, 0, 0],
  ]);
}
