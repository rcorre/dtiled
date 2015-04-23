module tests.core;

import std.conv;
import std.range;
import std.algorithm;
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

  // find the object layer
  auto layer = map.getLayer("things");
  assert(layer.type == MapLayer.Type.objectgroup);
  assert(layer.draworder == "topdown");

  auto tileset = map.getTileset("numbers");
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
