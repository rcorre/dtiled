/**
 * Provides various useful operations on a tile grid.
 */
module dtiled.algorithm;

import std.range;
import std.typecons : Tuple;
import std.algorithm;
import std.container : Array, SList;
import dtiled.coords : RowCol, Diagonals;
import dtiled.grid;

/// Same as enclosedTiles, but return coords instead of tiles
auto enclosedCoords(alias isWall, T)(T grid, RowCol origin, Diagonals diags = Diagonals.no)
  if (is(typeof(isWall(grid.tileAt(RowCol(0,0)))) : bool))
{
  // track whether we have hit the edge of the map
  bool hitEdge;

  // keep a flag for each tile to mark which have been visited
  Array!bool visited;
  visited.length = grid.numRows * grid.numCols;

  // visited[] index for a (row,col) pair
  auto coordToIdx(RowCol coord) {
    return coord.row * grid.numCols + coord.col;
  }

  // row/col coord for a visited[] index
  auto idxToCoord(size_t idx) {
    return RowCol(idx / grid.numCols, idx % grid.numCols);
  }

  bool outOfBounds(RowCol coord) {
    return coord.row < 0 || coord.col < 0 || coord.row >= grid.numRows || coord.col >= grid.numCols;
  }

  void flood(RowCol coord) {
    auto idx = coordToIdx(coord);
    hitEdge = hitEdge || outOfBounds(coord);

    // break this recursive branch if we hit an edge or a visited or invalid tile.
    if (hitEdge || visited[idx] || isWall(grid.tileAt(coord))) return;

    visited[idx] = true;

    // recurse into neighboring tiles
    foreach(neighbor ; coord.adjacent(diags)) flood(neighbor);
  }

  // start the flood at the origin tile
  flood(origin);

  return visited[]
    .enumerate                            // pair each bool with an index
    .filter!(pair => pair.value)          // keep only the visited nodes
    .map!(pair => idxToCoord(pair.index)) // grab the tile for each visited node
    .take(hitEdge ? 0 : size_t.max);      // empty range if edge of map was touched
}

/**
 * Find an area of tiles enclosed by 'walls'.
 *
 * Params:
 *  isWall = predicate which returns true if a tile should be considered a 'wall'
 *  grid = grid of tiles to find enclosed area in
 *  origin = tile that may be part of an enclosed region
 *  diags = if yes, an area is not considered enclosed if there is a diagonal opening.
 *
 * Returns: a range of tiles in the enclosure (empty if origin is not part of an enclosed region)
 */
auto enclosedTiles(alias isWall, T)(T grid, RowCol origin, Diagonals diags = Diagonals.no)
  if (is(typeof(isWall(grid.tileAt(RowCol(0,0)))) : bool))
{
  return enclosedCoords!isWall(grid, origin, diags).map!(x => grid.tileAt(x));
}

///
unittest {
  import std.array;
  import std.algorithm : equal;

  // let the 'X's represent 'walls', and the other letters 'open' areas we'd link to identify
  auto tiles = rectGrid([
    // 0    1    2    3    4    5 <-col| row
    [ 'X', 'X', 'X', 'X', 'X', 'X' ], // 0
    [ 'X', 'a', 'a', 'X', 'b', 'X' ], // 1
    [ 'X', 'a', 'a', 'X', 'b', 'X' ], // 2
    [ 'X', 'X', 'X', 'X', 'X', 'X' ], // 3
    [ 'd', 'd', 'd', 'X', 'c', 'X' ], // 4
    [ 'd', 'd', 'd', 'X', 'X', 'c' ], // 5
  ]);

  static bool isWall(char c) { return c == 'X'; }

  // starting on a wall should return an empty result
  assert(tiles.enclosedTiles!isWall(RowCol(0, 0)).empty);

  // all tiles in the [1,1] -> [2,2] area should find the 'a' room
  assert(tiles.enclosedTiles!isWall(RowCol(1, 1)).equal(['a', 'a', 'a', 'a']));
  assert(tiles.enclosedTiles!isWall(RowCol(1, 2)).equal(['a', 'a', 'a', 'a']));
  assert(tiles.enclosedTiles!isWall(RowCol(2, 1)).equal(['a', 'a', 'a', 'a']));
  assert(tiles.enclosedTiles!isWall(RowCol(2, 2)).equal(['a', 'a', 'a', 'a']));

  // get the two-tile 'b' room at [1,4] -> [2,4]
  assert(tiles.enclosedTiles!isWall(RowCol(1, 4)).equal(['b', 'b']));
  assert(tiles.enclosedTiles!isWall(RowCol(2, 4)).equal(['b', 'b']));

  // get the single tile 'c' room at 4,4
  assert(tiles.enclosedTiles!isWall(RowCol(4, 4)).equal(['c']));
  // if we require that diagonals be blocked too, 'c' is not an enclosure
  assert(tiles.enclosedTiles!isWall(RowCol(4, 4), Diagonals.yes).empty);

  // the 'd' region is not an enclosure (touches map edge)
  assert(tiles.enclosedTiles!isWall(RowCol(4, 1)).empty);
  assert(tiles.enclosedTiles!isWall(RowCol(5, 0)).empty);
}

