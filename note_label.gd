class_name NoteLabel
extends RichTextLabel

const EMPTY_LABEL = "---"

@onready var pitch_detection = $"../../PitchDetection"


func _ready() -> void:
	text = EMPTY_LABEL


func _on_pitch_detection_midi_note_changed(_prev: int, val: int) -> void:
	if val > 0:
		text = NoteRanges.get_note_name(val)
	else:
		text = EMPTY_LABEL
