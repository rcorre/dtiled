/**
 * This module models various representations of space in a map.
 *
 * Map coordinates can either refer to a 'grid' or 'pixel' position.
 *
 * A RowCol refers to a (row,column) pair that is independent of tile size.
 * It is named as such specifically to avoid confusion; the order is Row, then Column
 *
 * A 'pixel' position refers to an (x,y) location in 'pixel' space.
 * Pixel coordinates refer to the same tilewidth and tileheight fields in MapData.
 *
 * Within dtiled, pixel locations are represented by a PixelCoord.
 * However, you may already be using a game library that provides some 'Vector' implementation
 * used to represent positions.
 * You can pass any such type to dtiled functions expecting a pixel coordinate so long as it
 * satisfies isPixelCoord.
 */
module dtiled.spatial;

import std.typecons : Tuple;

/// Represents a location in continuous 2D space.
alias PixelCoord = Tuple!(float, "x", float, "y");

/// Represents a discrete location within the map grid.
alias RowCol = Tuple!(long, "row", long, "col");

/// True if T is a type that can represent a location in terms of pixels.
enum isPixelCoord(T) = is(typeof(T.x) : real) &&
                       is(typeof(T.y) : real);

///
unittest {
  // any (x,y) numeric pair can be used as a pixel coordinate
  struct MyVector(T) { T x, y; }

  static assert(isPixelCoord!(MyVector!int));
  static assert(isPixelCoord!(MyVector!uint));
  static assert(isPixelCoord!(MyVector!float));
  static assert(isPixelCoord!(MyVector!double));
  static assert(isPixelCoord!(MyVector!real));

  // To avoid confusion, grid coordinates are distinct from pixel coordinates
  static assert(!isPixelCoord!RowCol);
}
