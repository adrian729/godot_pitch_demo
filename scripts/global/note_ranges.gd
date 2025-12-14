extends Node

## A Singleton that provides a pre-calculated MIDI note-to-frequency mapping table.
## Tuning is determined by the BASE_A_FREQUENCY constant.
## The note table is generated once at startup.

# SETUP: To make this script work as a global Singleton, add it to your Autoloads.
# 1. Go to Project -> Project Settings -> Globals.
# 2. Select the "AutoLoad" tab.
# 3. For "Path", select this script file.
# 4. For "Node Name", enter "NoteRanges".
# 5. Click "Add".

enum NoteData { MIDI, NAME, FREQ, LOW_BOUND, HIGH_BOUND }

# === Constants ===
const BASE_A4_FREQUENCY: float = 440.0

const SEMITONES_PER_OCTAVE: int = 12
const MIDI_A4: int = 69
const MIN_MIDI_NOTE: int = 21
const MAX_MIDI_NOTE: int = 127

const NOTE_NAMES = [
	"C", "C# / Db", "D", "D# / Eb", "E", "F",
	"F# / Gb", "G", "G# / Ab", "A", "A# / Bb", "B"
]

# === Note Table ===
var note_table: Array


func _ready():
	populate_table()


# === Private Methods ===
func populate_table():
	note_table.resize(MAX_MIDI_NOTE + 1)

	var current_lower_bound: float
	if MIN_MIDI_NOTE > 0:
		current_lower_bound = get_mid_freq(get_freq(MIN_MIDI_NOTE - 1), get_freq(MIN_MIDI_NOTE))
	else:
		current_lower_bound = 0.0
	
	for midi_note in range(MIN_MIDI_NOTE, MAX_MIDI_NOTE + 1):
		var octave := int(floor((midi_note - SEMITONES_PER_OCTAVE) / float(SEMITONES_PER_OCTAVE)))
		var note_name := "%s%d" % [NOTE_NAMES[midi_note % SEMITONES_PER_OCTAVE], octave]
		var freq := get_freq(midi_note)
		
		var freq_next := get_freq(midi_note + 1)
		var upper_bound := get_mid_freq(freq, freq_next)
		
		note_table[midi_note] = [midi_note, note_name, freq, current_lower_bound, upper_bound]

		current_lower_bound = upper_bound


static func validate_midi_note_in_range(midi_note: int, extended_range: bool = false) -> bool:
	var min_range = MIN_MIDI_NOTE - 1 if extended_range else MIN_MIDI_NOTE
	var max_range = MAX_MIDI_NOTE + 1 if extended_range else MAX_MIDI_NOTE
	
	var is_valid := midi_note >= min_range and midi_note <= max_range
	
	if not is_valid:
		push_error("MIDI note %d is out of the valid range (%d to %d)." % [midi_note, min_range, max_range])
	
	return is_valid


# === Public API ===
func get_note_ranges() -> Array:
	return note_table

func get_max_frequency() -> float:
	if not note_table.is_empty() and note_table.size() > MAX_MIDI_NOTE:
		return note_table[MAX_MIDI_NOTE][NoteData.HIGH_BOUND]
	return 0.0


func get_midi_from_freq(freq: float) -> int:
	if freq <= 0:
		push_error("Frequency must be a positive value.")
		return -1
	
	var midi_float = SEMITONES_PER_OCTAVE * log(freq / BASE_A4_FREQUENCY) / log(2.0) + MIDI_A4
	var midi_note = int(round(midi_float))
	
	return clamp(midi_note, MIN_MIDI_NOTE, MAX_MIDI_NOTE)


static func get_freq(midi_note: int) -> float:
	if not validate_midi_note_in_range(midi_note, true):
		return 0.0
	
	return BASE_A4_FREQUENCY * pow(2.0, (midi_note - MIDI_A4) / float(SEMITONES_PER_OCTAVE))


func get_note_name(midi_note: int) -> String:
	if not validate_midi_note_in_range(midi_note):
		return ""

	var octave := int(floor((midi_note - SEMITONES_PER_OCTAVE) / float(SEMITONES_PER_OCTAVE)))
	return "%s%d" % [NOTE_NAMES[midi_note % SEMITONES_PER_OCTAVE], octave]


static func get_mid_freq(freq1: float, freq2: float) -> float:
	if freq1 < 0 or freq2 < 0:
		push_error("Frequencies must be non-negative.")
		return 0.0
	return sqrt(freq1 * freq2)
