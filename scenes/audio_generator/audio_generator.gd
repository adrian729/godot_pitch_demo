class_name AudioGenerator
extends Node

@onready var csharp_node_ref = $CSharpNode

func _ready():
	if csharp_node_ref == null:
		printerr("AudioGenerator: Could not find $CSharpNode!")

func note_on(midi_note_number: int, velocity: int):
	if csharp_node_ref:
		csharp_node_ref.NoteOn(midi_note_number, velocity)

func note_off(midi_note_number: int):
	if csharp_node_ref:
		csharp_node_ref.NoteOff(midi_note_number)

func all_notes_off():
	if csharp_node_ref:
		csharp_node_ref.AllNotesOff()
