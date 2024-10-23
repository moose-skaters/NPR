using UnityEngine;
using Unity.Mathematics;
using UnityEditor;
using System.IO;
using UnityEngine.Rendering;
using System.Collections.Generic;

public class VolumetricCloudBrush : MonoBehaviour
{
    public bool brushAdd = false;
    public int brushSizeAdd = 10;
    public Color brushColorAdd;
    public bool brushSubtract = false;
    public int brushSizeSubtract = 10;
    public Color brushColorSubtract;
    
    private Texture2D canvasTextureAdd;
    private Texture2D canvasTextureSubtract;
    private string savePath;
    private string savePath1;
    
    private Stack<(Color[], Color[])> undoStack = new Stack<(Color[], Color[])>();  // 撤销栈，保存两个纹理的状态
    private Stack<(Color[], Color[])> redoStack = new Stack<(Color[], Color[])>();  // 重做栈，保存两个纹理的状态
    private float4 CloudMapTiling;

    public float2 RaySphereDst(Vector3 sphereCenter, float sphereRadius, Vector3 origin, Vector3 direction)
    {
        float3 oc = origin - sphereCenter;
        float b = Vector3.Dot(direction, oc);
        float c = Vector3.Dot(oc, oc) - sphereRadius * sphereRadius;
        float t = b * b - c;

        float delta = Mathf.Sqrt(Mathf.Max(t, 0));
        float dstToSphere = Mathf.Max(-b - delta, 0);
        float dstInSphere = Mathf.Max(-b + delta , 0);
        return new float2(dstToSphere, dstInSphere);
    }

    public void DrawCloud()
    {
        var stack = VolumeManager.instance.stack;
        VolumetricCloudsRenderPassSetting cloudsVolume = stack.GetComponent<VolumetricCloudsRenderPassSetting>();
        CloudMapTiling = cloudsVolume._CloudMapTiling.value;

        Event e = Event.current;
        Camera sceneCamera = SceneView.lastActiveSceneView.camera;

        if ((e.type == EventType.MouseDown || e.type == EventType.MouseDrag) && e.button == 0)
        {
            // 在绘制之前清空重做栈
            redoStack.Clear();

            // 保存当前的纹理状态到撤销栈
            undoStack.Push((canvasTextureAdd.GetPixels(), canvasTextureSubtract.GetPixels()));

            if (brushAdd == true)
            {
                Ray ray = HandleUtility.GUIPointToWorldRay(e.mousePosition);
                float3 rayDirection = ray.direction;

                // 6360000 is the radius of Earth
                float interse = RaySphereDst(new Vector3(0.0f, -6360000.0f, 0.0f), 6360000.0f + 1500.0f, sceneCamera.transform.position, rayDirection).y;

                float3 entryPoint = (float3)sceneCamera.transform.position + interse * rayDirection;
                float2 reUV = (new float2(entryPoint.x, entryPoint.z) / 1000.0f) * CloudMapTiling.xy + CloudMapTiling.zw;

                float frac_x = (reUV.x - Mathf.Floor(reUV.x));
                float frac_y = (reUV.y - Mathf.Floor(reUV.y));

                int PixelX = Mathf.RoundToInt(frac_x * canvasTextureAdd.width);
                int PixelY = Mathf.RoundToInt(frac_y * canvasTextureAdd.height);

                // Draw with the brush
                for (int x = -brushSizeAdd / 2; x <= brushSizeAdd / 2; x++)
                {
                    for (int y = -brushSizeAdd / 2; y <= brushSizeAdd / 2; y++)
                    {
                        int drawX = PixelX + x;
                        int drawY = PixelY + y;

                        // Ensure the pixel is within the texture bounds
                        if (drawX >= 0 && drawX < canvasTextureAdd.width && drawY >= 0 &&
                            drawY < canvasTextureAdd.height)
                        {
                            canvasTextureAdd.SetPixel(drawX, drawY,
                                new Color(brushColorAdd.r, brushColorAdd.g, brushColorAdd.b, brushColorAdd.a));
                        }
                    }
                }
                canvasTextureAdd.Apply();
                e.Use(); // Consume the event
            }
            else if (brushSubtract == true)
            {
                Ray ray = HandleUtility.GUIPointToWorldRay(e.mousePosition);
                float3 rayDirection = ray.direction;

                // 6360000 is the radius of Earth
                float interse = RaySphereDst(new Vector3(0.0f, -6360000.0f, 0.0f), 6360000.0f + 1500.0f, sceneCamera.transform.position, rayDirection).y;

                float3 entryPoint = (float3)sceneCamera.transform.position + interse * rayDirection;
                float2 reUV = (new float2(entryPoint.x, entryPoint.z) / 1000.0f) * CloudMapTiling.xy + CloudMapTiling.zw;

                float frac_x = (reUV.x - Mathf.Floor(reUV.x));
                float frac_y = (reUV.y - Mathf.Floor(reUV.y));

                int PixelX = Mathf.RoundToInt(frac_x * canvasTextureSubtract.width);
                int PixelY = Mathf.RoundToInt(frac_y * canvasTextureSubtract.height);

                // Draw with the brush
                for (int x = -brushSizeSubtract / 2; x <= brushSizeSubtract / 2; x++)
                {
                    for (int y = -brushSizeSubtract / 2; y <= brushSizeSubtract / 2; y++)
                    {
                        int drawX = PixelX + x;
                        int drawY = PixelY + y;

                        // Ensure the pixel is within the texture bounds
                        if (drawX >= 0 && drawX < canvasTextureSubtract.width && drawY >= 0 &&
                            drawY < canvasTextureSubtract.height)
                        {
                            canvasTextureSubtract.SetPixel(drawX, drawY,
                                new Color(brushColorSubtract.r, brushColorSubtract.g, brushColorSubtract.b, brushColorSubtract.a));
                        }
                    }
                }
                canvasTextureSubtract.Apply();
                e.Use(); // Consume the event
            }
        }
    }

