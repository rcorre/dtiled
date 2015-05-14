/**
 * Provides a generic TileMap structure with commonly-needed functionality.
 *
 * While the types provided in dtiled.data are intended to provide the information needed to
 * load a map into a game, a TileMap is a structure intended to be used in-game.
 *
 * Authors: <a href="https://github.com/rcorre">rcorre</a>
 * License: <a href="http://opensource.org/licenses/MIT">MIT</a>
 * Copyright: Copyright © 2015, Ryan Roden-Corrent
 */
module dtiled.map;

import std.range     : only, take, chain;
import std.algorithm : map, filter;
import std.exception : enforce;
import dtiled.data;
import dtiled.spatial;

/// Types used in examples:
version(unittest) {
  struct TestTile { int row, col; }

  alias TestMap = OrthoMap!TestTile;

  auto testMap(int rows, int cols, int tileWidth, int tileHeight) {
    TestTile[][] tiles;

    foreach(row ; 0..rows) {
      TestTile[] newRow;
      foreach(col ; 0..cols) {
        newRow ~= TestTile(row, col);
      }
      tiles ~= newRow;
    }

    return TestMap(tileWidth, tileHeight, tiles);
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
 * Which tiles are included when getting the neighbors of a tile.
 *
 * Given the following grid of tiles:
 * v e v
 * e c e
 * v e v
 * 'c' is the 'center', 'e' are the 'edge' neighbors, and 'v' are the 'vertex' neighbors.
 * 'surround' would include all 'e' and 'v' tiles, 'all' would of course include all.
 */
enum NeighborType {
  center = 1 >> 0, /// The center tile.
  edge   = 1 >> 1, /// Tiles adjacent to the sides of the center.
  vertex = 1 >> 2, /// Tiles diagonally bordering the corners of the center.

  surround = edge | vertex,     /// All tiles around the center.
  all      = surround | center, /// All tiles around and including the center.
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
    size_t _numRows;
    size_t _numCols;
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

    _numRows = tiles.length;
    _numCols = tiles[0].length;

    debug {
      import std.algorithm : all;
      assert(tiles.all!(x => x.length == tiles[0].length),
          "all rows of an OrthoMap must have the same length (cannot be jagged array)");
    }

    _tiles = tiles;
  }

  @property {
    /// Number of rows along the tile grid y axis
    auto numRows()    { return _numRows; }
    /// Number of columns along the tile grid x axis
    auto numCols()    { return _numCols; }
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

  /**
   * Get the tile at a given position in the grid. Throws if out of bounds.
   * Params:
   *  coord = a row/column pair identifying a point in the tile grid.
   */
  Tile tileAt(RowCol coord) {
    enforce(contains(coord), "row/col out of map bounds: " ~ coord.toString);
    return _tiles[coord.row][coord.col];
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

  /**
   * Return tiles adjacent to the given tile.
   *
   * Params:
   *  coord = grid location of center tile.
   *  neighbors = describes which neighbors to fetch.
   */
  auto neighbors(RowCol coord, NeighborType neighbors = NeighborType.edge) {
    // TODO: this should be doable without allocating. custom range?
    RowCol[] coords;

    if (neighbors & NeighborType.center) {
      coords ~= coord;
    }

    if (neighbors & NeighborType.edge) {
      coords ~= RowCol(coord.row - 1, coord.col    );
      coords ~= RowCol(coord.row    , coord.col - 1);
      coords ~= RowCol(coord.row + 1, coord.col    );
      coords ~= RowCol(coord.row    , coord.col + 1);
    }

    if (neighbors & NeighborType.vertex) {
      coords ~= RowCol(coord.row - 1, coord.col - 1);
      coords ~= RowCol(coord.row - 1, coord.col + 1);
      coords ~= RowCol(coord.row + 1, coord.col - 1);
      coords ~= RowCol(coord.row + 1, coord.col + 1);
    }

    // for the in-range coordinates, get the corresponding tiles
    return coords.filter!(x => this.contains(x)).map!(x => this.tileAt(x));
  }
}
