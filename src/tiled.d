/**
  * Read and write data for <a href="mapeditor.org>Tiled</a> maps.
  * Currently only supports JSON format.
  *
  * Authors: <a href="https://github.com/rcorre">rcorre</a>
	* License: <a href="http://opensource.org/licenses/MIT">MIT</a>
	* Copyright: Copyright © 2015, Ryan Roden-Corrent
  */
module tiled;

import std.conv      : to;
import std.file      : exists;
import std.range     : empty, front;
import std.string    : format;
import std.algorithm : find;
import std.exception : enforce;
import jsonizer;

/// Underlying type used to represent Tiles Global IDentifiers
alias TiledGid = uint;

/// Flags set by Tiled in the guid field. Used to indicate mirroring and rotation.
enum TiledFlag : TiledGid {
  none           = 0x00000000, /// Tile is not flipped
  flipDiagonal   = 0x20000000, /// Tile is flipped diagonally
  flipVertical   = 0x40000000, /// Tile is flipped vertically (over x axis)
  flipHorizontal = 0x80000000, /// Tile is flipped horizontally (over y axis)
  all = flipHorizontal | flipVertical | flipDiagonal, /// bitwise `or` of all tile flags.
}

///
unittest {
  // this is the GID for a tile with tileset index 21 that was flipped horizontally
  TiledGid gid = 2147483669;
  // clearing the flip flags yields a gid that should map to a tileset index
  assert((gid & ~TiledFlag.all) == 21);
  // it is flipped horizontally
  assert(gid & TiledFlag.flipHorizontal);
  assert(!(gid & TiledFlag.flipVertical));
  assert(!(gid & TiledFlag.flipDiagonal));
}

/// Top-level Tiled structure - encapsulates all data in the map file.
struct TiledMap {
  mixin JsonizeMe;

  /* Types */
  /// Map orientation.
  enum Orientation {
    orthogonal, /// rectangular orthogonal map
    isometric,  /// diamond-shaped isometric map
    staggered   /// rough rectangular isometric map
  }

  /** The order in which tiles on tile layers are rendered.
    * From the docs:
    * Valid values are right-down (the default), right-up, left-down and left-up.
    * In all cases, the map is drawn row-by-row.
    * (since 0.10, but only supported for orthogonal maps at the moment)
    */
  enum RenderOrder : string {
    rightDown = "right-down", /// left-to-right, top-to-bottom
    rightUp   = "right-up",   /// left-to-right, bottom-to-top
    leftDown  = "left-down",  /// right-to-left, top-to-bottom
    leftUp    = "left-up"     /// right-to-left, bottom-to-top
  }

  /* Data */
  @jsonize(JsonizeOptional.no) {
    int width;               /// Number of tile columns
    int height;              /// Number of tile rows
    int tilewidth;           /// General grid size. Individual tiles sizes may differ.
    int tileheight;          /// ditto
    Orientation orientation; /// Orthogonal, isometric, or staggered
    TiledLayer[] layers;     /// All map layers (tiles and objects)
    TiledTileset[] tilesets; /// All tile sets defined in this map
  }

  @jsonize(JsonizeOptional.yes) {
    string backgroundcolor;    /// Hex-formatted background color (#RRGGBB)
    string renderorder;        /// Rendering direction (orthogonal maps only)
    string[string] properties; /// Key-value property pairs set at the map level
    int nextobjectid;          /// Global counter that increments for each new object
  }

  /* Functions */
  /** Load a Tiled map from a JSON file.
    * Throws if no file is found at that path or if the parsing fails.
    * Params:
    *   path = filesystem path to a JSON map file exported by Tiled
    * Returns: The parsed map data
    */
  static TiledMap load(string path) {
    enforce(path.exists, "No map file found at " ~ path);
    auto map = readJSON!TiledMap(path);

    // Tiled should export Tilesets in order of increasing GID.
    // Double check this in debug mode, as things will break if this invariant doesn't hold.
    debug {
      import std.algorithm : isSorted;
      assert(map.tilesets.isSorted!((a,b) => a.firstgid < b.firstgid),
          "TileSets are not sorted by GID!");
    }

    return map;
  }

  /** Save a Tiled map to a JSON file.
    * Params:
    *   path = file destination; parent directory must already exist
    */
  void save(string path) {
    // Tilemaps must be exported sorted in order of firstgid
    debug {
      import std.algorithm : isSorted;
      assert(tilesets.isSorted!((a,b) => a.firstgid < b.firstgid),
          "TileSets are not sorted by GID!");
    }

    path.writeJSON(this);
  }

  /** Fetch a map layer by its name. No check for layers with duplicate names is performed.
   * Throws if no layer has a matching name (case-sensitive).
   * Params:
   *   name = name of layer to find
   * Returns: Layer matching name
   */
  TiledLayer getLayer(string name) {
    auto r = layers.find!(x => x.name == name);
    enforce(!r.empty, "Could not find layer named %s".format(name));
    return r.front;
  }

