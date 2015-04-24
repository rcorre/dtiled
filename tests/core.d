module tests.core;

import std.conv;
import std.range;
import std.algorithm;
import std.path : buildPath, setExtension;
import std.exception : assertThrown;
import tiled.core;

enum testPath(string name) = "tests".buildPath("resources", name).setExtension("json");

// expected gids for the test terrain layer
enum terrainGids = [1, 2, 1, 2, 3, 1, 3, 1, 2, 2, 3, 3, 4, 4, 4, 1];
enum flippedTerrainGids = [1, 2, 2, 1, 3, 1, 1, 3, 4, 4, 1, 4, 2, 2, 3, 3];

/// Load a map containing a single tile layer
unittest {
  // load map
  auto map = TiledMap.load(testPath!"tiles");

  // general fields
  assert(map.height          == 4);
  assert(map.width           == 4);
  assert(map.tilewidth       == 32);
  assert(map.tileheight      == 32);
  assert(map.renderorder     == TiledMap.RenderOrder.rightDown);
  assert(map.orientation     == TiledMap.Orientation.orthogonal);
  assert(map.backgroundcolor == "#656667");

  // user defined properties
  assert(map.properties["mapProperty1"] == "one");
  assert(map.properties["mapProperty2"] == "two");

  // this map should have a single tile layer
  assert(map.layers.length == 1);
  auto tiles = map.layers[0];
  assert(tiles.name    == "terrain");
  assert(tiles.data    == terrainGids);
  assert(tiles.height  == 4);
  assert(tiles.width   == 4);
  assert(tiles.opacity == 1f);
  assert(tiles.type    == MapLayer.Type.tilelayer);
  assert(tiles.visible);
  assert(tiles.x == 0);
  assert(tiles.y == 0);

  // this map should have a single tile set
  assert(map.tilesets.length == 1);
  auto tileset = map.tilesets[0];
  assert(tileset.name        == "terrain");
  assert(tileset.firstgid    == 1);
  assert(tileset.imageheight == 64);
  assert(tileset.imagewidth  == 64);
  assert(tileset.margin      == 0);
  assert(tileset.tileheight  == 32);
  assert(tileset.tilewidth   == 32);
  assert(tileset.spacing     == 0);
}

/// Load a map containing an object layer
unittest {
  import std.string : format;

  // load map
  auto map = TiledMap.load(testPath!"objects");

  // Layer 1 is an object layer in the test map
  auto layer = map.layers[1];
  assert(layer.name == "things");
  assert(layer.type == MapLayer.Type.objectgroup);
  assert(layer.draworder == "topdown");

  // Tileset 1 is the tileset used for the objects
  auto tileset = map.tilesets[1];
  assert(tileset.name == "numbers");
  auto objects = layer.objects;

  // helper to check an object in the test data
  void checkObject(int num) {
    string name = "number%d".format(num);
    auto found = objects.find!(x => x.name == name);
    assert(!found.empty, "no object with name " ~ name);
    auto obj = found.front;

    assert(obj.gid == tileset.firstgid + num - 1); // number1 is the zeroth tile, ect.
    assert(obj.type == (num % 2 == 0 ? "even" : "odd")); // just an arbitrarily picked type
    //assert(obj.properties["half"].to!int == num / 2 ));
    assert(obj.rotation == 0);
    assert(obj.visible);
  }

  checkObject(1);
  checkObject(2);
  checkObject(3);
  checkObject(4);
}

/// Load a map containing flipped (mirrored) tiles.
unittest {
  import std.algorithm : map, equal;

  // load map
  auto tileMap = TiledMap.load(testPath!"flipped_tiles");

  // this map should have a single tile layer
  assert(tileMap.layers.length == 1);
  auto layer = tileMap.layers[0];

  // clear special bits to get actual gid
  auto gids = layer.data.map!(gid => gid & ~TileFlag.all);
  // with the special bits cleared, the gids should be the same as in the original map
  assert(gids.equal(flippedTerrainGids));

  // isolate special bits to get flipped state
  auto flags = layer.data.map!(gid => gid & TileFlag.all);

  with(TileFlag) {
    enum N = none;
    enum H = flipHorizontal;
    enum V = flipVertical;
    enum D = H | V;

    enum flippedState = [
      N, N, H, H,
      N, N, H, H,
      V, V, D, D,
      V, V, D, D,
    ];

    assert(flags.equal(flippedState));
  }
}

/// Load a map containing flipped (mirrored) objects.
unittest {
  import std.conv;
  import std.string : format;

  // load map
  auto map = TiledMap.load(testPath!"flipped_objects");

  // Layer 1 is an object layer in the test map
  auto layer = map.layers[1];

  // Tileset 1 is the tileset used for the objects
  auto tileset = map.tilesets[1];
  assert(tileset.name == "numbers");
  auto objects = layer.objects;

  // helper to check an object in the test data
  void checkObject(int num, TileFlag expectedFlags) {
    string name = "number%d".format(num);
    auto found = objects.find!(x => x.name == name);
    assert(!found.empty, "no object with name " ~ name);
    auto obj = found.front;

    auto gid = obj.gid & ~TileFlag.all;
    auto flags = obj.gid & TileFlag.all;
    assert(gid == tileset.firstgid + num - 1); // number1 is the zeroth tile, ect.
    assert(flags == expectedFlags, 
        "tile %d: expected flag %s, got %s".format(num, expectedFlags, cast(TileFlag) flags));
  }

  checkObject(1, TileFlag.none);
  checkObject(2, TileFlag.flipVertical);
  checkObject(3, TileFlag.flipHorizontal);
  checkObject(4, TileFlag.flipHorizontal | TileFlag.flipVertical);
}
