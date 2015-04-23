#!/bin/sh

MAPDIR="./tests/resources"

for file in $MAPDIR/*.tmx;
do
  target="${file%.tmx}.json"
  echo "$file -> $target"
  tiled --export-map $file $target
done