// test for bug with handling up-right diagonal
unittest {
  import std.array;
  import std.algorithm : equal;

  // 'a' is totally enclosed
  auto tiles1 = rectGrid([
    // 0    1    2
    [ 'X', 'X', 'X' ], // 1
    [ 'X', 'a', 'X' ], // 2
    [ 'X', 'X', 'X' ], // 3
  ]);

  // there is an escape diagonally up and right
  auto tiles2 = rectGrid([
    // 0    1    2
    [ 'X', 'X', 'a' ], // 1
    [ 'X', 'a', 'X' ], // 2
    [ 'X', 'X', 'X' ], // 3
  ]);

  static bool isWall(char c) { return c == 'X'; }

  assert(!tiles1.enclosedTiles!isWall(RowCol(1, 1), Diagonals.no).empty);
  assert(!tiles1.enclosedTiles!isWall(RowCol(1, 1), Diagonals.no).empty);

  assert(!tiles1.enclosedTiles!isWall(RowCol(1, 1), Diagonals.yes).empty);
  assert( tiles1.enclosedTiles!isWall(RowCol(1, 1), Diagonals.yes).empty);
}

/// Same as floodTiles, but return coordinates instead of the tiles at those coordinates.
auto floodCoords(alias pred, T)(T grid, RowCol origin, Diagonals diags = Diagonals.no)
  if (is(typeof(pred(grid.tileAt(RowCol(0,0)))) : bool))
{
  struct Result {
    private {
      T            _grid;
      SList!RowCol _stack;
      Array!bool   _visited;

      // helpers to translate between the 2D grid coordinate space and the 1D visited array
      bool getVisited(RowCol coord) {
        auto idx = coord.row * grid.numCols + coord.col;
        return _visited[idx];
      }

      void setVisited(RowCol coord) {
        auto idx = coord.row * grid.numCols + coord.col;
        _visited[idx] = true;
      }

      // true if front is out of bounds, already visited, or does not meet the predicate
      bool shouldSkipFront() {
        return !_grid.contains(front) || getVisited(front) || !pred(_grid.tileAt(front));
      }
    }

    this(T grid, RowCol origin) {
      _grid = grid;
      _visited.length = grid.numRows * grid.numCols; // one visited entry for each tile

      // push the first tile onto the stack only if it meets the predicate
      if (pred(grid.tileAt(origin))) {
        _stack.insertFront(origin);
      }
    }

    @property auto front() { return _stack.front; }
    @property bool empty() { return _stack.empty; }

    void popFront() {
      // copy the current coord before we pop it
      auto coord = front;

      // mark that the current coord was visited and pop it
      setVisited(coord);
      _stack.removeFront();

      // push neighboring coords onto the stack
      foreach(neighbor ; coord.adjacent(diags)) { _stack.insert(neighbor); }

      // keep popping until stack is empty or we get a floodable coord
      while (!_stack.empty && shouldSkipFront()) { _stack.removeFront(); }
    }
  }

  return Result(grid, origin);
}

/**
 * Returns a range that iterates through tiles based on a flood filling algorithm.
 *
 * Params:
 *  pred   = predicate that returns true if the flood should progress through a given tile.
 *  grid   = grid to apply flood to.
 *  origin = coordinate at which to begin flood.
 *  diags  = by default, flood only progresses to directly adjacent tiles.
 *           Diagonals.yes causes the flood to progress across diagonals too.
 */
auto floodTiles(alias pred, T)(T grid, RowCol origin, Diagonals diags = Diagonals.no)
  if (is(typeof(pred(grid.tileAt(RowCol(0,0)))) : bool))
{
  return floodCoords!pred(grid, origin, diags).map!(x => grid.tileAt(x));
}

///
unittest {
  import std.array;
  import std.algorithm : equal;

  // let the 'X's represent 'walls', and the other letters 'open' areas we'd link to identify
  auto grid = rectGrid([
    // 0    1    2    3    4    5 <-col| row
    [ 'X', 'X', 'X', 'X', 'X', 'X' ], // 0
    [ 'X', 'a', 'a', 'X', 'b', 'X' ], // 1
    [ 'X', 'a', 'a', 'X', 'b', 'X' ], // 2
    [ 'X', 'X', 'X', 'X', 'X', 'c' ], // 3
    [ 'd', 'd', 'd', 'X', 'c', 'X' ], // 4
    [ 'd', 'd', 'd', 'X', 'X', 'X' ], // 5
  ]);

  // starting on a wall should return an empty result
  assert(grid.floodTiles!(x => x == 'a')(RowCol(0,0)).empty);
  assert(grid.floodTiles!(x => x == 'a')(RowCol(3,3)).empty);

  // flood the 'a' room
  assert(grid.floodTiles!(x => x == 'a')(RowCol(1,1)).equal(['a', 'a', 'a', 'a']));
  assert(grid.floodTiles!(x => x == 'a')(RowCol(1,2)).equal(['a', 'a', 'a', 'a']));
  assert(grid.floodTiles!(x => x == 'a')(RowCol(2,1)).equal(['a', 'a', 'a', 'a']));
  assert(grid.floodTiles!(x => x == 'a')(RowCol(2,2)).equal(['a', 'a', 'a', 'a']));

  // flood the 'a' room, but asking for a 'b'
  assert(grid.floodTiles!(x => x == 'b')(RowCol(2,2)).empty);

  // flood the 'b' room
  assert(grid.floodTiles!(x => x == 'b')(RowCol(1,4)).equal(['b', 'b']));

  // flood the 'c' room
  assert(grid.floodTiles!(x => x == 'c')(RowCol(4,4)).equal(['c']));

  // flood the 'd' room
  assert(grid.floodTiles!(x => x == 'd')(RowCol(4,1)).equal(['d', 'd', 'd', 'd', 'd', 'd']));

  // flood the 'b' and 'c' rooms, moving through diagonals
  assert(grid.floodTiles!(x => x == 'b' || x == 'c')(RowCol(4,4), Diagonals.yes)
      .equal(['c', 'c', 'b', 'b']));
}
