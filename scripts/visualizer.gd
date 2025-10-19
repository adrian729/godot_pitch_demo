class_name Visualizer
extends Node2D

@export var show_peak_hold_line: bool = true

const VU_COUNT = 512
const PADDING = 40.0
const HEIGHT = 250
const HEIGHT_SCALE = 8.0
const MIN_DB = 60
const ANIMATION_SPEED = 0.1
const RECORD_BUS_NAME = "record"

@onready var record_bus_index: int = AudioServer.get_bus_index(RECORD_BUS_NAME)
@onready var spectrum_effect: AudioEffectSpectrumAnalyzerInstance = AudioServer.get_bus_effect_instance(record_bus_index, 1)

var min_values: Array[float] = []
var max_values: Array[float] = []
var freq_max: float = 0.0


func _ready() -> void:
	freq_max = NoteRanges.get_max_frequency()
	
	min_values.resize(VU_COUNT)
	max_values.resize(VU_COUNT)
	min_values.fill(0.0)
	max_values.fill(0.0)


func _draw() -> void:
	var screen_size = get_viewport_rect().size
	var draw_width = screen_size.x - (PADDING * 2)
	var origin = Vector2((screen_size.x - draw_width) / 2, screen_size.y / 2)
	
	var w: float = draw_width / VU_COUNT
	for i in VU_COUNT:
		var min_height = min_values[i]
		var max_height = max_values[i]
		var height = lerp(min_height, max_height, ANIMATION_SPEED)
		var base_color = Color.from_hsv(float(VU_COUNT * 0.6 + i * 0.5) / VU_COUNT, 0.5, 0.6)
		var peak_color = Color.from_hsv(float(VU_COUNT * 0.6 + i * 0.5) / VU_COUNT, 0.5, 1.0)
		
		var bar_x = origin.x + w * i
		
		# Main Bar
		draw_rect(Rect2(bar_x, origin.y - height, w - 2, height), base_color)
		draw_line(Vector2(bar_x, origin.y - height), Vector2(bar_x + w - 2, origin.y - height), peak_color, 2.0, true)

		# Peak Hold Line
		if show_peak_hold_line:
			var peak_y = origin.y - max_values[i]
			draw_line(Vector2(bar_x, peak_y), Vector2(bar_x + w - 2, peak_y), peak_color, 2.0, true)

		# Reflection
		var reflection_color = base_color * Color(1, 1, 1, 0.125)
		var reflection_peak_color = peak_color * Color(1, 1, 1, 0.125)
		draw_rect(Rect2(bar_x, origin.y, w - 2, height), reflection_color)
		draw_line(Vector2(bar_x, origin.y + height), Vector2(bar_x + w - 2, origin.y + height), reflection_peak_color, 2.0, true)


func _process(_delta: float) -> void:
	var data: Array[float] = []
	data.resize(VU_COUNT)
	var prev_hz := 0.0

	for i in VU_COUNT:
		var hz := (i + 1) * freq_max / VU_COUNT
		var magnitude := spectrum_effect.get_magnitude_for_frequency_range(prev_hz, hz).length()
		var energy := clampf((MIN_DB + linear_to_db(magnitude)) / MIN_DB, 0, 1)
		data[i] = energy * HEIGHT * HEIGHT_SCALE
		prev_hz = hz

	for i in VU_COUNT:
		var height = data[i]
		if height > max_values[i]:
			max_values[i] = height
		else:
			max_values[i] = lerpf(max_values[i], height, ANIMATION_SPEED)

		if height <= 0.0:
			min_values[i] = lerpf(min_values[i], 0.0, ANIMATION_SPEED)

	queue_redraw()
