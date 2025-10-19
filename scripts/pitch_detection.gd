extends Node

@export_range(0.0, 1.0) var note_detection_threshold: float = 0.25
@export_range(0.01, 0.2) var note_stability_time: float = 0.03

const MIN_DB = 60
const RECORD_BUS_NAME = "record"
const NOTE_FADE_OUT_SPEED = 8.0

@onready var curr_note_label: RichTextLabel = $"../UI/NoteLabel"

@onready var record_bus_index: int = AudioServer.get_bus_index(RECORD_BUS_NAME)
@onready var spectrum_effect: AudioEffectSpectrumAnalyzerInstance = AudioServer.get_bus_effect_instance(record_bus_index, 1)

var _note_ranges_table: Array = []

# State tracking variables
var _current_displayed_note: String = ""
var _last_detected_note: String = ""
var _stability_timer: float = 0.0


func _ready() -> void:
	_note_ranges_table = NoteRanges.get_note_ranges()
	curr_note_label.text = "---"


func _process(delta: float) -> void:
	_update_note_detection(delta)


func _update_note_detection(delta: float) -> void:
	var max_energy := 0.0
	var dominant_note_name := ""
	
	for note_data in _note_ranges_table:
		if note_data != null:
			var low_bound = note_data[NoteRanges.NoteData.LOW_BOUND]
			var high_bound = note_data[NoteRanges.NoteData.HIGH_BOUND]

			var magnitude := spectrum_effect.get_magnitude_for_frequency_range(low_bound, high_bound).length()
			var energy := clampf((MIN_DB + linear_to_db(magnitude)) / MIN_DB, 0, 1)

			if energy > max_energy:
				max_energy = energy
				dominant_note_name = note_data[NoteRanges.NoteData.NAME]

	var detected_note = dominant_note_name if max_energy > note_detection_threshold else ""

	# --- Case 1: Sound is being detected ---
	if detected_note != "":
		# Update stability timer for the currently heard note
		if detected_note == _last_detected_note:
			_stability_timer += delta
		else:
			_stability_timer = 0.0 # A new note is heard, reset its stability timer
		
		# If the newly heard note is stable, update the display
		if _stability_timer > note_stability_time:
			if _current_displayed_note != detected_note:
				_current_displayed_note = detected_note
				curr_note_label.text = _current_displayed_note

		# As long as sound is being made, keep the label fully visible
		curr_note_label.modulate.a = 1.0

	# --- Case 2: Silence is detected ---
	else:
		_stability_timer = 0.0
		# Only fade out during silence
		if _current_displayed_note != "":
			curr_note_label.modulate.a = lerpf(curr_note_label.modulate.a, 0.0, delta * NOTE_FADE_OUT_SPEED)
			if curr_note_label.modulate.a < 0.01:
				_current_displayed_note = ""
				curr_note_label.text = "---"
	
	_last_detected_note = detected_note
