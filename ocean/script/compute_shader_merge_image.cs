using Godot;
using System;


public partial class compute_shader_merge_image : Node
{

	[Export]
	public SubViewport left_viewport;

	[Export]
	public SubViewport right_viewport;

	[Export]
	public TextureRect resultDisplay;
	

	RenderingDevice rd;
	private Rid outputTexRid;
	private Rid shader;
    private Rid pipeline;
    private Rid uniformSet;

// 中间存储纹理（带 StorageBit）
    private Rid leftStorageTex;
    private Rid rightStorageTex;

	private Rid leftDefaultTexRid;
    private Rid rightDefaultTexRid;

	public override void _Ready()
    {
        // 获取 SubViewport 默认纹理的 RID（只读，无 StorageBit）
        Rid leftVP = left_viewport.GetViewportRid();
        Rid rightVP = right_viewport.GetViewportRid();

        leftDefaultTexRid = RenderingServer.ViewportGetTexture(leftVP);
        rightDefaultTexRid = RenderingServer.ViewportGetTexture(rightVP);

        // 等待一帧确保纹理已创建
        GetTree().CreateTimer(0).Timeout += InitializeAfterFirstFrame;
    }

	void InitializeAfterFirstFrame()
	{
		if (!leftDefaultTexRid.IsValid || !rightDefaultTexRid.IsValid)
        {
            GD.PrintErr("Failed to get viewport textures.");
            return;
        }

		rd = RenderingServer.CreateLocalRenderingDevice();

        // 获取尺寸
        var tex2D = left_viewport.GetTexture();
        int width = tex2D.GetWidth();
        int height = tex2D.GetHeight();

        var format = RenderingDevice.DataFormat.R8G8B8A8Unorm;
        var usage = RenderingDevice.TextureUsageBits.StorageBit |
                    RenderingDevice.TextureUsageBits.CanUpdateBit |
                    RenderingDevice.TextureUsageBits.CanCopyFromBit |
                    RenderingDevice.TextureUsageBits.SamplingBit |
                    RenderingDevice.TextureUsageBits.CanCopyToBit;

        // 创建带 StorageBit 的中间纹理
        leftStorageTex = rd.TextureCreate(new RDTextureFormat
        {
            Width = (uint)width,
            Height = (uint)height,
            Format = format,
            UsageBits = usage
        }, new RDTextureView());

        rightStorageTex = rd.TextureCreate(new RDTextureFormat
        {
            Width = (uint)width,
            Height = (uint)height,
            Format = format,
            UsageBits = usage
        }, new RDTextureView());

        // 输出纹理
        outputTexRid = rd.TextureCreate(new RDTextureFormat
        {
            Width = (uint)width,
            Height = (uint)height,
            Format = format,
            UsageBits = usage
        }, new RDTextureView());

		var shaderFile = GD.Load<RDShaderFile>("res://shaders/texture_merge.glsl");
        shader = rd.ShaderCreateFromSpirV(shaderFile.GetSpirV());


		var uniforms = new Godot.Collections.Array<RDUniform>();

		var uniformLeft = new RDUniform
		{
			UniformType = RenderingDevice.UniformType.Texture,
			Binding = 0,
		};
		uniformLeft.AddId(leftStorageTex);
		uniforms.Add(uniformLeft);

		var uniformRight = new RDUniform
		{
			UniformType = RenderingDevice.UniformType.Texture,
			Binding = 1,
		};
		uniformRight.AddId(rightStorageTex);
		uniforms.Add(uniformRight);

		var uniformOutput = new RDUniform
		{
			UniformType = RenderingDevice.UniformType.Image,
			Binding = 2,
		};
		uniformOutput.AddId(outputTexRid);
		uniforms.Add(uniformOutput);

		// 创建 UniformSet
		uniformSet = rd.UniformSetCreate(uniforms, shader, 0);

		// 创建 Compute Pipeline
		pipeline = rd.ComputePipelineCreate(shader);

	}
   	private void UploadImageDataToTexture(Rid texture, Image image)
    {
        if (image.GetFormat() != Image.Format.Rgba8)
        {
            image.Convert(Image.Format.Rgba8); // 将 Rgb8 -> Rgba8
        }
        // Get raw pixel data as byte arrayCreateLocalRenderingDevice
        byte[] data = image.GetData();
        // Update the RD texture with this data (layer 0 for 2D texture)
        Error err = rd.TextureUpdate(texture, 0, data);
        if (err != Error.Ok)
        {
            GD.PrintErr($"Failed to update texture: {err}");
        }
    }

    private void ExecuteComputeDispatch()
    {
        var leftTex = left_viewport.GetTexture();
        var rightTex = right_viewport.GetTexture();

        if (leftTex == null || rightTex == null) return;

        Image leftImg = leftTex.GetImage();
        Image rightImg = rightTex.GetImage();

        //GD.Print($"Left Image Format: {leftImg.GetFormat()}, Size: {leftImg.GetData().Length} bytes");
        //GD.Print($"Right Image Format: {rightImg.GetFormat()}, Size: {rightImg.GetData().Length} bytes");

        if (leftImg == null || rightImg == null) return;

        // Upload to storage textures using the correct API
        UploadImageDataToTexture(leftStorageTex, leftImg);
        UploadImageDataToTexture(rightStorageTex, rightImg);

        // Dispatch compute
        int width = leftTex.GetWidth();
        int height = leftTex.GetHeight();
        uint gx = (uint)Math.Ceiling(width / 8f);
        uint gy = (uint)Math.Ceiling(height / 8f);

        long computeList = rd.ComputeListBegin();
        rd.ComputeListBindComputePipeline(computeList, pipeline);
        rd.ComputeListBindUniformSet(computeList, uniformSet, 0);
        rd.ComputeListDispatch(computeList, gx, gy, 1);
        rd.ComputeListEnd();

        rd.Submit();
        rd.Sync();

        // Get result and display
        byte[] resultData = rd.TextureGetData(outputTexRid, 0);
        Image resultImg = Image.CreateFromData(width, height, false, Image.Format.Rgba8, resultData);
        resultDisplay.Texture = ImageTexture.CreateFromImage(resultImg);
    }

	static int frameCount = 1;
	public override void _Process(double delta)
	{
		if(frameCount++ % 30 == 0)
		{
			ExecuteComputeDispatch();
		}
	}
}
