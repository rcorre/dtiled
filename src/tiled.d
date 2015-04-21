/**
  * Enables marking user-defined types for JSON serialization.
  *
  * Authors: <a href="https://github.com/rcorre">rcorre</a>
	* License: <a href="http://opensource.org/licenses/MIT">MIT</a>
	* Copyright: Copyright © 2015, Ryan Roden-Corrent
  */
module tiled;

import std.file;
import std.path;
import std.conv;
import std.range;
import std.algorithm;
import std.exception : enforce;
import jsonizer;

/// Flags set by Tiled in the guid field. Used to indicate mirroring and rotation.
enum TileFlag {
  flipHorizontal = 0x80000000,
  flipVertical   = 0x40000000,
  flipDiagonal   = 0x20000000,
  all            = flipHorizontal | flipVertical | flipDiagonal,
}

/// Top-level Tiled structure - encapsulates all data in the map file.
class TiledMap {
  mixin JsonizeMe;

  /// Map orientation.
  enum Orientation {
    orthogonal,
    isometric,
    staggered
  }

  /** The order in which tiles on tile layers are rendered.
    * From the docs:
    * Valid values are right-down (the default), right-up, left-down and left-up.
    * In all cases, the map is drawn row-by-row.
    * (since 0.10, but only supported for orthogonal maps at the moment)
    */
  enum RenderOrder : string {
    rightDown = "right-down",
    rightUp   = "right-up",
    leftDown  = "left-down",
    leftUp    = "left-up"
  }

  @jsonize(JsonizeOptional.no) {
    int width;               /// Number of tile columns
    int height;              /// Number of tile rows
    int tilewidth;           /// General grid size. Individual tiles sizes may differ.
    int tileheight;          /// ditto
    Orientation orientation; /// Orthogonal, isometric, or staggered
    MapLayer[] layers;       /// All map layers (tiles and objects)
    TileSet[] tilesets;      /// All tile sets defined in this map
  }

  @jsonize(JsonizeOptional.yes) {
    string backgroundcolor;    /// Hex-formatted background color (#RRGGBB)
    string renderorder;        /// Rendering direction (orthogonal maps only)
    string[string] properties; /// Key-value property pairs set at the map level
    int nextobjectid;
  }

  static TiledMap load(string path) {
    enforce(path.exists, "No map file found at " ~ path);
    return readJSON!TiledMap(path);
  }
}

class MapLayer {
  mixin JsonizeMe;

  /// Identifies what kind of information a layer contains.
  enum Type {
    tilelayer,   /// One tileset index for every tile in the layer
    objectgroup, /// One or more `MapObjects`
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
    int[] data;                /// An array of GIDs that identify tiles. Only on `tilelayer` layers
    MapObject[] objects;       /// An array of objects. Only on `objectgroup` layers.
    string[string] properties; /// Optional user-defined key-value properties for this layer
    float opacity;             /// Visual opacity of all tiles in this layer
  }
}

class MapObject {
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
  }

  @jsonize(JsonizeOptional.yes) {
    int gid; /// Identifies a tile in a tileset if this object is represented by a tile
  }
}

class TileSet {
  mixin JsonizeMe;
  @jsonize(JsonizeOptional.no) {
    int firstgid;              /// The GID that maps to the first tile in this set
    string image;              /// Image used for tiles in this set
    string name;               /// Name given to this tileset
    int tilewidth;             /// Maximum width of tiles in this set
    int tileheight;            /// Maximum height of tiles in this set
    int imagewidth;            /// Width of source image in pixels
    int imageheight;           /// Height of source image in pixels
    string[string] properties; /// Properties assigned to this tileset
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
}
