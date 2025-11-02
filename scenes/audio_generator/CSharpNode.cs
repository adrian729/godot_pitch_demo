using Godot;
using System.Collections.Generic;

public partial class CSharpNode : Node
{
	[Export] public AudioStreamPlayer Player { get; set; }

	private AudioStreamGeneratorPlayback _playback;
	private float _sampleHz;

	// --- Voice Structure ---
	private class Voice
	{
		public int MidiNote = -1;
		public float Frequency = 0.0f;
		public float Phase = 0.0f;
		public float Amplitude = 0.0f;        // Current TONE volume
		public float TargetAmplitude = 0.0f;  // Target TONE volume (velocity based)
		public float NoiseAmplitude = 0.0f;   // Current CHIFF volume
		public bool NeedsChiffTrigger = false; // Flag to trigger chiff noise
		public bool IsActive => MidiNote != -1;
	}

	// --- Voice Management ---
	private List<Voice> _voices = new List<Voice>();
	private const int MAX_VOICES = 8; // Max simultaneous notes (polyphony)

	// --- Global Envelope Speed ---
	private float _attackTime = 0.015f; // Tone attack
	private float _releaseTime = 0.1f;  // Tone release
	private float _noiseReleaseTime = 0.008f; // Chiff decay time
	private float _attackStep = 0.0f;
	private float _releaseStep = 0.0f;
	private float _noiseStep = 0.0f;

	// --- Pre-generated Noise Buffer ---
	private float[] _noiseBuffer;
	private int _noisePhase = 0;
	private RandomNumberGenerator _noiseGen = new RandomNumberGenerator();
	private const float SUSTAINED_BREATH_AMOUNT = 0.015f;

	public override void _Ready()
	{
		if (Player == null) { GD.PrintErr("CSharpNode: Player not assigned!"); return; }

		AudioStreamGenerator generator = Player.Stream as AudioStreamGenerator;
		if (generator == null)
		{
			generator = new AudioStreamGenerator();
			Player.Stream = generator;
		}

		generator.BufferLength = 0.02f; // Keep 20ms buffer
		_sampleHz = generator.MixRate = 44100.0f; // Use 44.1kHz
		Player.VolumeDb = -12.0f;

		// Calculate envelope steps
		_attackStep = 1.0f / (_attackTime * _sampleHz);
		_releaseStep = 1.0f / (_releaseTime * _sampleHz);
		_noiseStep = 1.0f / (_noiseReleaseTime * _sampleHz);

		// Initialize voices
		for (int i = 0; i < MAX_VOICES; i++) _voices.Add(new Voice());

		// Fill the noise buffer
		_noiseBuffer = new float[(int)_sampleHz];
		_noiseGen.Randomize();
		for (int i = 0; i < _noiseBuffer.Length; i++) _noiseBuffer[i] = (_noiseGen.Randf() - 0.5f);

		// Start Player (Always On)
		Player.Play();
		_playback = (AudioStreamGeneratorPlayback)Player.GetStreamPlayback();
		if (_playback == null) { GD.PrintErr("CSharpNode: Failed to get Playback!"); return; }
		GD.Print("CSharpNode Ready, Playback obtained.");
	}

	// --- Added _Process to drive FillBuffer ---
	public override void _Process(double delta)
	{
		if (Player.IsPlaying() && _playback != null)
		{
			FillBuffer();
		}
	}
	// ------------------------------------------

	private float GetNoise()
	{
		float noise = _noiseBuffer[_noisePhase];
		_noisePhase = (_noisePhase + 1) % _noiseBuffer.Length;
		return noise;
	}

