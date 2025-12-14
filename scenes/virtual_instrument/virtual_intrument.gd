class_name VirtualInstrument
extends Node2D


@export var transpose_semitones: int = 12 * 4 # default 4 octaves

# TODO: my keyboard only picks 6 simultaneous keys :/ so this won't work for example... sad
@export var key_map: Array[Key] = [
	KEY_S, KEY_D, KEY_F, KEY_J, KEY_K, KEY_L, # fingering
	KEY_A # 'BLOW'
]

@onready var voices: Array = $Voices.get_children().map(func(child): return child as Voice)


var _label_refs: Array[Label] = []
var pressed_keys: Dictionary[Key, bool] = {} # <Key, is_pressed>

func _ready():
	var conf_warns = _get_configuration_warnings()
	if len(conf_warns):
		printerr(conf_warns[0])

	# --- Dynamically Create Labels (based on key_map) ---
	if key_map.is_empty():
		printerr("VirtualInstrument: key_map is empty, no labels created.")
		return

	for i in key_map.size():
		var key: Key = key_map[i]
		# --- MODIFIED: Create a Label ---
		var new_label = Label.new()
		new_label.text = str(key)
		new_label.name = "NoteLabel_" + str(key)

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

	print("Instrument: Created ", _label_refs.size(), " labels dynamically.")


func _unhandled_input(event):
	var has_keys_changed = false
	if event is InputEventKey:
		if event.is_pressed() and not event.is_echo():
			has_keys_changed = _on_key_pressed(event.keycode)
		elif event.is_released():
			has_keys_changed = _on_key_released(event.keycode) or has_keys_changed


func _on_key_pressed(key: Key) -> bool:
	if not key in key_map:
		return false
	
	if pressed_keys.get(key):
		return false

	pressed_keys[key] = true
	
	var key_idx = key_map.find(key)
	if key_idx != -1 and key_idx < _label_refs.size():
		_label_refs[key_idx].modulate = Color.GREEN

	get_viewport().set_input_as_handled()
	return true


func _on_key_released(key: Key):
	if not key in key_map:
		return false
	
	if not pressed_keys.get(key):
		return false

	pressed_keys[key] = false
	
	var key_idx = key_map.find(key)
	if key_idx != -1 and key_idx < _label_refs.size():
		_label_refs[key_idx].modulate = Color.WHITE

	get_viewport().set_input_as_handled()
	return true


# CONFIGURATION WARNINGS
func _get_configuration_warnings():
	if key_map.is_empty():
		return ["Key Map array is empty."]

	return []
