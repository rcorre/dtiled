/**
 * Provides various useful operations on a tile grid.
 */
module dtiled.algorithm;

import std.range;
import std.typecons : Tuple;
import std.algorithm;
import std.container : Array, SList, RedBlackTree;
import dtiled.coords;
import dtiled.grid;

/// Same as enclosedTiles, but return coords instead of tiles
auto enclosedCoords(alias isWall, T)(T grid, RowCol origin, Diagonals diags = Diagonals.no)
  if (is(typeof(isWall(grid.tileAt(RowCol(0,0)))) : bool))
{
  // track whether we have hit the edge of the map
  bool hitEdge;

  // keep a flag for each tile to mark which have been visited
  auto visited = CoordMap!bool(grid.numRows, grid.numCols);

  bool outOfBounds(RowCol coord) {
    return coord.row < 0 || coord.col < 0 || coord.row >= grid.numRows || coord.col >= grid.numCols;
  }

  void flood(RowCol coord) {
    hitEdge = hitEdge || outOfBounds(coord);

    // break this recursive branch if we hit an edge or a visited or invalid tile.
    if (hitEdge || visited[coord] || isWall(grid.tileAt(coord))) return;

    visited[coord] = true;

    // recurse into neighboring tiles
    foreach(neighbor ; coord.adjacent(diags)) flood(neighbor);
  }

  // start the flood at the origin tile
  flood(origin);

  return visited
    .byKeyValue                      // pair each bool with an index
    .filter!(pair => pair.value)     // keep only the visited nodes
    .map!(pair => pair.coord)        // grab the coord for each visited node
    .take(hitEdge ? 0 : size_t.max); // empty range if edge of map was touched
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

/// Same as floodTiles, but return coordinates instead of the tiles at those coordinates.
auto floodCoords(alias pred, T)(T grid, RowCol origin, Diagonals diags = Diagonals.no)
  if (is(typeof(pred(grid.tileAt(RowCol(0,0)))) : bool))
{
  struct Result {
    private {
      T             _grid;
      SList!RowCol  _stack;
      CoordMap!bool _visited;

      // true if front is out of bounds, already visited, or does not meet the predicate
      bool shouldSkipFront() {
        return !_grid.contains(front) || _visited[front] || !pred(_grid.tileAt(front));
      }
    }

    this(T grid, RowCol origin) {
      _grid = grid;
      _visited = CoordMap!bool(grid.numRows, grid.numCols);

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
      _visited[coord] = true;
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

/**
 * Get the shortest path between two coordinates.
 *
 * Params:
 *  cost = function that returns the cost to move onto a tile.
 *         To represent an 'impassable' tile, cost should return a large value.
 *         Do $(RED NOT) let cost return a value large enough to overflow when added to another.
 *         For example, if cost returns an int, the return value should be less than `int.max / 2`.
 *  T = type of the grid
 *  grid = grid of tiles to find path on
 *  start = tile to start pathfinding from
 *  end = the 'goal' the pathfinder should reach
 *
 *  Returns: the shortest path as a range of tiles, including `end` but not including `start`.
 *           returns an empty range if no path could be found or if `start` == `end`.
 */
auto shortestPath(alias cost, T)(T grid, RowCol start, RowCol end)
  if (is(typeof(cost(grid.tileAt(RowCol.init))) : real))
{
  // A* implementation:

  // type returned by the cost function
  alias Cost = typeof(cost(grid.tileAt(RowCol.init)));

  // constant used to indicate that a node's parent has not been set
  enum noParent = RowCol(-1, -1);

  // pair a coord with its current fscore for sorted insertion into the 'open' set.
  struct OpenEntry {
    RowCol coord;
    int fscore;
  }

  // a 'Node' stores all information this algorithm needs for a particular coord.
  struct Node {
    bool open;                // an 'open' node is a candidate for exploration
    bool closed;              // a 'closed' node should not be explored again
    Cost gscore;              // the known cost from 'start' to a given tile
    Cost fscore;              // the 'g' score of this coord plus its estimated cost to the goal.
    RowCol parent = noParent; // the coord of its parent
  }
  auto nodes = CoordMap!Node(grid.numRows, grid.numCols);

  // 'open' tiles are candidates for exploration; the lowest f-score is the most viable.
  auto open = new RedBlackTree!(OpenEntry, (a,b) => a.fscore < b.fscore, true);

  // the open set starts with only the current tile
  open.insert(OpenEntry(start, 0));

  // loop until we reach the goal or run out of tiles to explore
  while (!open.empty) {
    // get the current most optimal tile and move it from the open to the closed set
    auto current = open.front.coord;
    open.removeFront();
    nodes[current].closed = true;

    // if current is the destination, reconstruct the path by following the 'parent' graph
    if (current == end) {
      SList!RowCol path;

      while (nodes[current].parent != noParent) {
        path.insertFront(current);
        current = nodes[current].parent;
      }

      return path;
    }

    // current is not the destination, explore its neighbors
    foreach(neighbor ; current.adjacent) {
      // ignore this coord if it is out of bounds or already in the closed set
      if (!grid.contains(neighbor) || nodes[neighbor].closed) continue;

      // tentative score is the score of the current tile plus the cost to the neighbor
      auto estimate = nodes[neighbor].gscore + cost(grid.tileAt(neighbor));

      // only insert into the open set if it is not already there
      bool wasOpen = nodes[neighbor].open;
      if (!wasOpen) {
        nodes[neighbor].open = true;
        open.insert(OpenEntry(neighbor, estimate));
      }

      // compute costs if it is a new tile or if we have found a shorter route to this tile
      if (!wasOpen || estimate < nodes[neighbor].gscore) {
        nodes[neighbor].parent = current;
        nodes[neighbor].gscore = estimate;
        nodes[neighbor].fscore = estimate + cast(Cost) manhattan(neighbor, end);
      }
    }
  }

  return SList!RowCol(); // no path found, return empty path
}

unittest {
  import std.algorithm : equal;

  // let the 'X's represent 'walls', we want a path from a to b
  auto grid = rectGrid([
    // 0    1    2    3    4    5 <-col| row
    [ 'X', 'X', 'X', 'X', 'X', 'X' ], // 0
    [ 'X', ' ', 'b', 'X', 'b', 'X' ], // 1
    [ 'X', ' ', 'b', 'X', ' ', 'X' ], // 2
    [ 'X', ' ', 'X', 'X', ' ', ' ' ], // 3
    [ ' ', 'a', ' ', ' ', ' ', 'X' ], // 4
    [ ' ', ' ', ' ', 'X', 'X', 'X' ], // 5
  ]);

  // our cost function returns 1 for an empty tile and 99 for a wall (an 'X')
  auto path = shortestPath!(x => x == 'X' ? 99 : 1)(grid, RowCol(4,1), RowCol(1,4));
  assert(!path.empty, "failed to find path when one existed");

  // path should include the end but not the start
  assert(path[].equal([RowCol(4,2), RowCol(4,3), RowCol(4,4), RowCol(3,4), RowCol(2,4), RowCol(1,4)]));
}

private:
// helper that maps a 'RowCol' to a value of type T
struct CoordMap(T) {
  Array!T store;
  size_t numRows, numCols;

  this(size_t numRows, size_t numCols) {
    this.numRows = numRows;
    this.numCols = numCols;
    store.length = numRows * numCols;
  }

  ref auto opIndex(RowCol coord) {
    assert(coord.row >= 0 && coord.col >= 0 && coord.row < numRows && coord.col < numCols);
    return store[coord.row * numCols + coord.col];
  }

  void opIndexAssign(T val, RowCol coord) {
    assert(coord.row >= 0 && coord.col >= 0 && coord.row < numRows && coord.col < numCols);
    store[coord.row * numCols + coord.col] = val;
  }

  auto byKeyValue() {
    struct Result {
      private alias Pair = Tuple!(RowCol, "coord", T, "value");
      private CoordMap!T  _map;
      private RowColRange _span;

      auto front() { return Pair(_span.front, _map[_span.front]); }
      auto empty() { return _span.empty; }
      void popFront() { _span.popFront; }
    }

    return Result(this, RowCol(0,0).span(numRows, numCols));
  }
}