	// Implicitly called by audio thread
	public void FillBuffer()
	{
		if (_playback == null) return;
		int framesAvailable = _playback.GetFramesAvailable();
		if (framesAvailable <= 0) return;

		for (int frame = 0; frame < framesAvailable; frame++)
		{
			float mixedSample = 0.0f;

			foreach (Voice voice in _voices)
			{
				// Skip silent, inactive voices
				if (!voice.IsActive && voice.Amplitude == 0.0f && voice.NoiseAmplitude == 0.0f) continue;

				// --- Trigger Chiff if needed ---
				if (voice.NeedsChiffTrigger)
				{
					voice.NoiseAmplitude = 1.0f; // Start chiff envelope
					voice.NeedsChiffTrigger = false;
				}

				// --- Handle TONE Envelope ---
				if (voice.Amplitude < voice.TargetAmplitude) voice.Amplitude = Mathf.Min(voice.Amplitude + _attackStep, voice.TargetAmplitude);
				else if (voice.Amplitude > voice.TargetAmplitude) voice.Amplitude = Mathf.Max(voice.Amplitude - _releaseStep, 0.0f);

				// --- Handle NOISE (Chiff) Envelope ---
				if (voice.NoiseAmplitude > 0.0f) voice.NoiseAmplitude = Mathf.Max(voice.NoiseAmplitude - _noiseStep, 0.0f);

				// If Tone & Chiff fade-out is complete after a NoteOff, mark voice inactive
				if (voice.TargetAmplitude == 0.0f && voice.Amplitude == 0.0f && voice.NoiseAmplitude == 0.0f && voice.IsActive)
				{
					voice.MidiNote = -1; // Free up the voice
					continue;
				}

				// --- Generate Flute Sound Sample for this voice ---
				float currentToneSample = 0.0f;
				float currentNoiseSample = GetNoise(); // Get noise value for breath/chiff

				if (voice.Amplitude > 0.0f) // Only calculate harmonics if tone is audible
				{
					float phaseRad = voice.Phase * Mathf.Tau;
					float s1 = Mathf.Sin(phaseRad * 1.0f); float s2 = Mathf.Sin(phaseRad * 2.0f);
					float s3 = Mathf.Sin(phaseRad * 3.0f); float s4 = Mathf.Sin(phaseRad * 4.0f);
					float s5 = Mathf.Sin(phaseRad * 5.0f); float s6 = Mathf.Sin(phaseRad * 6.0f);
					float s7 = Mathf.Sin(phaseRad * 7.0f); float s8 = Mathf.Sin(phaseRad * 8.0f);
					float s9 = Mathf.Sin(phaseRad * 9.0f);

					// Flute Recipe (richer version)
					// H1=35%, H2=25%, H3=15%, H4=10%, H5=7%, H6=3%, H7=2%, H8=2%, H9=1%
					currentToneSample = (s1 * 0.35f) + (s2 * 0.25f) + (s3 * 0.15f) + (s4 * 0.10f) + (s5 * 0.07f)
									  + (s6 * 0.03f) + (s7 * 0.02f) + (s8 * 0.02f) + (s9 * 0.01f);

					// Add sustained breath noise
					currentToneSample += (currentNoiseSample * SUSTAINED_BREATH_AMOUNT);

					// Advance phase only if tone is playing
					voice.Phase = Mathf.PosMod(voice.Phase + (voice.Frequency / _sampleHz), 1.0f);
				}

				// --- Mix Tone and Chiff components for this voice ---
				float voiceSample = (currentToneSample * voice.Amplitude) + (currentNoiseSample * voice.NoiseAmplitude * 0.7f);
				mixedSample += voiceSample;
			}

			// --- Push Mixed Frame ---
			mixedSample /= (MAX_VOICES * 0.5f); // Simple normalization
			_playback.PushFrame(Vector2.One * Mathf.Clamp(mixedSample, -1.0f, 1.0f));
		}
	}

	private static float MidiToFrequency(int midiNote) => Mathf.Pow(2.0f, (midiNote - 69.0f) / 12.0f) * 440.0f;

	// --- PUBLIC API ---
	public void NoteOn(int midiNote, int velocity)
	{
		if (velocity == 0) { NoteOff(midiNote); return; }

		float targetAmp = velocity / 127.0f;
		Voice voiceToUse = null;

		// 1. Find inactive voice
		foreach (Voice v in _voices) { if (!v.IsActive) { voiceToUse = v; break; } }
		// 2. If none, steal first voice
		if (voiceToUse == null) { voiceToUse = _voices[0]; GD.Print("Stole voice for note: " + midiNote); }

		// Setup voice
		voiceToUse.MidiNote = midiNote;
		voiceToUse.Frequency = MidiToFrequency(midiNote);
		voiceToUse.TargetAmplitude = targetAmp;

		// Trigger chiff only if starting from silence
		if (voiceToUse.Amplitude == 0.0f)
		{
			voiceToUse.Phase = 0.0f;
			voiceToUse.NeedsChiffTrigger = true; // Signal FillBuffer to start noise env
		} else {
			voiceToUse.NeedsChiffTrigger = false; // Ensure chiff doesn't trigger on legato
		}
	}

	public void NoteOff(int midiNote)
	{
		foreach (Voice v in _voices)
		{
			if (v.IsActive && v.MidiNote == midiNote)
			{
				v.TargetAmplitude = 0.0f; // Start tone release
				break;
			}
		}
	}

	public void AllNotesOff()
	{
		foreach (Voice v in _voices)
		{
			 v.TargetAmplitude = 0.0f;
			 v.NoiseAmplitude = 0.0f; // Immediately cut noise
			 v.NeedsChiffTrigger = false;
		}
	}
}