    public void Undo()
    {
        if (undoStack.Count > 0)
        {
            // 将当前状态保存到重做栈
            redoStack.Push((canvasTextureAdd.GetPixels(), canvasTextureSubtract.GetPixels()));

            // 从撤销栈中弹出上一个状态并恢复
            var previousPixels = undoStack.Pop();
            canvasTextureAdd.SetPixels(previousPixels.Item1);
            canvasTextureSubtract.SetPixels(previousPixels.Item2);
            canvasTextureAdd.Apply();
            canvasTextureSubtract.Apply();
            Debug.Log("Undo successful");
        }
        else
        {
            Debug.Log("No more actions to undo");
        }
    }

    public void Redo()
    {
        if (redoStack.Count > 0)
        {
            // 将当前状态保存到撤销栈
            undoStack.Push((canvasTextureAdd.GetPixels(), canvasTextureSubtract.GetPixels()));

            // 从重做栈中弹出上一个状态并恢复
            var redoPixels = redoStack.Pop();
            canvasTextureAdd.SetPixels(redoPixels.Item1);
            canvasTextureSubtract.SetPixels(redoPixels.Item2);
            canvasTextureAdd.Apply();
            canvasTextureSubtract.Apply();
            Debug.Log("Redo successful");
        }
        else
        {
            Debug.Log("No more actions to redo");
        }
    }

    public void SaveCanvasTexture()
    {
        if (canvasTextureAdd != null)
        {
            byte[] bytes = canvasTextureAdd.EncodeToPNG();
            File.WriteAllBytes(savePath, bytes);
            Debug.Log("Canvas TextureAdd saved to " + savePath);
        }
        if (canvasTextureSubtract != null)
        {
            byte[] bytes = canvasTextureSubtract.EncodeToPNG();
            File.WriteAllBytes(savePath1, bytes);
            Debug.Log("Canvas TextureSubtract saved to " + savePath1);
        }
    }

    public void InitializeCanvasTexture()
    {
        // 设置保存路径
        savePath = "Assets/VolumetricCloud/Textures/CloudCanvasTextureAdd.png";
        savePath1 = "Assets/VolumetricCloud/Textures/CloudCanvasTextureSubtract.png";
        
        // 尝试加载已有的纹理文件
        if (File.Exists(savePath))
        {
            byte[] fileData = File.ReadAllBytes(savePath);
            canvasTextureAdd = new Texture2D(2, 2);
            canvasTextureAdd.LoadImage(fileData);
        }
        else
        {
            // 初始化一个新的Texture2D
            canvasTextureAdd = new Texture2D(2048, 2048, TextureFormat.RGBA32, false, true);
            Color[] fillColorArray = canvasTextureAdd.GetPixels();
            for (int i = 0; i < fillColorArray.Length; ++i)
            {
                fillColorArray[i] = new Color(0, 0, 0, 0);
            }
            canvasTextureAdd.SetPixels(fillColorArray);
            canvasTextureAdd.Apply();
            if (canvasTextureAdd != null)
            {
                byte[] bytes = canvasTextureAdd.EncodeToPNG();
                File.WriteAllBytes(savePath, bytes);
                Debug.Log("Canvas TextureAdd saved to " + savePath);
            }
        }
        
        if (File.Exists(savePath1))
        {
            byte[] fileData1 = File.ReadAllBytes(savePath1);
            canvasTextureSubtract = new Texture2D(2, 2);
            canvasTextureSubtract.LoadImage(fileData1);
        }
        else
        {
            // 初始化一个新的Texture2D
            canvasTextureSubtract = new Texture2D(2048, 2048, TextureFormat.RGBA32, false, true);
            Color[] fillColorArray1 = canvasTextureSubtract.GetPixels();
            for (int i = 0; i < fillColorArray1.Length; ++i)
            {
                fillColorArray1[i] = new Color(0, 0, 0, 0);
            }
            canvasTextureSubtract.SetPixels(fillColorArray1);
            canvasTextureSubtract.Apply();
            if (canvasTextureSubtract != null)
            {
                byte[] bytes1 = canvasTextureSubtract.EncodeToPNG();
                File.WriteAllBytes(savePath1, bytes1);
                Debug.Log("Canvas TextureSubtract saved to " + savePath1);
            }
        }
    
        
        Shader.SetGlobalTexture("_CloudBrushMapTextureAdd", canvasTextureAdd);
        Shader.SetGlobalTexture("_CloudBrushMapTextureSubtract", canvasTextureSubtract);
    }
}

[CustomEditor(typeof(VolumetricCloudBrush))]
public class VolumetricCloudBrushEditor : Editor
{
    public override void OnInspectorGUI()
    {
        DrawDefaultInspector();
        VolumetricCloudBrush script = (VolumetricCloudBrush)target;

        if (GUILayout.Button("Initialize Cloud Texture"))
        {
            script.InitializeCanvasTexture();
        }

        if (GUILayout.Button("Save CloudMap"))
        {
            script.SaveCanvasTexture();
        }

        if (GUILayout.Button("Undo"))
        {
            script.Undo();
        }

        if (GUILayout.Button("Redo"))
        {
            script.Redo();
        }
    }

    void OnSceneGUI()
    {
        VolumetricCloudBrush brush = (VolumetricCloudBrush)target;
        brush.DrawCloud();
    }
}
