class_name Voice
extends Node2D

const DEFAULT_VELOCITY = 5


@export var sampler_instrument: SamplerInstrument

@export var valid_tones: Array[PlayingNotes.Tone] = PlayingNotes.C_MAJOR
@export var valid_tone_relative_octaves: Array[int] = []

@export var tone_low: PlayingNotes.Tone = PlayingNotes.Tone.C:
	set(value):
		tone_low = value
		update_configuration_warnings()
@export_range(0, 10, 1, 'Octave Lower Bound') var octave_low: int = 4:
	set(value):
		octave_low = value
		update_configuration_warnings()

@export var tone_up: PlayingNotes.Tone = PlayingNotes.Tone.C:
	set(value):
		tone_up = value
		update_configuration_warnings()
@export_range(0, 10, 1, 'Octave Upper Bound') var octave_up: int = 6:
	set(value):
		octave_up = value
		update_configuration_warnings()


func _ready() -> void:
	var conf_warns = _get_configuration_warnings()
	if len(conf_warns):
		printerr(conf_warns[0])

	if not is_instance_valid(sampler_instrument):
		printerr("VirtualInstrument: FluteSamplerInstrument node not found!")
		set_process_unhandled_input(false)
		return

	fill_valid_tone_relative_octaves()


func fill_valid_tone_relative_octaves() -> void:
	# Populate any missing valid tone relative octaves,
	# following the chromatic scale, if not enough values are provided
	if len(valid_tone_relative_octaves) < len(valid_tones):
		var start_idx = len(valid_tone_relative_octaves)
		for i in range(len(valid_tones) - len(valid_tone_relative_octaves)):
			var idx = start_idx + i

			var curr_tone = valid_tones[idx]
			var prev_tone = null
			if idx > 0:
				prev_tone = valid_tones[idx - 1]

			var prev_octave = 0
			if idx > 0 and len(valid_tone_relative_octaves) > idx - 1:
				prev_octave = valid_tone_relative_octaves[idx - 1]
			if prev_tone != null and prev_tone >= curr_tone:
				valid_tone_relative_octaves.append(prev_octave + 1)
			else:
				valid_tone_relative_octaves.append(prev_octave)


func play_note(note_tone: PlayingNotes.Tone, note_octave: int):
	sampler_instrument.release()
	sampler_instrument.play_note(
		PlayingNotes.tone_enum_to_str(note_tone),
		note_octave,
		DEFAULT_VELOCITY
	)


#func get_key_tone(key_idx: int) -> PlayingNotes.Tone:
	#return valid_tones[key_idx % valid_tones.size()]


#func get_key_octave(key_idx: int) -> int:
	#var tone_relative_octave = valid_tone_relative_octaves[key_idx % valid_tone_relative_octaves.size()]
	#return tone_relative_octave + floori(float(key_idx) / len(valid_tone_relative_octaves)) + int(transpose_semitones / 12.0)


# CONFIGURATION WARNINGS
func _get_configuration_warnings():
	if not is_instance_valid(sampler_instrument):
		return ["SamplerInstrument node is not assigned."]

	if octave_low > octave_up:
		return ['Upper octave must be greater or equal than lower octave']
	if octave_low == octave_up and tone_low > tone_up:
		return ['Upper tone must be greater or equal than lower tone if lower and upper octave are equal']

	if valid_tones.is_empty():
		return ["Valid Tones array is empty."]

	return []
