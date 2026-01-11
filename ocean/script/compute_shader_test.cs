using Godot;
using System;

public partial class compute_shader_test : Node
{
	// Create a local rendering device.
	RenderingDevice rd;
	// Called when the node enters the scene tree for the first time.
	public override void _Ready()
	{
		rd = RenderingServer.CreateLocalRenderingDevice();
		// Load GLSL shader
		RDShaderFile shaderFile = GD.Load<RDShaderFile>("res://shaders/compute_example.glsl");
		RDShaderSpirV shaderBytecode = shaderFile.GetSpirV();
		Rid shader = rd.ShaderCreateFromSpirV(shaderBytecode);

		float[] input = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
		byte[] inputBytes = new byte[input.Length * sizeof(float)];
		Buffer.BlockCopy(input, 0, inputBytes, 0, inputBytes.Length);

		Rid buffer = rd.StorageBufferCreate((uint)inputBytes.Length, inputBytes);

		RDUniform uniform = new RDUniform
		{
			UniformType = RenderingDevice.UniformType.StorageBuffer,
			Binding = 0
		};
		uniform.AddId(buffer);
		var uniformSet = rd.UniformSetCreate([uniform], shader, 0);

		// Create a compute pipeline
		Rid pipeline = rd.ComputePipelineCreate(shader);
		long computeList = rd.ComputeListBegin();
		rd.ComputeListBindComputePipeline(computeList, pipeline);
		rd.ComputeListBindUniformSet(computeList, uniformSet, 0);
		rd.ComputeListDispatch(computeList, xGroups: 5, yGroups: 1, zGroups: 1);
		rd.ComputeListEnd();

		// Submit to GPU and wait for sync
		rd.Submit();
		rd.Sync();

		// Read back the data from the buffers
		byte[] outputBytes = rd.BufferGetData(buffer);
		float[] output = new float[input.Length];
		Buffer.BlockCopy(outputBytes, 0, output, 0, outputBytes.Length);
		GD.Print("Input: ", string.Join(", ", input));
		GD.Print("Output: ", string.Join(", ", output));
	}

	// Called every frame. 'delta' is the elapsed time since the previous frame.
	public override void _Process(double delta)
	{
	}
}
