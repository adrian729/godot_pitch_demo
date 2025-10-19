extends Node

signal midi_note_changed(prev: int, val: int)

@export_range(0.0, 1.0) var note_detection_threshold: float = 0.4
@export_range(0.01, 0.2) var note_stability_time: float = 0.01

const MIN_DB = 60
const RECORD_BUS_NAME = "record"
const NOTE_FADE_OUT_SPEED = 8.0
const START_FADE_VALUE = 1.0

@onready var record_bus_index: int = AudioServer.get_bus_index(RECORD_BUS_NAME)
@onready var spectrum_effect: AudioEffectSpectrumAnalyzerInstance = AudioServer.get_bus_effect_instance(record_bus_index, 1)

@onready var _note_ranges_table: Array = NoteRanges.get_note_ranges()

var fade_value = START_FADE_VALUE
var stability_timer: float = 0.0

var midi_note = -1 # val > 0 note detected, otherwise none
var last_midi_note = -1 # val > 0 note detected, otherwise none


func _process(delta: float) -> void:
	update_note_detection(delta)


func update_note_detection(delta: float) -> void:
	var playing_note := get_playing_note()
	# --- Case 1: Sound is being detected ---
	if playing_note > 0:
		stability_timer += delta
		if playing_note != last_midi_note:
			stability_timer = 0.0

		if stability_timer > note_stability_time:
			if midi_note != playing_note:
				midi_note_changed.emit(midi_note, playing_note)
				midi_note = playing_note
	# --- Case 2: Silence is detected ---
	else:
		stability_timer = 0.0
		# Only fade out during silence
		if midi_note > 0:
			fade_value = lerpf(fade_value, 0.0, delta * NOTE_FADE_OUT_SPEED)
			if fade_value < 0.01:
				fade_value = START_FADE_VALUE
				midi_note_changed.emit(midi_note, -1)
				midi_note = -1

	last_midi_note = playing_note


func get_playing_note() -> int:
	var max_energy := note_detection_threshold
	var detected_midi_note := -1

	for note_data in _note_ranges_table:
		if note_data != null:
			var low_bound = note_data[NoteRanges.NoteData.LOW_BOUND]
			var high_bound = note_data[NoteRanges.NoteData.HIGH_BOUND]

			var magnitude := spectrum_effect.get_magnitude_for_frequency_range(low_bound, high_bound).length()
			var energy := clampf((MIN_DB + linear_to_db(magnitude)) / MIN_DB, 0, 1)

			if energy > max_energy:
				max_energy = energy
				detected_midi_note = note_data[NoteRanges.NoteData.MIDI]

	return detected_midi_note
