class_name Art
extends RefCounted
## Painted sprites in assets/sprites/px (tools/paint_art.py, tools/generate_ground.py). Looked up by
## name; when a name has no painted version the caller falls back to the pixel atlas.

const DIR := "res://assets/sprites/px/%s.png"

static var cache := {}


static func tex(name: String) -> Texture2D:
	if cache.has(name):
		return cache[name]
	var path := DIR % name
	var t: Texture2D = load(path) if ResourceLoader.exists(path) else null
	cache[name] = t
	return t


static func has(name: String) -> bool:
	return tex(name) != null
