/**
 * This module helps handle coordinate systems within a map.
 *
 * When dealing with a grid, do you ever forget whether the row or column is the first index?
 * Me too.
 * For this reason, all functions dealing with grid coordinates take a RowCol argument.
 * This makes it abundantly clear that the map is indexed in row-major order.
 * Furthormore, it prevents confusion between **grid** coordinates and **pixel** coordinates.
 *
 * A 'pixel' coordinate refers to an (x,y) location in 'pixel' space.
 * The units used by 'pixel' coords are the same as used in MapData tilewidth and tileheight.
 *
 * Within dtiled, pixel locations are represented by a PixelCoord.
 * However, you may already be using a game library that provides some 'Vector' implementation
 * used to represent positions.
 * You can pass any such type to dtiled functions expecting a pixel coordinate so long as it
 * satisfies isPixelCoord.
 */
module dtiled.coords;

import std.conv     : to;
import std.math     : abs;
import std.format   : format;
import std.typecons : Tuple;

/// Represents a discrete location within the map grid.
struct RowCol {
  long row, col;

  /// Construct a row column pair
  this(long row, long col) {
    this.row = row;
    this.col = col;
  }

  /// Get a string representation of the coordinate, useful for debugging
  @property string toString() {
    return "<row: %d, col: %d".format(row, col);
  }

  /// Add or subtract one coordinate from another
  RowCol opBinary(string op)(RowCol rhs) if (op == "+" || op == "-") {
    return mixin(q{RowCol(this.row %s rhs.row, this.col %s rhs.col)}.format(op, op));
  }

  unittest {
    assert(RowCol(1, 2) + RowCol(4, 1) == RowCol(5, 3));
    assert(RowCol(4, 2) - RowCol(6, 1) == RowCol(-2, 1));
  }
}

/// Represents a location in continuous 2D space.
alias PixelCoord = Tuple!(float, "x", float, "y");

/// True if T is a type that can represent a location in terms of pixels.
enum isPixelCoord(T) = is(typeof(T.x) : real) &&
                       is(typeof(T.y) : real) &&
                       is(T == struct); // must be a struct/tuple

///
unittest {
  // PixelCoord is dtiled's vector representation within pixel coordinate space.
  static assert(isPixelCoord!PixelCoord);

  // as a user, you may choose any (x,y) numeric pair to use as a pixel coordinate
  struct MyVector(T) { T x, y; }

  static assert(isPixelCoord!(MyVector!int));
  static assert(isPixelCoord!(MyVector!uint));
  static assert(isPixelCoord!(MyVector!float));
  static assert(isPixelCoord!(MyVector!double));
  static assert(isPixelCoord!(MyVector!real));

  // To avoid confusion, grid coordinates are distinct from pixel coordinates
  static assert(!isPixelCoord!RowCol);
}

/// Convert a PixelCoord to a user-defined (x,y) numeric pair.
T as(T)(PixelCoord pos) if (isPixelCoord!T) {
  T t;
  t.x = pos.x.to!(typeof(t.x));
  t.y = pos.y.to!(typeof(t.y));
  return t;
}

/// Convert dtiled's pixel-space coordinates to your own types:
unittest {
  // your own representation may be a struct
  struct MyVector(T) { T x, y; }

  assert(PixelCoord(5, 10).as!(MyVector!double) == MyVector!double(5, 10));
  assert(PixelCoord(5.5, 10.2).as!(MyVector!int) == MyVector!int(5, 10));

  // or it may be a tuple
  alias MyPoint(T) = Tuple!(T, "x", T, "y");

  assert(PixelCoord(5, 10).as!(MyPoint!double) == MyPoint!double(5, 10));
  assert(PixelCoord(5.5, 10.2).as!(MyPoint!int) == MyPoint!int(5, 10));

  // std.conv.to is used internally, so it should detect overflow
  import std.conv : ConvOverflowException;
  import std.exception : assertThrown;
  assertThrown!ConvOverflowException(PixelCoord(-1, -1).as!(MyVector!ulong));
}

/**
 * Return the manhattan distance between two tile coordinates.
 * For two coordinates a and b, this is defined as abs(a.row - b.row) + abs(a.col - b.col)
 */
auto manhattan(RowCol a, RowCol b) {
  return abs(a.row - b.row) + abs(a.col - b.col);
}

unittest {
  assert(manhattan(RowCol(0,0), RowCol(2,2))     == 4);
  assert(manhattan(RowCol(2,2), RowCol(2,2))     == 0);
  assert(manhattan(RowCol(-2,-2), RowCol(-2,-2)) == 0);
  assert(manhattan(RowCol(4,-2), RowCol(2,2))    == 6);
  assert(manhattan(RowCol(4,-2), RowCol(-2,-2))  == 6);
}
