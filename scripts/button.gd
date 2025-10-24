extends Button

@onready var audio_generator: AudioGenerator = $"../AudioGenerator"

var test: bool = true

func _ready():
	pressed.connect(_button_pressed)

func _button_pressed():
	if test:
		audio_generator.change_pitch(440.0)
	else:
		audio_generator.change_pitch(261.63)
	test = !test
