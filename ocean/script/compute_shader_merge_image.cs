using Godot;
using System;

public partial class compute_shader_merge_image : Node
{

	[Export]
	public SubViewport left_viewport;

	[Export]
	public SubViewport right_viewport;

	RenderingDevice rd;
	Rid csBuffer;
	Texture2D left_texture;
	Texture2D right_texture;

	private Rid shader;
    private Rid pipeline;
    private Rid uniformSet;
	void cs_init()
	{
		rd = RenderingServer.CreateLocalRenderingDevice();

		// 加载 compute shader
		RDShaderFile shaderFile = GD.Load<RDShaderFile>("res://shaders/texture_merge.glsl");
		RDShaderSpirV shaderBytecode = shaderFile.GetSpirV();
		shader = rd.ShaderCreateFromSpirV(shaderBytecode);

		// 获取输入纹理的 Rid（确保在 _Ready 中已赋值）
		Rid left_tex_rid = left_texture.GetRid();
		Rid right_tex_rid = right_texture.GetRid();

		// 创建 Uniforms
		var uniforms = new Godot.Collections.Array<RDUniform>();

		var uniformLeft = new RDUniform
		{
			UniformType = RenderingDevice.UniformType.Sampler,
			Binding = 0,
		};
		uniformLeft.AddId(left_tex_rid);
		uniforms.Add(uniformLeft);

		var uniformRight = new RDUniform
		{
			UniformType = RenderingDevice.UniformType.Sampler,
			Binding = 1,
		};
		uniformRight.AddId(right_tex_rid);
		uniforms.Add(uniformRight);

		var uniformOutput = new RDUniform
		{
			UniformType = RenderingDevice.UniformType.Image,
			Binding = 2,
		};
		uniformOutput.AddId(output_tex);
		uniforms.Add(uniformOutput);

		// 创建 UniformSet
		uniformSet = rd.UniformSetCreate(uniforms, shader, 0);

		// 创建 Compute Pipeline
		pipeline = rd.ComputePipelineCreate(shader);

	}

	void executeComputeDispatch()
	{
		int width = left_texture.GetWidth();
		int height = left_texture.GetHeight();

		const int LOCAL_SIZE_X = 8;
		const int LOCAL_SIZE_Y = 8;

		uint groupsX = (uint)Math.Ceiling((float)width / LOCAL_SIZE_X);
		uint groupsY = (uint)Math.Ceiling((float)height / LOCAL_SIZE_Y);

		long computeList = rd.ComputeListBegin();
		rd.ComputeListBindComputePipeline(computeList, pipeline);
		rd.ComputeListBindUniformSet(computeList, uniformSet, 0);
		rd.ComputeListDispatch(computeList, groupsX, groupsY, 1);
		rd.ComputeListEnd();

		rd.Submit();
		rd.Sync(); // 确保完成（如需读回数据）
	}

	static int frameCount = 0;
	void csExe()
	{	
		if(frameCount++ % 30 == 0)
		{
			executeComputeDispatch();
		}
			
		
	}

	Rid left_tex_rid;
	Rid right_tex_rid;
	Rid output_tex;
	public override void _Ready()
	{
		left_texture = left_viewport.GetTexture();
		right_texture = right_viewport.GetTexture();

		Rid left_tex_rid = left_texture.GetRid();
		Rid right_tex_rid = right_texture.GetRid();

		int width = left_texture.GetWidth();
		int height = left_texture.GetHeight();

		// ✅ 正确的 DataFormat 名称（Vulkan 风格）
		var format = RenderingDevice.DataFormat.R8G8B8A8Unorm;

		// ✅ TextureUsageBits 是枚举，直接用 | 组合
		var usage = RenderingDevice.TextureUsageBits.StorageBit |
					RenderingDevice.TextureUsageBits.CanUpdateBit |
					RenderingDevice.TextureUsageBits.CanCopyFromBit;

		Rid output_tex = rd.TextureCreate(
			new RDTextureFormat()
			{
				Width = (uint)width,
				Height = (uint)height,
				Format = format,
				UsageBits = usage  // ← 直接传枚举，不转 uint
			},
			new RDTextureView()
		);

		// 保存 output_tex 到成员变量（后续要用）
		this.output_tex = output_tex;

		cs_init(); // 注意：你现在的 cs_init() 还是旧 buffer 版本，需要重写！
	}

	public override void _Process(double delta)
	{
		
		csExe();
	}
}
