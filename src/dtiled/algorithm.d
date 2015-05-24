module dtiled.algorithm;

import std.range;
import std.algorithm;
import std.container : Array;
import dtiled.coords : RowCol;

auto findEnclosure(alias isWall, Tile)(Tile[][] tiles, RowCol origin)
  if (is(typeof(isWall(Tile.init)) : bool))
{
  auto numRows = tiles.length;
  auto numCols = tiles[0].length;

  // track whether we have hit the edge of the map
  bool hitEdge;

  // keep a flag for each tile to mark which have been visited
  Array!bool visited;
  visited.length = numRows * numCols;

  // visited[] index for a (row,col) pair
  auto coordToIdx(size_t row, size_t col) {
    return row * numCols + col;
  }

  // visited[] index for a (row,col) pair
  auto idxToTile(size_t idx) {
    auto row = idx / numCols;
    auto col = idx % numCols;
    return tiles[row][col];
  }

  bool outOfBounds(size_t row, size_t col) {
    return row < 0 || col < 0 || row >= numRows || col >= numCols;
  }

  void flood(size_t row, size_t col) {
    auto idx = coordToIdx(row, col);
    hitEdge = hitEdge || outOfBounds(row, col);

    // break this recursive branch if we hit an edge or a visited or invalid tile.
    if (hitEdge || visited[idx] || isWall(tiles[row][col])) return;

    visited[idx] = true;

    // cardinal directions
    flood(row - 1 , col    );
    flood(row + 1 , col    );
    flood(row     , col - 1);
    flood(row     , col + 1);

    // diagonals
    flood(row - 1 , col - 1);
    flood(row - 1 , col + 1);
    flood(row + 1 , col - 1);
    flood(row + 1 , col + 1);
  }

  // start the flood at the origin tile
  flood(origin.row, origin.col);

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
  auto tiles = [
    // 0    1    2    3    4    5 <-col| row
    [ 'X', 'X', 'X', 'X', 'X', 'X' ], // 0
    [ 'X', 'a', 'a', 'X', 'b', 'X' ], // 1
    [ 'X', 'a', 'a', 'X', 'b', 'X' ], // 2
    [ 'X', 'X', 'X', 'X', 'X', 'X' ], // 3
    [ 'd', 'd', 'd', 'X', 'c', 'X' ], // 4
    [ 'd', 'd', 'd', 'X', 'X', 'X' ], // 5
  ];

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