  /** Fetch a tileset by its name. No check for layers with duplicate names is performed.
   * Throws if no tileset has a matching name (case-sensitive).
   * Params:
   *   name = name of tileset to find
   * Returns: Tileset matching name
   */
  TiledTileset getTileset(string name) {
    auto r = tilesets.find!(x => x.name == name);
    enforce(!r.empty, "Could not find layer named %s".format(name));
    return r.front;
  }
}

/** A layer of tiles within the map.
 *
 * A Map layer could be one of:
 * Tile Layer: `data` is an array of guids that each map to some tile from a `TiledTileset`
 * Object Group: `objects` is a set of entities that are not necessarily tied to the grid
 * Image Layer: This layer is a static image (e.g. a backdrop)
 */
struct TiledLayer {
  mixin JsonizeMe;

  /// Identifies what kind of information a layer contains.
  enum Type {
    tilelayer,   /// One tileset index for every tile in the layer
    objectgroup, /// One or more `TiledObjects`
    imagelayer   /// TODO: try actually creating one of these
  }

  @jsonize(JsonizeOptional.no) {
    int width;    /// Number of tile columns. Always same as map width in Tiled Qt.
    int height;   /// Number of tile rows. Always same as map height in Tiled Qt.
    string name;  /// Name assigned to this layer
    Type type;    /// Category (tile, object, or image)
    bool visible; /// whether layer is shown or hidden in editor
    int x;        /// Horizontal layer offset. Always 0 in Tiled Qt.
    int y;        /// Vertical layer offset. Always 0 in Tiled Qt.
  }

  // These entries exist only on object layers
  @jsonize(JsonizeOptional.yes) {
    TiledGid[] data;           /// An array of GIDs that identify tiles. Only for `tilelayer`
    TiledObject[] objects;     /// An array of objects. Only on `objectgroup` layers.
    string[string] properties; /// Optional user-defined key-value properties for this layer
    float opacity;             /// Visual opacity of all tiles in this layer
    string draworder;          /// Not documented by tiled, but may appear in JSON.
  }

  @property {
    /// get the row corresponding to a position in the $(D data) or $(D objects) array.
    int idxToRow(int idx) { return idx / width; }

    ///
    unittest {
      TiledLayer layer;
      layer.width = 3;
      layer.height = 2;

      assert(layer.idxToRow(0) == 0);
      assert(layer.idxToRow(1) == 0);
      assert(layer.idxToRow(2) == 0);
      assert(layer.idxToRow(3) == 1);
      assert(layer.idxToRow(4) == 1);
      assert(layer.idxToRow(5) == 1);
    }

    /// get the column corresponding to a position in the $(D data) or $(D objects) array.
    int idxToCol(int idx) { return idx % width; }

    ///
    unittest {
      TiledLayer layer;
      layer.width = 3;
      layer.height = 2;

      assert(layer.idxToCol(0) == 0);
      assert(layer.idxToCol(1) == 1);
      assert(layer.idxToCol(2) == 2);
      assert(layer.idxToCol(3) == 0);
      assert(layer.idxToCol(4) == 1);
      assert(layer.idxToCol(5) == 2);
    }
  }
}

/** Represents an entity in an object layer.
 *
 * Objects are not necessarily grid-aligned, but rather have a position specified in pixel coords.
 * Each object instance can have a `name`, `type`, and set of `properties` defined in the editor.
 */
struct TiledObject {
  mixin JsonizeMe;
  @jsonize(JsonizeOptional.no) {
    int id;                    /// Incremental id - unique across all objects
    int width;                 /// Width in pixels. Ignored if using a gid.
    int height;                /// Height in pixels. Ignored if using a gid.
    string name;               /// Name assigned to this object instance
    string type;               /// User-defined string 'type' assigned to this object instance
    string[string] properties; /// Optional properties defined on this instance
    bool visible;              /// Whether object is shown.
    int x;                     /// x coordinate in pixels
    int y;                     /// y coordinate in pixels
    float rotation;            /// Angle in degrees clockwise
  }

  @jsonize(JsonizeOptional.yes) {
    TiledGid gid; /// Identifies a tile in a tileset if this object is represented by a tile
  }
}

/**
 * A `TiledTileset` maps GIDs (Global IDentifiers) to tiles.
 *
 * Each tileset has a range of GIDs that map to the tiles it contains.
 * This range starts at `firstgid` and extends to the `firstgid` of the next tileset.
 * The index of a tile within a tileset is given by tile.gid - tileset.firstgid.
 * A tileset uses its `image` as a 'tile atlas' and may specify per-tile `properties`.
 */
struct TiledTileset {
  mixin JsonizeMe;
  @jsonize(JsonizeOptional.no) {
    TiledGid firstgid;         /// The GID that maps to the first tile in this set
    string image;              /// Image used for tiles in this set
    string name;               /// Name given to this tileset
    int tilewidth;             /// Maximum width of tiles in this set
    int tileheight;            /// Maximum height of tiles in this set
    int imagewidth;            /// Width of source image in pixels
    int imageheight;           /// Height of source image in pixels
    string[string] properties; /// Properties assigned to this tileset
    int margin;                /// Buffer between image edge and tiles (in pixels)
    int spacing;               /// Spacing between tiles in image (in pixels)
  }

