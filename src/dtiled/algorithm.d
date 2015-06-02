module dtiled.algorithm;

import std.range;
import std.algorithm;
import std.container : Array;
import dtiled.coords : RowCol;
import dtiled.grid;

auto findEnclosure(alias isWall, Tile)(TileGrid!Tile grid, RowCol origin)
  if (is(typeof(isWall(Tile.init)) : bool))
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

  // visited[] index for a (row,col) pair
  auto ref idxToTile(size_t idx) {
    auto coord = RowCol(idx / grid.numCols, idx % grid.numCols);
    return grid.tileAt(coord);
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

    // cardinal directions
    flood(coord.north);
    flood(coord.south);
    flood(coord.west);
    flood(coord.east);

    // diagonals
    flood(coord.north.west);
    flood(coord.north.east);
    flood(coord.south.west);
    flood(coord.south.east);
  }

  // start the flood at the origin tile
  flood(origin);

  return visited[]
    .enumerate                           // pair each bool with an index
    .filter!(pair => pair.value)         // keep only the visited nodes
    .map!(pair => idxToTile(pair.index)) // grab the tile for each visited node
    .take(hitEdge ? 0 : size_t.max);     // empty range if edge of map was touched
}

///
unittest {
  import std.array;
  import std.algorithm : equal;

  // let the 'X's represent 'walls', and the other letters 'open' areas we'd link to identify
  auto tiles = TileGrid!char([
    // 0    1    2    3    4    5 <-col| row
    [ 'X', 'X', 'X', 'X', 'X', 'X' ], // 0
    [ 'X', 'a', 'a', 'X', 'b', 'X' ], // 1
    [ 'X', 'a', 'a', 'X', 'b', 'X' ], // 2
    [ 'X', 'X', 'X', 'X', 'X', 'X' ], // 3
    [ 'd', 'd', 'd', 'X', 'c', 'X' ], // 4
    [ 'd', 'd', 'd', 'X', 'X', 'X' ], // 5
  ]);

  static bool isWall(char c) { return c == 'X'; }

  // starting on a wall should return an empty result
  assert(tiles.findEnclosure!isWall(RowCol(0, 0)).empty);

  // all tiles in the [1,1] -> [2,2] area should find the 'a' room
  assert(tiles.findEnclosure!isWall(RowCol(1, 1)).equal(['a', 'a', 'a', 'a']));
  assert(tiles.findEnclosure!isWall(RowCol(1, 2)).equal(['a', 'a', 'a', 'a']));
  assert(tiles.findEnclosure!isWall(RowCol(2, 1)).equal(['a', 'a', 'a', 'a']));
  assert(tiles.findEnclosure!isWall(RowCol(2, 2)).equal(['a', 'a', 'a', 'a']));

  // get the two-tile 'b' room at [1,4] -> [2,4]
  assert(tiles.findEnclosure!isWall(RowCol(1, 4)).equal(['b', 'b']));
  assert(tiles.findEnclosure!isWall(RowCol(2, 4)).equal(['b', 'b']));

  // get the single tile 'c' room at 4,4
  assert(tiles.findEnclosure!isWall(RowCol(4, 4)).equal(['c']));

  // the 'd' region is not an enclosure (touches map edge)
  assert(tiles.findEnclosure!isWall(RowCol(4, 1)).empty);
  assert(tiles.findEnclosure!isWall(RowCol(5, 0)).empty);
}
