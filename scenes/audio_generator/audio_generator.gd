class_name AudioGenerator
extends Node

# The C# script node must be a child of this node
@onready var csharp_node_ref = $CSharpNode

# This array tracks which notes are currently held down.
# The last note in the array is the one that gets played.
var note_stack: Array[float] = []

func _ready():
	if csharp_node_ref == null:
		printerr("AudioGenerator: Could not find $CSharpNode!")

## Called by your 'Instrument.gd' when a button is pressed.
func note_on(hz: float):
	if csharp_node_ref == null: return

	# Add the new note to the top of the stack
	note_stack.push_back(hz)
	
	# Tell the C# engine to play this new note
	csharp_node_ref.NoteOn(hz)

## Called by your 'Instrument.gd' when a button is released.
func note_off(hz: float):
	if csharp_node_ref == null: return

	# Find and remove the released note from the stack
	# This handles the case where an *older* note is released
	# while a newer one is still held down.
	note_stack.erase(hz)
	
	if note_stack.is_empty():
		# No notes left, tell the engine to fade out
		csharp_node_ref.NoteOff()
	else:
		# A note is still held, play the *newest* one
		# (which is the last item in the array).
		csharp_node_ref.NoteOn(note_stack.back())
