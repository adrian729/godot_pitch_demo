class_name VirtualInstrument
extends Node2D

# TODO: add transpose (so we can have for example flutes with different registers)
const DEFAULT_VELOCITY = 5

# VIRTUAL INSTRUMENT
@export var transpose_semitones: int = 0
# END VIRTUAL INSTRUMENT

# VOICE (TODO: move to nodes)
@export var sampler_instrument: SamplerInstrument
@export var valid_tones: Array[PlayingNotes.Tone] = PlayingNotes.C_MAJOR

@export var tone_low: PlayingNotes.Tone = PlayingNotes.Tone.C:
	set(value):
		tone_low = value
		update_configuration_warnings()
@export_range(0, 10, 1,'Octave Lower Bound') var octave_low: int = 4:
	set(value):
		octave_low = value
		update_configuration_warnings()

@export var tone_up: PlayingNotes.Tone = PlayingNotes.Tone.C:
	set(value):
		tone_up = value
		update_configuration_warnings()
@export_range(0, 10, 1, 'Octave Upper Bound') var octave_up: int = 6:
	set(value):
		octave_low = value
		update_configuration_warnings()

@export var key_map: Array[Key] = [KEY_A, KEY_S, KEY_D, KEY_F, KEY_G, KEY_H, KEY_J, KEY_K]
# END VOICE

var _label_refs: Array[Label] = []
var playing_key_idx: int = -1 # Currently playing key
var pressed_key_idxs: Array[int] = [] # Currently pressed keys (playing key NOT included)


func _ready():
	var conf_warns = _get_configuration_warnings()
	if len(conf_warns):
		printerr(conf_warns[0])

	if not is_instance_valid(sampler_instrument):
		printerr("VirtualInstrument: FluteSamplerInstrument node not found!")
		set_process_unhandled_input(false)
		return

	# --- Dynamically Create Labels (based on key_map) ---
	if key_map.is_empty():
		printerr("VirtualInstrument: key_map is empty, no labels created.")
		return
	if valid_tones.is_empty():
		printerr("VirtualInstrument: valid_tones is empty, cannot create labels.")
		return
		
	for i in range(key_map.size()):
		var note_tone_enum = valid_tones[i % valid_tones.size()]
		var note_octave = get_key_octave(i)
		var note_name = PlayingNotes.tone_enum_to_str(note_tone_enum) + str(note_octave)

		# --- MODIFIED: Create a Label ---
		var new_label = Label.new()
		new_label.text = note_name
		new_label.name = "NoteLabel_" + note_name

		# Position Labels
		var label_width = 100
		var spacing = 10
		new_label.position = Vector2(i * (label_width + spacing), 0)
		new_label.size = Vector2(label_width, 40)
		
		# Optional: Add some styling
		new_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		new_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

		add_child(new_label)
		_label_refs.append(new_label)
		
		# --- REMOVED: Button signal connections ---

	print("Instrument: Created ", _label_refs.size(), " labels dynamically.")


func _play_new_note(note_tone: PlayingNotes.Tone, note_octave: int):
	sampler_instrument.release()
	sampler_instrument.play_note(
		PlayingNotes.tone_enum_to_str(note_tone),
		note_octave,
		DEFAULT_VELOCITY
	)


func _unhandled_input(event):
	if event is InputEventKey:
		var key_idx = key_map.find(event.keycode)
		if event.is_pressed() and not event.is_echo():
			_on_key_pressed(key_idx)
		elif event.is_released():
			_on_key_released(key_idx)


func _on_key_pressed(key_idx: int):
	if key_idx == -1 or key_idx >= key_map.size():
		return

	if playing_key_idx == key_idx:
		return

	if playing_key_idx != -1:
		sampler_instrument.release()
		pressed_key_idxs.append(playing_key_idx)

	playing_key_idx = key_idx
	_play_new_note(
		get_key_tone(key_idx),
		get_key_octave(key_idx)
	)

	if key_idx < _label_refs.size():
		_label_refs[key_idx].modulate = Color.GREEN

	get_viewport().set_input_as_handled()


func _on_key_released(key_idx: int):
	if key_idx == -1 or key_idx >= key_map.size():
		return

	if playing_key_idx == key_idx:
		playing_key_idx = -1
		sampler_instrument.release()

	pressed_key_idxs.erase(key_idx)
	if key_idx < _label_refs.size():
		_label_refs[key_idx].modulate = Color.WHITE
	
	if len(pressed_key_idxs):
		playing_key_idx = pressed_key_idxs.pop_back()
		_play_new_note(
			get_key_tone(playing_key_idx),
			get_key_octave(playing_key_idx)
		)

	get_viewport().set_input_as_handled()


func _release(key_idx: int):
	sampler_instrument.release()
	if key_idx < _label_refs.size():
		_label_refs[key_idx].modulate = Color.WHITE


func get_key_tone(key_idx: int) -> PlayingNotes.Tone:
	return valid_tones[key_idx % valid_tones.size()]


func get_key_octave(key_idx: int) -> int:
	# TODO: fix this, it's all wrong.
	if valid_tones.is_empty():
		printerr("VirtualInstrument: valid_tones array is empty, cannot calculate octave.")
		return octave_low
	
	var octave_offset = floori(float(key_idx) / valid_tones.size())
	return octave_low + octave_offset


# CONFIGURATION WARNINGS
func _get_configuration_warnings():
	if not is_instance_valid(sampler_instrument):
		return ["SamplerInstrument node is not assigned."]

	if octave_low > octave_up:
		return ['Upper octave must be greater or equal than lower octave']
	if octave_low == octave_up and tone_low > tone_up:
		return ['Upper tone must be greater or equal than lower tone if lower and upper octave are equal']
	
	if key_map.is_empty():
		return ["Key Map array is empty."]
	if valid_tones.is_empty():
		return ["Valid Tones array is empty."]

	return []
