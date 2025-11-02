class_name Instrument
extends Node2D

## Signal emitted when a MIDI message is generated as an InputEventMIDI
signal midi_event_generated(event: InputEventMIDI)

# --- Constants ---
# MIDI Note Numbers for D Major Scale starting D4
const D_MAJOR_SCALE_MIDI = [62, 64, 66, 67, 69, 71, 73]
const NOTE_NAMES = ["D4", "E4", "F#4", "G4", "A4", "B4", "C#5"]

# Keyboard Mapping (A, S, D, F, G, H, J)
const KEY_MAP = [KEY_A, KEY_S, KEY_D, KEY_F, KEY_G, KEY_H, KEY_J]

# MIDI Defaults
const DEFAULT_VELOCITY = 100
# -----------------

# Store references to the created buttons
var _buttons: Array[Button] = []


func _ready():
	# --- Dynamically Create Buttons ---
	for i in range(D_MAJOR_SCALE_MIDI.size()):
		var midi_note = D_MAJOR_SCALE_MIDI[i]
		var note_name = NOTE_NAMES[i] if i < NOTE_NAMES.size() else str(midi_note)

		var new_button = Button.new()
		new_button.text = note_name
		new_button.name = "NoteButton_" + note_name

		# Position Buttons (Simple Horizontal Layout)
		var button_width = 100
		var spacing = 10
		new_button.position = Vector2(i * (button_width + spacing), 0)
		new_button.size = Vector2(button_width, 40)

		add_child(new_button)
		_buttons.append(new_button) # Store reference

		# Connect signals, binding the MIDI note number
		new_button.button_down.connect(_on_button_down.bind(midi_note))
		new_button.button_up.connect(_on_button_up.bind(midi_note))

	print("Instrument: Created ", _buttons.size(), " buttons dynamically.")


# --- Create and Emit InputEventMIDI ---
func _send_note_on(midi_note: int, velocity: int):
	var event = InputEventMIDI.new()
	event.channel = 0
	event.message = MIDI_MESSAGE_NOTE_ON # Using global constant
	event.pitch = midi_note
	event.velocity = velocity
	midi_event_generated.emit(event)

func _send_note_off(midi_note: int):
	var event = InputEventMIDI.new()
	event.channel = 0
	event.message = MIDI_MESSAGE_NOTE_OFF # Using global constant
	event.pitch = midi_note
	event.velocity = 0
	midi_event_generated.emit(event)

# --- Input Handlers ---
func _on_button_down(midi_note: int):
	_send_note_on(midi_note, DEFAULT_VELOCITY)
	var note_index = D_MAJOR_SCALE_MIDI.find(midi_note)
	if note_index != -1 and note_index < _buttons.size():
		_buttons[note_index].button_pressed = true


func _on_button_up(midi_note: int):
	_send_note_off(midi_note)
	var note_index = D_MAJOR_SCALE_MIDI.find(midi_note)
	if note_index != -1 and note_index < _buttons.size():
		_buttons[note_index].button_pressed = false


func _unhandled_input(event):
	if event is InputEventKey:
		# Find which key was pressed/released based on our KEY_MAP
		var key_index = KEY_MAP.find(event.keycode)

		# Check if the found key is within the bounds of our scale/buttons
		if key_index != -1 and key_index < D_MAJOR_SCALE_MIDI.size():
			var midi_note = D_MAJOR_SCALE_MIDI[key_index]

			if event.is_pressed() and not event.is_echo():
				_send_note_on(midi_note, DEFAULT_VELOCITY)
				# Visually press the corresponding button
				if key_index < _buttons.size():
					_buttons[key_index].button_pressed = true
				get_viewport().set_input_as_handled()

			elif event.is_released():
				_send_note_off(midi_note)
				# Visually release the corresponding button
				if key_index < _buttons.size():
					_buttons[key_index].button_pressed = false
				get_viewport().set_input_as_handled()
