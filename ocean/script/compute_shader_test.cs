using Godot;
using System;

public partial class compute_shader_test : Node
{

	[Export]
	public SubViewport left_viewport;
	public SubViewport right_viewport;

	RenderingDevice rd;
	Rid csBuffer;
	Texture2D left_texture;
	Texture2D right_texture;
	float[] input = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];

	void cs_init()
	{
		rd = RenderingServer.CreateLocalRenderingDevice();

		RDShaderFile shaderFile = GD.Load<RDShaderFile>("res://shaders/compute_example.glsl");
		RDShaderSpirV shaderBytecode = shaderFile.GetSpirV();
		Rid shader = rd.ShaderCreateFromSpirV(shaderBytecode);

		
		byte[] inputBytes = new byte[input.Length * sizeof(float)];
		Buffer.BlockCopy(input, 0, inputBytes, 0, inputBytes.Length);

		csBuffer = rd.StorageBufferCreate((uint)inputBytes.Length, inputBytes);

		RDUniform uniform = new RDUniform
		{
			UniformType = RenderingDevice.UniformType.StorageBuffer,
			Binding = 0
		};
		uniform.AddId(csBuffer);
		var uniformSet = rd.UniformSetCreate([uniform], shader, 0);


		Rid pipeline = rd.ComputePipelineCreate(shader);
		long computeList = rd.ComputeListBegin();
		rd.ComputeListBindComputePipeline(computeList, pipeline);
		rd.ComputeListBindUniformSet(computeList, uniformSet, 0);
		rd.ComputeListDispatch(computeList, xGroups: 5, yGroups: 1, zGroups: 1);
		rd.ComputeListEnd();
	}


	void csExe()
	{
		rd.Submit();
		rd.Sync();
		byte[] outputBytes = rd.BufferGetData(csBuffer);
		float[] output = new float[input.Length];
		Buffer.BlockCopy(outputBytes, 0, output, 0, outputBytes.Length);
		GD.Print("Input: ", string.Join(", ", input));
		GD.Print("Output: ", string.Join(", ", output));
	}

	

	public override void _Ready()
	{
		cs_init();
	}

	public override void _Process(double delta)
	{
		csExe();
	}
}
