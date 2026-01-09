using Godot;
using System;

// [Tool]
public partial class WaveCascadeParameters : Resource
{
    // Signal equivalent in C#
    [Signal]
    public delegate void ScaleChangedEventHandler();

    // Private backing fields for properties with custom setters
    private Vector2 _tileLength = new Vector2(50, 50);
    private float _displacementScale = 1.0f;
    private float _normalScale = 1.0f;
    private float _windSpeed = 20.0f;
    private float _windDirection = 0.0f; // stored in radians internally
    private float _fetchLength = 550.0f;
    private float _swell = 0.8f;
    private float _spread = 0.2f;
    private float _detail = 1.0f;
    private float _whitecap = 0.5f;
    private float _foamAmount = 5.0f;

    // Public properties with [Export] and custom setters

    [Export(PropertyHint.None)]
    public Vector2 TileLength
    {
        get => _tileLength;
        set
        {
            _tileLength = value;
            ShouldGenerateSpectrum = true;
            EmitSignal(SignalName.ScaleChanged);
        }
    }

    [Export(PropertyHint.Range, "0,2")]
    public float DisplacementScale
    {
        get => _displacementScale;
        set
        {
            _displacementScale = value;
            EmitSignal(SignalName.ScaleChanged);
        }
    }

    [Export(PropertyHint.Range, "0,2")]
    public float NormalScale
    {
        get => _normalScale;
        set
        {
            _normalScale = value;
            EmitSignal(SignalName.ScaleChanged);
        }
    }

    [Export(PropertyHint.None)]
    public float WindSpeed
    {
        get => _windSpeed;
        set
        {
            _windSpeed = Mathf.Max(0.0001f, value);
            ShouldGenerateSpectrum = true;
        }
    }

    [Export(PropertyHint.Range, "-360,360")]
    public float WindDirectionDegrees
    {
        get => Mathf.RadToDeg(_windDirection);
        set
        {
            _windDirection = Mathf.DegToRad(value);
            ShouldGenerateSpectrum = true;
        }
    }

    [Export(PropertyHint.None)]
    public float FetchLength
    {
        get => _fetchLength;
        set
        {
            _fetchLength = Mathf.Max(0.0001f, value);
            ShouldGenerateSpectrum = true;
        }
    }

    [Export(PropertyHint.Range, "0,2")]
    public float Swell
    {
        get => _swell;
        set
        {
            _swell = value;
            ShouldGenerateSpectrum = true;
        }
    }

    [Export(PropertyHint.Range, "0,1")]
    public float Spread
    {
        get => _spread;
        set
        {
            _spread = value;
            ShouldGenerateSpectrum = true;
        }
    }

    [Export(PropertyHint.Range, "0,1")]
    public float Detail
    {
        get => _detail;
        set
        {
            _detail = value;
            ShouldGenerateSpectrum = true;
        }
    }

    [Export(PropertyHint.Range, "0,2")]
    public float Whitecap
    {
        get => _whitecap;
        set
        {
            _whitecap = value;
            ShouldGenerateSpectrum = true;
        }
    }

    [Export(PropertyHint.Range, "0,10")]
    public float FoamAmount
    {
        get => _foamAmount;
        set
        {
            _foamAmount = value;
            ShouldGenerateSpectrum = true;
        }
    }

    // Internal state variables (not exported)
    public Vector2I SpectrumSeed { get; set; } = Vector2I.Zero;
    public bool ShouldGenerateSpectrum { get; set; } = true;

    public float Time { get; set; }
    public float FoamGrowRate { get; set; }
    public float FoamDecayRate { get; set; }

    // ImGui / debug references (mirroring values for UI tools)
    // These are not automatically synced — must be updated manually if used in editor tools.
    public float[] _TileLengthRef => new float[] { _tileLength.X, _tileLength.Y };
    public float[] _DisplacementScaleRef => new float[] { _displacementScale };
    public float[] _NormalScaleRef => new float[] { _normalScale };
    public float[] _WindSpeedRef => new float[] { _windSpeed };
    public float[] _WindDirectionRef => new float[] { _windDirection }; // in radians
    public float[] _FetchLengthRef => new float[] { _fetchLength };
    public float[] _SwellRef => new float[] { _swell };
    public float[] _SpreadRef => new float[] { _spread };
    public float[] _DetailRef => new float[] { _detail };
    public float[] _WhitecapRef => new float[] { _whitecap };
    public float[] _FoamAmountRef => new float[] { _foamAmount };

    // Optional: Constructor to mimic _init()
    public WaveCascadeParameters()
    {
        // You can initialize here if needed
    }
}