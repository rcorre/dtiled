/**
 * This module models various representations of space in a map.
 *
 * Map coordinates can either refer to a 'grid' or 'pixel' position.
 *
 * A 'grid' position refers to a (row,column) pair that is independent of tile size.
 * Within dtiled, grid locations are represented by a GridCoord.
 * You can use your own coordinate representation that fufills isGridCoord.
 *
 * A 'pixel' position refers to an (x,y) location in 'pixel' space.
 * Pixel coordinates refer to the same tilewidth and tileheight fields in MapData.
 * Within dtiled, pixel locations are represented by a PixelCoord.
 * As you may be using a game library that provides some 'Vector' implementation used to
 * represent positions, you can use that as long as it satisfies isPixelCoord.
 */
module dtiled.spatial;

import std.typecons : Tuple;

/// Represents a location in continuous 2D space.
alias PixelCoord = Tuple!(float, "x", float, "y");

/// Represents a discrete location within the map grid.
alias GridCoord  = Tuple!(long, "row", long, "col");

/// True if T is a type that can represent a location in terms of pixels.
enum isPixelCoord(T) = is(typeof(T.x) : real) &&
                       is(typeof(T.y) : real);

///
unittest {
  struct MyVector(T) { T x, y; }

  static assert(isPixelCoord!(MyVector!int));
  static assert(isPixelCoord!(MyVector!uint));
  static assert(isPixelCoord!(MyVector!float));
  static assert(isPixelCoord!(MyVector!double));
  static assert(isPixelCoord!(MyVector!real));

  struct MyCoord(T)  { T row, col; }

  static assert(!isPixelCoord!(MyCoord!int));
  static assert(!isPixelCoord!(MyCoord!uint));
  static assert(!isPixelCoord!(MyCoord!float));
  static assert(!isPixelCoord!(MyCoord!double));
  static assert(!isPixelCoord!(MyCoord!real));
}

/// True if T is a type that can represent a location within a map grid.
enum isGridCoord(T) = is(typeof(T.row) : long) &&
                      is(typeof(T.col) : long);

///
unittest {
  struct MyCoord(T)  { T row, col; }

  // A grid coord must have an integral row and column
  static assert(isGridCoord!(MyCoord!int));
  static assert(isGridCoord!(MyCoord!uint));
  static assert(isGridCoord!(MyCoord!ulong));

  // A grid coord cannot have a floating-point representation
  static assert(!isGridCoord!(MyCoord!float));
  static assert(!isGridCoord!(MyCoord!double));
  static assert(!isGridCoord!(MyCoord!real));

  struct MyVector(T) { T x, y; }

  // A grid coord must use row/col, not x/y
  static assert(!isGridCoord!(MyVector!int));
  static assert(!isGridCoord!(MyVector!uint));
}
