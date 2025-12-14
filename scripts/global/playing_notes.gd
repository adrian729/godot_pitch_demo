extends Node

## Manages the state of all currently playing notes.
## Provides globally accessible enums (Tone, Dynamic) and helper functions
## for converting note/dynamic values. Emits signals for note_on/note_off.

# SETUP: To make this script work as a global Singleton, add it to your AutoLoads.
# 1. Go to Project -> Project Settings -> Globals.
# 2. Select the "AutoLoad" tab.
# 3. For "Path", select this script file.
# 4. For "Node Name", enter "PlayingNotes".
# 5. Click "Add".

signal note_on(tone: Tone, octave: int, dynamic: Dynamic, instrument_id: String)
signal note_off(tone: Tone, octave: int, instrument_id: String)


# TONE
enum Tone { C, C_SHARP, D, D_SHARP, E, F, F_SHARP, G, G_SHARP, A, A_SHARP, B }
const TONE_ENUM_TO_STRING = ["C", "C#/Db", "D", "D#/Eb", "E", "F", "F#/Gb", "G", "G#/Ab", "A", "A#/Bb", "B"]
const TONE_STRING_TO_ENUM = {
	"C": Tone.C,
	"C#": Tone.C_SHARP,
	"Db": Tone.C_SHARP,
	"C#/Db": Tone.C_SHARP,
	"D": Tone.D,
	"D#": Tone.D_SHARP,
	"Eb": Tone.D_SHARP,
	"D#/Eb": Tone.D_SHARP,
	"E": Tone.E,
	"F": Tone.F,
	"F#": Tone.F_SHARP,
	"Gb": Tone.F_SHARP,
	"F#/Gb": Tone.F_SHARP,
	"G": Tone.G,
	"G#": Tone.G_SHARP,
	"Ab": Tone.G_SHARP,
	"G#/Ab": Tone.G_SHARP,
	"A": Tone.A,
	"A#": Tone.A_SHARP,
	"Bb": Tone.A_SHARP,
	"A#/Bb": Tone.A_SHARP,
	"B": Tone.B
}

const C_MAJOR: Array[Tone] = [Tone.C, Tone.D, Tone.E, Tone.F, Tone.G, Tone.A, Tone.B]
const C_MAJOR_RELATIVE_OCTAVES: Array[int] = [0, 0, 0, 0, 0, 0, 0]
const A_MINOR: Array[Tone] = [Tone.A, Tone.B, Tone.C, Tone.D, Tone.E, Tone.F, Tone.G]
const A_MINOR_RELATIVE_OCTAVES: Array[int] = [0, 0, 1, 1, 1, 1, 1]


func tone_str_to_enum(tone_string: String) -> Tone:
	assert(TONE_STRING_TO_ENUM.has(tone_string), "Invalid note string: " + tone_string)
	return TONE_STRING_TO_ENUM[tone_string]


func tone_enum_to_str(tone_enum: Tone) -> String:
	assert(tone_enum >= 0 and tone_enum < TONE_ENUM_TO_STRING.size(), "Invalid note enum value: " + str(tone_enum))
	return TONE_ENUM_TO_STRING[tone_enum]


# DYNAMIC
enum Dynamic { SILENCE, PIANISSIMO, PIANO, MEZZO_PIANO, MEZZO_FORTE, FORTE, FORTISSIMO }

const DYNAMIC_TO_VEL = [0, 1, 3, 4, 5, 8, 10]
const DYNAMIC_ENUM_TO_STRING = ["silence", "pianissimo", "piano", "mezzo-piano", "mezzo-forte", "forte", "fortissimo"]


func dynamic_to_velocity(dynamic_enum: Dynamic) -> int:
	assert(dynamic_enum >= 0 and dynamic_enum < DYNAMIC_TO_VEL.size(), "Invalid dynamic enum value: " + str(dynamic_enum))
	return DYNAMIC_TO_VEL[dynamic_enum]


func velocity_to_dynamic(velocity_int: int) -> Dynamic:
	for i in range(DYNAMIC_TO_VEL.size() - 1, 0, -1):
		if velocity_int >= DYNAMIC_TO_VEL[i]:
			return i as Dynamic

	return Dynamic.SILENCE


func dynamic_to_str(dynamic_enum: Dynamic) -> String:
	assert(dynamic_enum >= 0 and dynamic_enum < DYNAMIC_ENUM_TO_STRING.size(), "Invalid dynamic enum value: " + str(dynamic_enum))
	return DYNAMIC_ENUM_TO_STRING[dynamic_enum]


# NOTES
class Note:
	var tone: Tone
	var octave: int
	var dynamic: Dynamic
	
	func _init(_tone: Tone, _octave: int, _dynamic: Dynamic = Dynamic.MEZZO_FORTE):
		assert(_octave >= 0, "Note octave cannot be negative. Received: " + str(_octave))
		self.tone = _tone
		self.octave = _octave
		self.dynamic = _dynamic

var playing_notes: Dictionary = {} # Key: instrument_id (String), Value: Array[Note]
var instruments_count: int = 0


func get_new_id() -> String:
	var id := 'instrument_%s' % instruments_count
	instruments_count += 1
	return id


func play_note(tone: Tone, octave: int, dynamic: Dynamic, instrument_id: String):
	assert(octave >= 0, "Octave cannot be negative.")
	stop_note(tone, octave, instrument_id)
	if dynamic == Dynamic.SILENCE:
		return

	if not playing_notes.has(instrument_id):
		playing_notes[instrument_id] = []

	var new_note = Note.new(tone, octave, dynamic)
	playing_notes[instrument_id].append(new_note)
	
	note_on.emit(tone, octave, dynamic, instrument_id)


func stop_note(tone: Tone, octave: int, instrument_id: String):
	if not playing_notes.has(instrument_id):
		return

	var notes_for_instrument: Array = playing_notes[instrument_id]
	
	# Iterate backwards to safely remove items
	for i in range(notes_for_instrument.size() - 1, -1, -1):
		var note: Note = notes_for_instrument[i]
		
		if note.tone == tone and note.octave == octave:
			notes_for_instrument.remove_at(i)
			note_off.emit(tone, octave, instrument_id)
			if notes_for_instrument.is_empty():
				playing_notes.erase(instrument_id)

			break


func note_to_semitone(note: Note) -> int:
	return note.octave * 12 + note.tone


func semitone_to_octave(semitone: int) -> int:
	return floori(float(semitone) / 12.0)


func semitone_to_tone(semitone: int) -> Tone:
	return semitone % 12 as PlayingNotes.Tone


func semitone_to_note(semitone: int, dynamic: Dynamic = Dynamic.MEZZO_FORTE) -> Note:
	assert(semitone >= 0, "Semitone value must be non-negative. Received: " + str(semitone))
	return Note.new(
		semitone_to_octave(semitone), 
		semitone_to_tone(semitone), 
		dynamic
	)


func add_semitones(note_in: Note, semitones: int) -> Note:
	var new_semitone = note_to_semitone(note_in) + semitones
	assert(new_semitone >= 0, "Resulting semitone value must be non-negative. Result: " + str(new_semitone))
	return semitone_to_note(
		new_semitone, 
		note_in.dynamic
	)
