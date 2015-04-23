/**
  * Convenience functions for interpreting Tiled map data.
  * Provides a higher-level API than tiled.core.
  *
  * Authors: <a href="https://github.com/rcorre">rcorre</a>
	* License: <a href="http://opensource.org/licenses/MIT">MIT</a>
	* Copyright: Copyright © 2015, Ryan Roden-Corrent
  */
module tiled.helper;

import std.range     : empty, front;
import std.string    : format;
import std.algorithm : find;
import std.exception : enforce;
import tiled.core;

/** Fetch a map layer by its name. No check for layers with duplicate names is performed.
 * Throws if no layer has a matching name (case-sensitive).
 * Params:
 *   name = name of layer to find
 * Returns: Layer matching name
 */
MapLayer getLayer(TiledMap map, string name) {
  auto r = map.layers.find!(x => x.name == name);
  enforce(!r.empty, "Could not find layer named %s".format(name));
  return r.front;
}

/** Fetch a tileset by its name. No check for layers with duplicate names is performed.
 * Throws if no tileset has a matching name (case-sensitive).
 * Params:
 *   name = name of tileset to find
 * Returns: Tileset matching name
 */
TileSet getTileset(TiledMap map, string name) {
  auto r = map.tilesets.find!(x => x.name == name);
  enforce(!r.empty, "Could not find layer named %s".format(name));
  return r.front;
}
