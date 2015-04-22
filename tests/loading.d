module tests.loading;

import std.path : buildPath, setExtension;
import std.exception : assertThrown;
import tiled;

enum testPath(string name) = "tests".buildPath("resources", name).setExtension("json");

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
  assert(tiles.data    == [1, 2, 1, 2, 3, 1, 3, 1, 2, 2, 3, 3, 4, 4, 4, 1]);
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

  // test getTileset
  assert(map.getLayer("terrain") == map.layers[0]);
  assertThrown(map.getLayer("nosuchlayer"));
}

/// Load a map containing a single tile layer
unittest {
  // load map
  auto map = TiledMap.load(testPath!"objects");
}
