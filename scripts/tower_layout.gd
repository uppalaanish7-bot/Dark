extends RefCounted
## Shared dimensions of the eleven-storey cathedral and its continuous stairs.
const FLOOR_COUNT: int = 11
const FLOOR_HEIGHT: float = 18.0
const ROOF_HEIGHT: float = FLOOR_COUNT * FLOOR_HEIGHT
const ROOM_HALF_WIDTH: float = 110.0
const ROOM_HALF_DEPTH: float = 260.0
const STAIR_OFFSET := Vector3(176, 0, 250)
const HALL_EXIT := Vector3(104, 0.12, 256)
const CORRIDOR_TURN := Vector3(104, 0.12, 270)
const ROOM_OFFSETS := [Vector3(-150, 0, -170), Vector3(-150, 0, 80), Vector3(150, 0, -130), Vector3(150, 0, 170), Vector3(0, 0, -310)]
const ROOM_SIZES := [Vector2(80, 100), Vector2(80, 100), Vector2(80, 100), Vector2(80, 100), Vector2(100, 100)]
const ROOM_DOORS := [Vector3(-110, 0, -192), Vector3(-110, 0, 108), Vector3(110, 0, -98), Vector3(110, 0, 140), Vector3(35, 0, -260)]
const STAIR_STEPS: int = 36
const STEP_RISE: float = 0.25
const STEP_RUN: float = 0.55
const STAIR_WIDTH: float = 6.0
const STAIR_START_Z: float = 266.0
const STAIR_TURN_Z: float = 246.2
const LOWER_FLIGHT_X: float = 208.0
const UPPER_FLIGHT_X: float = 216.0
const POTION_POSITION := Vector3(0, ROOF_HEIGHT + 0.12, -7)
const EXIT_POSITION := Vector3(0, ROOF_HEIGHT + 0.12, -24)
const TERRACE_POSITION := Vector3(0, ROOF_HEIGHT + 0.12, 14)

static func center(index: int) -> Vector3:
	return Vector3(0, clampi(index, 0, FLOOR_COUNT - 1) * FLOOR_HEIGHT + 0.12, 0)

static func floor_spawn(index: int) -> Vector3:
	return Vector3(0, clampi(index, 0, FLOOR_COUNT - 1) * FLOOR_HEIGHT + 0.12, 10)

static func stair_entry(index: int) -> Vector3:
	return Vector3(LOWER_FLIGHT_X, clampi(index, 0, FLOOR_COUNT - 1) * FLOOR_HEIGHT + 0.12, 270)

static func room_centers(index: int) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for offset in ROOM_OFFSETS:
		result.append(offset + Vector3.UP * (clampi(index, 0, FLOOR_COUNT - 1) * FLOOR_HEIGHT + 0.12))
	return result

static func key_position(index: int) -> Vector3:
	var room: int = clampi(index, 0, FLOOR_COUNT - 1) % ROOM_OFFSETS.size()
	var at: Vector3 = room_centers(index)[room]
	return at + (Vector3(-24 if at.x < 0 else 24, 0, 26) if room < 4 else Vector3(-30, 0, -30))

static func room_rect(room: int) -> Rect2:
	var offset: Vector3 = ROOM_OFFSETS[room]
	var size: Vector2 = ROOM_SIZES[room]
	return Rect2(Vector2(offset.x, offset.z) - size * 0.5, size)

static func floor_bounds() -> Rect2:
	return Rect2(-140, -140, 280, 280)

static func floor_for_position(pos: Vector3) -> int:
	return clampi(floori((pos.y + 0.15) / FLOOR_HEIGHT), 0, FLOOR_COUNT)

static func stair_surface_height(pos: Vector3, index: int) -> float:
	var base: float = clampi(index, 0, FLOOR_COUNT - 1) * FLOOR_HEIGHT
	if pos.z >= STAIR_START_Z:
		return base
	if pos.z <= STAIR_TURN_Z:
		return base + FLOOR_HEIGHT * 0.5
	if pos.x < 212.0:
		return base + ceilf((STAIR_START_Z - pos.z) / STEP_RUN) * STEP_RISE
	return base + FLOOR_HEIGHT * 0.5 + ceilf((pos.z - STAIR_TURN_Z) / STEP_RUN) * STEP_RISE

static func play_bounds() -> Rect2:
	return floor_bounds()
