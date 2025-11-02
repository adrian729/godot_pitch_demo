class_name MidiReceiver
extends Node

## The AudioGenerator node that controls the C# synth
@export var audio_generator: AudioGenerator

## The node emitting MIDI signals (our Instrument node, optional)
@export var virtual_midi_source: Node

func _ready():
	# Input Validation
	if not is_instance_valid(audio_generator):
		printerr("MidiReceiver: AudioGenerator node not assigned or invalid!")
		set_process_input(false)
		return

	# Enable System MIDI Input (Using OS singleton)
	OS.open_midi_inputs()
	var connected_devices = OS.get_connected_midi_inputs()
	if connected_devices.size() > 0:
		print("MidiReceiver: Listening to system MIDI devices: ", connected_devices)
	else:
		print("MidiReceiver: No system MIDI devices detected.")

	# Connect to Virtual Instrument Signal
	if is_instance_valid(virtual_midi_source):
		if virtual_midi_source.has_signal("midi_event_generated"):
			var err = virtual_midi_source.midi_event_generated.connect(_on_virtual_midi_event_received)
			if err == OK: print("MidiReceiver connected to virtual_midi_source.")
			else: printerr("MidiReceiver: Failed to connect signal. Error: ", err)
		else: printerr("MidiReceiver: virtual_midi_source lacks 'midi_event_generated' signal!")
	else: print("MidiReceiver: No virtual_midi_source assigned.")

# Cleanup MIDI on exit
func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		OS.close_midi_inputs()
		print("MidiReceiver: Closed MIDI inputs.")

# Catches System MIDI Events
func _input(event):
	if event is InputEventMIDI:
		_process_midi_event(event)
		get_viewport().set_input_as_handled()

# Catches Events from Virtual Node
func _on_virtual_midi_event_received(event: InputEventMIDI):
	_process_midi_event(event)

# Central Processing Logic
func _process_midi_event(event: InputEventMIDI):
	if not is_instance_valid(audio_generator): return

	# Use correct global constants for comparison
	match event.message:
		MIDI_MESSAGE_NOTE_OFF:
			audio_generator.note_off(event.pitch)
		MIDI_MESSAGE_NOTE_ON:
			if event.velocity == 0:
				audio_generator.note_off(event.pitch)
			else:
				audio_generator.note_on(event.pitch, event.velocity)
		_:
			pass # Ignore other messages

func hex(val: int) -> String:
	return "0x%X" % val
