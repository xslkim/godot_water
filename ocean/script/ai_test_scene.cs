using Godot;
using System;
using System.Runtime.InteropServices;


public partial class ai_test_scene : Node
{

	[Export]
	public SubViewport left_viewport;

    [Export]
	public SubViewport front_viewport;

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
    private Rid frontStorageTex;
    private Rid rightStorageTex;

	private Rid leftDefaultTexRid;
    private Rid frontDefaultTexRid;
    private Rid rightDefaultTexRid;

    float outputWidth;
    float outputHeight;
    bool isInitialized = false;
	public override void _Ready()
    {
        outputWidth = resultDisplay.GetRect().Size.X;
        outputHeight = resultDisplay.GetRect().Size.Y;
        // 获取 SubViewport 默认纹理的 RID（只读，无 StorageBit）
        Rid leftVP = left_viewport.GetViewportRid();
        Rid frontVP = front_viewport.GetViewportRid();
        Rid rightVP = right_viewport.GetViewportRid();

        leftDefaultTexRid = RenderingServer.ViewportGetTexture(leftVP);
        frontDefaultTexRid = RenderingServer.ViewportGetTexture(frontVP);
        rightDefaultTexRid = RenderingServer.ViewportGetTexture(rightVP);

        // 等待一帧确保纹理已创建
        GetTree().CreateTimer(0).Timeout += InitializeAfterFirstFrame;
    }


    [StructLayout(LayoutKind.Sequential, Pack = 4)] // 4字节对齐
    public struct CameraParameter
    {
        public Vector4 position;
        public Vector4 rotation; 

        public float fx;         // 4 bytes
        public float fy;         // 4 bytes
        public float cx;         // 4 bytes
        public float cy;         // 4 bytes
        public float w;         // 4 bytes
        public float h;         // 4 bytes

        private float _padding1; // offset 36
        private float _padding2; // offset 40
        
        
        public CameraParameter()
        {
            rotation.X = 0;
            rotation.Y = 0;
            rotation.Z = 0;
            position.X = 0;
            position.Y = 0;
            position.Z = 0;
            w = 1920;
            h = 1080;
            fx = 1967f;
            fy = 1967f;
            cx = 960;
            cy = 540;
        }
    }

    [StructLayout(LayoutKind.Sequential, Pack = 4)]
    public struct ComputeUniforms
    {
        public CameraParameter left_camera;
        public CameraParameter front_camera;
        public CameraParameter right_camera;

        public ComputeUniforms()
        {
            left_camera = new CameraParameter();
            front_camera = new CameraParameter();
            right_camera = new CameraParameter();
        }
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

        frontStorageTex = rd.TextureCreate(new RDTextureFormat
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
            Width = (uint)outputWidth,
            Height = (uint)outputHeight,
            Format = format,
            UsageBits = usage
        }, new RDTextureView());

		var shaderFile = GD.Load<RDShaderFile>("res://shaders/ai_testure_merge.glsl");
        shader = rd.ShaderCreateFromSpirV(shaderFile.GetSpirV());


		var uniforms = new Godot.Collections.Array<RDUniform>();

		var uniformLeft = new RDUniform
		{
			UniformType = RenderingDevice.UniformType.Texture,
			Binding = 0,
		};
		uniformLeft.AddId(leftStorageTex);
		uniforms.Add(uniformLeft);

        var uniformFront = new RDUniform
		{
			UniformType = RenderingDevice.UniformType.Texture,
			Binding = 1,
		};
		uniformFront.AddId(frontStorageTex);
		uniforms.Add(uniformFront);

		var uniformRight = new RDUniform
		{
			UniformType = RenderingDevice.UniformType.Texture,
			Binding = 2,
		};
		uniformRight.AddId(rightStorageTex);
		uniforms.Add(uniformRight);

		var uniformOutput = new RDUniform
		{
			UniformType = RenderingDevice.UniformType.Image,
			Binding = 3,
		};
		uniformOutput.AddId(outputTexRid);
		uniforms.Add(uniformOutput);

        

