class_name Instrument
extends Node2D

@onready var button1: Button = $Button1
@onready var button2: Button = $Button2
@onready var audio_generator: AudioGenerator = $"../AudioGenerator" # Assumes path

# C4 = 261.63 Hz, A4 = 440.0 Hz
const NOTE_1 = 261.63
const NOTE_2 = 440.0

func _ready():
	# --- 1. Mouse Click Logic ---
	button1.button_down.connect(_on_button_down.bind(NOTE_1))
	button1.button_up.connect(_on_button_up.bind(NOTE_1))
	
	button2.button_down.connect(_on_button_down.bind(NOTE_2))
	button2.button_up.connect(_on_button_up.bind(NOTE_2))

# These functions handle the button signals
func _on_button_down(hz: float):
	audio_generator.note_on(hz)

func _on_button_up(hz: float):
	audio_generator.note_off(hz)

# --- 2. Keyboard Logic ---
func _unhandled_input(event):
	
	if event is InputEventKey:
		
		# --- Handle 'A' Key (Note 1) ---
		if event.keycode == KEY_A:
			if event.is_pressed() and not event.is_echo():
				audio_generator.note_on(NOTE_1)
			elif event.is_released():
				audio_generator.note_off(NOTE_1)
		
		# --- Handle 'S' Key (Note 2) ---
		elif event.keycode == KEY_S:
			if event.is_pressed() and not event.is_echo():
				audio_generator.note_on(NOTE_2)
			elif event.is_released():
				audio_generator.note_off(NOTE_2)