  @jsonize(JsonizeOptional.yes) {
    /** Optional per-tile properties, indexed by the GID as a string.
     *
     * For example, if the tile with GID 25 has the property "moveCost=4", then
     * `tileproperties["25"]["moveCost"] == "4"
     * A tile with no special properties will not have an index here.
     * If no tiles have special properties, this field is not populated at all.
     */
    string[string][string] tileproperties;
  }

  @property {
    /// Number of tile rows in the tileset
    int numRows()  { return (imageheight - margin * 2) / (tileheight + spacing); }

    /// Number of tile rows in the tileset
    int numCols()  { return (imagewidth - margin * 2) / (tilewidth + spacing); }

    /// Total number of tiles defined in the tileset
    int numTiles() { return numRows * numCols; }
  }

  /**
   * Find the grid position of a tile within this tileset.
   *
   * Throws if $(D gid) is out of range for this tileset.
   * Params:
   *  gid = GID of tile. Does not need to be cleaned of flags.
   * Returns: 0-indexed row of tile
   */
  int tileRow(TiledGid gid) {
    return getIdx(gid) / numCols;
  }

  /**
   * Find the grid position of a tile within this tileset.
   *
   * Throws if $(D gid) is out of range for this tileset.
   * Params:
   *  gid = GID of tile. Does not need to be cleaned of flags.
   * Returns: 0-indexed column of tile
   */
  int tileCol(TiledGid gid) {
    return getIdx(gid) % numCols;
  }

  /**
   * Find the pixel position of a tile within this tileset.
   *
   * Throws if $(D gid) is out of range for this tileset.
   * Params:
   *  gid = GID of tile. Does not need to be cleaned of flags.
   * Returns: space between left side of image and left side of tile (pixels)
   */
  int tileOffsetX(TiledGid gid) {
    return margin + tileCol(gid) * (tilewidth + spacing);
  }

  /**
   * Find the pixel position of a tile within this tileset.
   *
   * Throws if $(D gid) is out of range for this tileset.
   * Params:
   *  gid = GID of tile. Does not need to be cleaned of flags.
   * Returns: space between top side of image and top side of tile (pixels)
   */
  int tileOffsetY(TiledGid gid) {
    return margin + tileRow(gid) * (tileheight + spacing);
  }

  /**
   * Find the properties defined for a tile in this tileset.
   *
   * Throws if $(D gid) is out of range for this tileset.
   * Params:
   *  gid = GID of tile. Does not need to be cleaned of flags.
   * Returns: AA of key-value property pairs, or $(D null) if no properties defined for this tile.
   */
  string[string] tileProperties(TiledGid gid) {
    auto res = gid.to!string in tileproperties;
    return res ? *res : null;
  }

  // clean the gid, adjust it to an index within this tileset, and throw if out of range
  private auto getIdx(TiledGid gid) {
    gid = gid.cleanGid;
    auto idx = gid - firstgid;

    enforce(idx >= 0 && idx < numTiles,
      "GID %d out of range [%d,%d] for tileset %s"
      .format( gid, firstgid, firstgid + numTiles - 1, name));

    return idx;
  }
}

unittest {
  // 3 rows, 3 columns
  TiledTileset tileset;
  tileset.firstgid = 4;
  tileset.tilewidth = tileset.tileheight = 32;
  tileset.imagewidth = tileset.imageheight = 96;
  tileset.tileproperties = [ "6": ["a": "b"], "7": ["c": "d"] ];

  void test(TiledGid gid, int row, int col, int x, int y, string[string] props) {
    assert(tileset.tileRow(gid) == row         , "row mismatch   gid=%d".format(gid));
    assert(tileset.tileCol(gid) == col         , "col mismatch   gid=%d".format(gid));
    assert(tileset.tileOffsetX(gid) == x       , "x   mismatch   gid=%d".format(gid));
    assert(tileset.tileOffsetY(gid) == y       , "y   mismatch   gid=%d".format(gid));
    assert(tileset.tileProperties(gid) == props, "props mismatch gid=%d".format(gid));
  }

  //   gid , row , col , x  , y  , props
  test(4   , 0   , 0   , 0  , 0  , null);
  test(5   , 0   , 1   , 32 , 0  , null);
  test(6   , 0   , 2   , 64 , 0  , ["a": "b"]);
  test(7   , 1   , 0   , 0  , 32 , ["c": "d"]);
  test(8   , 1   , 1   , 32 , 32 , null);
  test(9   , 1   , 2   , 64 , 32 , null);
  test(10  , 2   , 0   , 0  , 64 , null);
  test(11  , 2   , 1   , 32 , 64 , null);
  test(12  , 2   , 2   , 64 , 64 , null);
}

private:
// get the ID portion of a GID
TiledGid cleanGid(TiledGid gid) {
  return gid & ~TiledFlag.all;
}

// get the flags portion of a GID
TiledFlag getFlags(TiledGid gid) {
  return cast(TiledFlag) (gid & TiledFlag.all);
}
