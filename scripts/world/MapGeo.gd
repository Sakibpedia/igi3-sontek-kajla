extends RefCounted
## Converts game-world metres (origin = Kajla centre) to pixels of the real
## OpenStreetMap raster (assets/maps/kajla_osm.png, zoom 18, 4x4 tiles).
const LAT0 := 23.71116
const LON0 := 90.44350
const N := 131072.0          # 2^17
const TILE_X0 := 98461       # first tile x in the stitched image
const TILE_Y0 := 56641       # first tile y in the stitched image
const TILE_SIZE := 256.0
const IMG_SIZE := 2048.0
const MAP_PX_PER_M := 0.914
const MX := 95200.0          # metres per degree longitude at Kajla
const MZ := 111320.0         # metres per degree latitude

static func world_to_map(p: Vector2) -> Vector2:
	var lon := LON0 + p.x / MX
	var lat := LAT0 - p.y / MZ
	var gx := (lon + 180.0) / 360.0 * N
	var t := tan(deg_to_rad(lat))
	var gy := (1.0 - log(t + 1.0 / maxf(cos(deg_to_rad(lat)), 0.001)) / PI) * 0.5 * N
	return Vector2((gx - float(TILE_X0)) * TILE_SIZE, (gy - float(TILE_Y0)) * TILE_SIZE)


static func map_uv(p: Vector2) -> Vector2:
	return world_to_map(p) / IMG_SIZE
