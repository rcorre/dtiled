/**
  * Read and write data for <a href="mapeditor.org">Tiled</a> maps.
  * Currently only supports JSON format.
  *
  * Authors: <a href="https://github.com/rcorre">rcorre</a>
	* License: <a href="http://opensource.org/licenses/MIT">MIT</a>
	* Copyright: Copyright © 2015, Ryan Roden-Corrent
  */
module dtiled.data;

import std.conv      : to;
import std.file      : exists;
import std.range     : empty, front, retro;
import std.string    : format;
import std.algorithm : find;
import std.exception : enforce;
import jsonizer;

/**
 * Underlying type used to represent Tiles Global IDentifiers.
 * Note that a GID of 0 is used to indicate the abscence of a tile.
 */
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
struct MapData {
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
    @jsonize("width")      int numCols;    /// Number of tile columns
    @jsonize("height")     int numRows;    /// Number of tile rows
    @jsonize("tilewidth")  int tileWidth;  /// General grid size. Individual tiles sizes may differ.
    @jsonize("tileheight") int tileHeight; /// ditto
    Orientation orientation;               /// Orthogonal, isometric, or staggered
    LayerData[] layers;                    /// All map layers (tiles and objects)
    TilesetData[] tilesets;                /// All tile sets defined in this map
  }

  @jsonize(JsonizeOptional.yes) {
    @jsonize("backgroundcolor") string backgroundColor; /// Hex-formatted background color (#RRGGBB)
    @jsonize("renderorder")     string renderOrder;     /// Rendering direction (orthogonal only)
    @jsonize("nextobjectid")    int    nextObjectId;    /// Global counter across all objects
    string[string] properties;                          /// Key-value property pairs on map
  }

  /* Functions */
  /** Load a Tiled map from a JSON file.
    * Throws if no file is found at that path or if the parsing fails.
    * Params:
    *   path = filesystem path to a JSON map file exported by Tiled
    * Returns: The parsed map data
    */
  static auto load(string path) {
    enforce(path.exists, "No map file found at " ~ path);
    auto map = readJSON!MapData(path);

    // Tiled should export Tilesets in order of increasing GID.
    // Double check this in debug mode, as things will break if this invariant doesn't hold.
    debug {
      import std.algorithm : isSorted;
      assert(map.tilesets.isSorted!((a,b) => a.firstGid < b.firstGid),
          "TileSets are not sorted by GID!");
    }

    return map;
  }

  /** Save a Tiled map to a JSON file.
    * Params:
    *   path = file destination; parent directory must already exist
    */
  void save(string path) {
    // Tilemaps must be exported sorted in order of firstGid
    debug {
      import std.algorithm : isSorted;
      assert(tilesets.isSorted!((a,b) => a.firstGid < b.firstGid),
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
  auto getLayer(string name) {
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
  auto getTileset(string name) {
    auto r = tilesets.find!(x => x.name == name);
    enforce(!r.empty, "Could not find layer named %s".format(name));
    return r.front;
  }

  /** Fetch the tileset containing the tile a given GID.
   * Throws if the gid is out of range for all tilesets
   * Params:
   *   gid = gid of tile to find tileset for
   * Returns: Tileset containing the given gid
   */
  auto getTileset(TiledGid gid) {
    gid = gid.cleanGid;
    // search in reverse order, want the highest firstGid <= the given gid
    auto r = tilesets.retro.find!(x => x.firstGid <= gid);
    enforce(!r.empty, "GID %d is out of range for all tilesets".format(gid));
    return r.front;
  }

  ///
  unittest {
    MapData map;
    map.tilesets ~= TilesetData();
    map.tilesets[0].firstGid = 1;
    map.tilesets ~= TilesetData();
    map.tilesets[1].firstGid = 5;
    map.tilesets ~= TilesetData();
    map.tilesets[2].firstGid = 12;

    assert(map.getTileset(1) == map.tilesets[0]);
    assert(map.getTileset(3) == map.tilesets[0]);
    assert(map.getTileset(5) == map.tilesets[1]);
    assert(map.getTileset(9) == map.tilesets[1]);
    assert(map.getTileset(15) == map.tilesets[2]);
  }
}

/** A layer of tiles within the map.
 *
 * A Map layer could be one of:
 * Tile Layer: data is an array of guids that each map to some tile from a TilesetData
 * Object Group: objects is a set of entities that are not necessarily tied to the grid
 * Image Layer: This layer is a static image (e.g. a backdrop)
 */
struct LayerData {
  mixin JsonizeMe;

  /// Identifies what kind of information a layer contains.
  enum Type {
    tilelayer,   /// One tileset index for every tile in the layer
    objectgroup, /// One or more ObjectData
    imagelayer   /// TODO: try actually creating one of these
  }

  @jsonize(JsonizeOptional.no) {
    @jsonize("width")  int numCols; /// Number of tile columns. Identical to map width in Tiled Qt.
    @jsonize("height") int numRows; /// Number of tile rows. Identical to map height in Tiled Qt.
    string name;                    /// Name assigned to this layer
    Type type;                      /// Category (tile, object, or image)
    bool visible;                   /// whether layer is shown or hidden in editor
    int x;                          /// Horizontal layer offset. Always 0 in Tiled Qt.
    int y;                          /// Vertical layer offset. Always 0 in Tiled Qt.
  }

  // These entries exist only on object layers
  @jsonize(JsonizeOptional.yes) {
    TiledGid[] data;                        /// An array of tile GIDs. Only for `tilelayer`
    ObjectData[] objects;                   /// An array of objects. Only on `objectgroup` layers.
    string[string] properties;              /// Optional key-value properties for this layer
    float opacity;                          /// Visual opacity of all tiles in this layer
    @jsonize("draworder") string drawOrder; /// Not documented by tiled, but may appear in JSON.
  }

  @property {
    /// get the row corresponding to a position in the $(D data) or $(D objects) array.
    auto idxToRow(size_t idx) { return idx / numCols; }

    ///
    unittest {
      LayerData layer;
      layer.numCols = 3;
      layer.numRows = 2;

      assert(layer.idxToRow(0) == 0);
      assert(layer.idxToRow(1) == 0);
      assert(layer.idxToRow(2) == 0);
      assert(layer.idxToRow(3) == 1);
      assert(layer.idxToRow(4) == 1);
      assert(layer.idxToRow(5) == 1);
    }

    /// get the column corresponding to a position in the $(D data) or $(D objects) array.
    auto idxToCol(size_t idx) { return idx % numCols; }

    ///
    unittest {
      LayerData layer;
      layer.numCols = 3;
      layer.numRows = 2;

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
struct ObjectData {
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
 * A TilesetData maps GIDs (Global IDentifiers) to tiles.
 *
 * Each tileset has a range of GIDs that map to the tiles it contains.
 * This range starts at `firstGid` and extends to the `firstGid` of the next tileset.
 * The index of a tile within a tileset is given by tile.gid - tileset.firstGid.
 * A tileset uses its `image` as a 'tile atlas' and may specify per-tile `properties`.
 */
struct TilesetData {
  mixin JsonizeMe;
  @jsonize(JsonizeOptional.no) {
    string name;                               /// Name given to this tileset
    string image;                              /// Image used for tiles in this set
    int margin;                                /// Buffer between image edge and tiles (in pixels)
    int spacing;                               /// Spacing between tiles in image (in pixels)
    string[string] properties;                 /// Properties assigned to this tileset
    @jsonize("firstgid")    TiledGid firstGid; /// The GID that maps to the first tile in this set
    @jsonize("tilewidth")   int tileWidth;     /// Maximum width of tiles in this set
    @jsonize("tileheight")  int tileHeight;    /// Maximum height of tiles in this set
    @jsonize("imagewidth")  int imageWidth;    /// Width of source image in pixels
    @jsonize("imageheight") int imageHeight;   /// Height of source image in pixels
  }

  @jsonize(JsonizeOptional.yes) {
    /** Optional per-tile properties, indexed by the relative ID as a string.
     *
     * $(RED Note:) The ID is $(B not) the same as the GID. The ID is calculated relative to the
     * firstgid of the tileset the tile belongs to.
     * For example, if a tile has GID 25 and belongs to the tileset with firstgid = 10, then its
     * properties are given by $(D tileset.tileproperties["15"]).
     *
     * A tile with no special properties will not have an index here.
     * If no tiles have special properties, this field is not populated at all.
     */
    string[string][string] tileproperties;
  }

  @property {
    /// Number of tile rows in the tileset
    int numRows()  { return (imageHeight - margin * 2) / (tileHeight + spacing); }

    /// Number of tile rows in the tileset
    int numCols()  { return (imageWidth - margin * 2) / (tileWidth + spacing); }

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
    return margin + tileCol(gid) * (tileWidth + spacing);
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
    return margin + tileRow(gid) * (tileHeight + spacing);
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
    auto id = cleanGid(gid) - firstGid; // indexed by relative ID, not GID
    auto res = id.to!string in tileproperties;
    return res ? *res : null;
  }

  // clean the gid, adjust it to an index within this tileset, and throw if out of range
  private auto getIdx(TiledGid gid) {
    gid = gid.cleanGid;
    auto idx = gid - firstGid;

    enforce(idx >= 0 && idx < numTiles,
      "GID %d out of range [%d,%d] for tileset %s"
      .format( gid, firstGid, firstGid + numTiles - 1, name));

    return idx;
  }
}

unittest {
  // 3 rows, 3 columns
  TilesetData tileset;
  tileset.firstGid = 4;
  tileset.tileWidth = tileset.tileHeight = 32;
  tileset.imageWidth = tileset.imageHeight = 96;
  tileset.tileproperties = [ "2": ["a": "b"], "3": ["c": "d"] ];

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

/**
 * Clear the TiledFlag portion of a GID, leaving just the tile id.
 * Params:
 *   gid = GID to clean
 * Returns: A GID with the flag bits zeroed out
 */
TiledGid cleanGid(TiledGid gid) {
  return gid & ~TiledFlag.all;
}

///
unittest {
  // normal tile, no flags
  TiledGid gid = 0x00000002;
  assert(gid.cleanGid == gid);

  // normal tile, no flags
  gid = 0x80000002; // tile with id 2 flipped horizontally
  assert(gid.cleanGid == 0x2);
  assert(gid & TiledFlag.flipHorizontal);
}
