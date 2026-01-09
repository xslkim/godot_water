using Godot;
using System;
using Godot.Collections;
using System.Collections.Generic;

// [Tool]
public partial class Water : MeshInstance3D
{
	// const string WATER_MAT = "res://assets/water/mat_water.tres";
	// const string SPRAY_MAT = "res://assets/water/mat_spray.tres";
	const string WATER_MESH_HIGH = "res://assets/water/clipmap_high.obj";
	const string WATER_MESH_LOW = "res://assets/water/clipmap_low.obj";	

	// Material waterMat = GD.Load<Material>(WATER_MAT);
	// Material sprayMat = GD.Load<Material>(SPRAY_MAT);

	public enum WaterQuality
	{
		High,
		Low
	}

	Color _waterColor = Colors.Blue;
	[Export]
	public Color WaterColor
    {
        get { return _waterColor; }
		set {
			 _waterColor = value; 
			 RenderingServer.GlobalShaderParameterSet("water_color", _waterColor);
			 }	
    }

	Color _foamColor = Colors.White;
	[Export]
	public Color FoamColor
	{
		get { return _foamColor; }
		set
		{
			_foamColor = value;
			RenderingServer.GlobalShaderParameterSet("foam_color", _foamColor);
		}
	}

	WaterQuality quality = WaterQuality.High;
	public WaterQuality Quality
	{
		get { return quality; }
		set
		{
			quality = value;
			switch (quality)
			{
				case WaterQuality.High:
					Mesh = GD.Load<Mesh>(WATER_MESH_HIGH);
					break;
				case WaterQuality.Low:
					Mesh = GD.Load<Mesh>(WATER_MESH_LOW);
					break;
			}
		}
	}

	[Export]
    public Array<WaveCascadeParameters> WaveCascades = new Array<WaveCascadeParameters>();

	public override void _Ready()
    {
		

    }

	// Called every frame. 'delta' is the elapsed time since the previous frame.
	public override void _Process(double delta)
	{
	}
}