        computeUniforms = new ComputeUniforms();
        initComputeUniforms(ref computeUniforms);
        
        // 计算结构体大小并预分配字节数组
        _uniformSize = Marshal.SizeOf<ComputeUniforms>();
        _uniformBytes = new byte[_uniformSize];
        
        UpdateUniformBufferData(computeUniforms);
        _uniformBuffer = rd.UniformBufferCreate((uint)_uniformSize, _uniformBytes);

        
        var uniformParams = new RDUniform
        {
            UniformType = RenderingDevice.UniformType.UniformBuffer,
            Binding = 4,
        };
        uniformParams.AddId(_uniformBuffer);
        uniforms.Add(uniformParams);
        


		// 创建 UniformSet
		uniformSet = rd.UniformSetCreate(uniforms, shader, 0);

		// 创建 Compute Pipeline
		pipeline = rd.ComputePipelineCreate(shader);

        isInitialized = true;
	}

    void initComputeUniforms(ref ComputeUniforms uniforms)
    {
        uniforms.left_camera.rotation.Y = 45f;
        uniforms.front_camera.rotation.Y = 0f;
        uniforms.right_camera.rotation.Y = -45f;
    }

    Rid _uniformBuffer;

    private byte[] _uniformBytes;

    int _uniformSize = Marshal.SizeOf<ComputeUniforms>();

    
    ComputeUniforms computeUniforms;
        

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
        var frontTex = front_viewport.GetTexture();
        var rightTex = right_viewport.GetTexture();

        if (leftTex == null || rightTex == null || frontTex == null) return;

        Image leftImg = leftTex.GetImage();
        Image rightImg = rightTex.GetImage();
        Image frontImg = frontTex.GetImage();


        if (leftImg == null || rightImg == null) return;

        // Upload to storage textures using the correct API
        UploadImageDataToTexture(leftStorageTex, leftImg);
        UploadImageDataToTexture(frontStorageTex, frontImg);
        UploadImageDataToTexture(rightStorageTex, rightImg);


        uint gx = (uint)Math.Ceiling(outputWidth / 8f);
        uint gy = (uint)Math.Ceiling(outputHeight / 8f);

        long computeList = rd.ComputeListBegin();
        rd.ComputeListBindComputePipeline(computeList, pipeline);
        rd.ComputeListBindUniformSet(computeList, uniformSet, 0);
        rd.ComputeListDispatch(computeList, gx, gy, 1);
        rd.ComputeListEnd();

        rd.Submit();
        rd.Sync();

        // Get result and display
        byte[] resultData = rd.TextureGetData(outputTexRid, 0);
        Image resultImg = Image.CreateFromData((int)outputWidth, (int)outputHeight, false, Image.Format.Rgba8, resultData);
        resultDisplay.Texture = ImageTexture.CreateFromImage(resultImg);
    }

    private void UpdateUniformBufferData(ComputeUniforms uniforms)
    {
        IntPtr ptr = Marshal.AllocHGlobal(_uniformSize);
        try
        {
            Marshal.StructureToPtr(uniforms, ptr, false);
            Marshal.Copy(ptr, _uniformBytes, 0, _uniformSize);
            GD.Print("Uniform buffer updated.");
        }
        finally
        {
            Marshal.FreeHGlobal(ptr);
        }
    }

    // [Export]
    // public float fov_x = 52f;
    //[Export]
    //public float rotate_y = 45f;

    [Export]
    public Node3D rightCamera;

    //[Export]
    //public float left_gate = 1670f;

    [Export]
    public float right_gate = 1920f;

    [Export]
    public float x_rate = 1;
    [Export]
    public float y_rate = 1;

	static int frameCount = 1;
	public override void _Process(double delta)
	{
        if(isInitialized == false || rd == null)
            return;
		if(frameCount++ % 2 == 0)
		{
            UpdateUniformBufferData(computeUniforms);
        
            rd.BufferUpdate(_uniformBuffer, 0, (uint)_uniformBytes.Length, _uniformBytes);
			ExecuteComputeDispatch();
		}
	}
}
