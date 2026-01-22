using Godot;
using System;
using System.IO;

public partial class AdvancedViewportSaver : Node
{
    [Export] public SubViewport TargetViewport { get; set; }
    [Export] public Key SaveKey { get; set; } = Key.F12;
    [Export] public string SaveDirectory { get; set; } = "user://screenshots/";
    [Export] public string FileNamePrefix { get; set; } = "screenshot";
    
    private bool _isSaving = false;
    
    public override void _Ready()
    {
        // 创建保存目录
        CreateSaveDirectory();
    }
    
    public override void _Process(double delta)
    {
        if (Input.IsKeyPressed(SaveKey) && !_isSaving)
        {
            _isSaving = true;
            SaveViewportTextureAsync();
        }
    }
    
    private async void SaveViewportTextureAsync()
    {
        if (TargetViewport == null)
        {
            GD.PrintErr("TargetViewport 未设置!");
            _isSaving = false;
            return;
        }
        
        try
        {
            // 等待一帧确保渲染完成
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
            
            // 获取纹理
            ViewportTexture texture = TargetViewport.GetTexture();
            if (texture == null)
            {
                throw new InvalidOperationException("无法获取 ViewportTexture");
            }
            
            // 获取图像
            Image image = texture.GetImage();
            if (image == null || image.IsEmpty())
            {
                throw new InvalidOperationException("图像数据为空");
            }
            
            // 可选：调整图像格式
            if (image.GetFormat() != Image.Format.Rgba8)
            {
                image.Convert(Image.Format.Rgba8);
            }
            
            // 生成文件名
            string timestamp = DateTime.Now.ToString("yyyy-MM-dd_HH-mm-ss");
            string fileName = $"{FileNamePrefix}_{timestamp}.png";
            string filePath = Path.Combine(SaveDirectory, fileName).Replace("\\", "/");
            
            // 确保目录存在
            EnsureDirectoryExists(filePath.GetBaseDir());
            
            // 保存图片
            Error error = image.SavePng(filePath);
            
            if (error == Error.Ok)
            {
                string globalPath = ProjectSettings.GlobalizePath(filePath);
                GD.Print($"✅ 截图保存成功: {globalPath}");
            }
            else
            {
                GD.PrintErr($"❌ 保存失败，错误码: {error}");
            }
        }
        catch (Exception ex)
        {
            GD.PrintErr($"保存过程中发生错误: {ex.Message}");
        }
        finally
        {
            _isSaving = false;
        }
    }
    
    private void CreateSaveDirectory()
    {
        // 确保保存目录存在
        EnsureDirectoryExists(SaveDirectory);
    }
    
    private void EnsureDirectoryExists(string dirPath)
    {
        // 规范化路径
        dirPath = dirPath.Replace("\\", "/");
        
        // 如果路径已经是根目录或空，直接返回
        if (string.IsNullOrEmpty(dirPath) || dirPath == "user://" || dirPath == "res://")
            return;
        
        // 检查目录是否存在
        if (DirAccess.DirExistsAbsolute(dirPath))
        {
            return;
        }
        
        // 使用 MakeDirRecursive 创建目录
        using DirAccess dir = DirAccess.Open(dirPath.GetBaseDir());
        if (dir != null)
        {
            string relativePath = dirPath;
            if (dirPath.StartsWith("user://"))
            {
                relativePath = dirPath.Substring("user://".Length);
            }
            else if (dirPath.StartsWith("res://"))
            {
                relativePath = dirPath.Substring("res://".Length);
            }
            
            Error error = dir.MakeDirRecursive(relativePath);
            if (error == Error.Ok)
            {
                GD.Print($"创建目录成功: {dirPath}");
            }
            else
            {
                GD.PrintErr($"创建目录失败: {error}, 路径: {dirPath}");
            }
        }
        else
        {
            // 如果无法打开父目录，尝试使用更直接的方法
            try
            {
                // 使用完整的绝对路径
                string[] parts = dirPath.Split('/');
                string currentPath = parts[0] + "://"; // user:// 或 res://
                
                for (int i = 1; i < parts.Length; i++)
                {
                    if (string.IsNullOrEmpty(parts[i])) continue;
                    
                    string checkPath = currentPath + parts[i];
                    if (!DirAccess.DirExistsAbsolute(checkPath))
                    {
                        using DirAccess currentDir = DirAccess.Open(currentPath);
                        if (currentDir != null)
                        {
                            Error err = currentDir.MakeDir(parts[i]);
                            if (err != Error.Ok)
                            {
                                GD.PrintErr($"创建子目录失败: {parts[i]}, 错误: {err}");
                            }
                        }
                    }
                    currentPath = checkPath + "/";
                }
            }
            catch (Exception ex)
            {
                GD.PrintErr($"创建目录时发生异常: {ex.Message}");
            }
        }
    }
}