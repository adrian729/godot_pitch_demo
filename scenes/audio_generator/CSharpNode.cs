using Godot;

public partial class CSharpNode : Node
{
	[Export] public AudioStreamPlayer Player { get; set; }

	private AudioStreamGeneratorPlayback _playback;
	private float _sampleHz;

	// --- Synth State ---
	private float _pulseHz = 440.0f;
	private float _phase = 0.0f;

	// --- Two Envelopes ---
	private float _amplitude = 0.0f;
	private float _targetAmplitude = 0.0f;
	private float _amplitudeStep;

	private float _noiseAmplitude = 0.0f;
	private float _noiseStep;

	// --- Pre-generated Noise Buffer ---
	private float[] _noiseBuffer;
	private int _noisePhase = 0;
	private RandomNumberGenerator _noiseGen = new RandomNumberGenerator();

	// --- Sustained Breath Amount ---
	private const float SUSTAINED_BREATH_AMOUNT = 0.015f;

	public override void _Ready()
	{
		if (Player == null)
		{
			GD.PrintErr("CSharpNode: AudioStreamPlayer not assigned!");
			return;
		}

		AudioStreamGenerator generator = Player.Stream as AudioStreamGenerator;
		if (generator == null)
		{
			generator = new AudioStreamGenerator();
			Player.Stream = generator;
		}

		generator.BufferLength = 0.02f; // Keep 20ms buffer for now

		// --- INCREASED MIX RATE ---
		_sampleHz = generator.MixRate = 44100.0f; // Increase to CD quality
		// --------------------------

		Player.VolumeDb = -12.0f;

		// --- RECALCULATE ENVELOPE STEPS for new sample rate ---
		_amplitudeStep = 1.0f / (0.015f * _sampleHz); // Tone fade (~15ms)
		_noiseStep = 1.0f / (0.008f * _sampleHz);     // Chiff fade (~8ms)
		// ----------------------------------------------------

		// --- Fill the noise buffer (NOW NEEDS 44100 samples) ---
		_noiseBuffer = new float[(int)_sampleHz];
		_noiseGen.Randomize();
		for (int i = 0; i < _noiseBuffer.Length; i++)
		{
			_noiseBuffer[i] = (_noiseGen.Randf() - 0.5f); // Noise between -0.5 and 0.5
		}

		Player.Play();
		_playback = (AudioStreamGeneratorPlayback)Player.GetStreamPlayback();

		if (_playback == null)
		{
			GD.PrintErr("CSharpNode: Failed to get AudioStreamGeneratorPlayback!");
			return;
		}

		FillBuffer(); // Fill with initial silence
	}

	public override void _Process(double delta)
	{
		if (_playback != null)
		{
			FillBuffer();
		}
	}

	private float GetNoise()
	{
		float noise = _noiseBuffer[_noisePhase];
		_noisePhase = (_noisePhase + 1) % _noiseBuffer.Length;
		return noise;
	}

	public void FillBuffer()
	{
		if (_playback == null) return;

		float increment = _pulseHz / _sampleHz;
		int framesAvailable = _playback.GetFramesAvailable();

		for (int i = 0; i < framesAvailable; i++)
		{
			// --- 1. Handle TONE Envelope ---
			if (_amplitude < _targetAmplitude) _amplitude = Mathf.Min(_amplitude + _amplitudeStep, 1.0f);
			else if (_amplitude > _targetAmplitude) _amplitude = Mathf.Max(_amplitude - _amplitudeStep, 0.0f);

			// --- 2. Handle NOISE ("Chiff") Envelope ---
			if (_noiseAmplitude > 0.0f) _noiseAmplitude = Mathf.Max(_noiseAmplitude - _noiseStep, 0.0f);

			// --- 3. Generate the Sound ---

			// --- TONE: Rebalanced Flute Harmonic Recipe ---
			float phaseRad = _phase * Mathf.Tau; // Pre-calculate 2*PI*phase
			float s1 = Mathf.Sin(phaseRad * 1.0f);  // H1
			float s2 = Mathf.Sin(phaseRad * 2.0f);  // H2
			float s3 = Mathf.Sin(phaseRad * 3.0f);  // H3
			float s4 = Mathf.Sin(phaseRad * 4.0f);  // H4
			float s5 = Mathf.Sin(phaseRad * 5.0f);  // H5
			float s6 = Mathf.Sin(phaseRad * 6.0f);  // H6
			float s7 = Mathf.Sin(phaseRad * 7.0f);  // H7
			float s8 = Mathf.Sin(phaseRad * 8.0f);  // H8
			float s9 = Mathf.Sin(phaseRad * 9.0f);  // H9


			// New Mix giving more weight to upper harmonics:
			// H1=35%, H2=25%, H3=15%, H4=10%, H5=7%, H6=3%, H7=2%, H8=2%, H9=1% [Total=100%]
			float toneSample = (s1 * 0.35f) + (s2 * 0.25f) + (s3 * 0.15f) + (s4 * 0.10f) + (s5 * 0.07f)
							 + (s6 * 0.03f) + (s7 * 0.02f) + (s8 * 0.02f) + (s9 * 0.01f);

			float noiseSample = GetNoise();

			float toneWithBreath = toneSample + (noiseSample * SUSTAINED_BREATH_AMOUNT);
			float finalSample = (toneWithBreath * _amplitude) + (noiseSample * _noiseAmplitude * 0.7f);

			_playback.PushFrame(Vector2.One * Mathf.Clamp(finalSample, -1.0f, 1.0f));
			_phase = Mathf.PosMod(_phase + increment, 1.0f);
		}
	}

	public void NoteOn(float newHz)
	{
		if (_targetAmplitude == 0.0f)
		{
			_phase = 0.0f;
			_noiseAmplitude = 1.0f;
		}

		_pulseHz = newHz;
		_targetAmplitude = 1.0f;
	}

	public void NoteOff()
	{
		_targetAmplitude = 0.0f;
		_noiseAmplitude = 0.0f;
	}
}
