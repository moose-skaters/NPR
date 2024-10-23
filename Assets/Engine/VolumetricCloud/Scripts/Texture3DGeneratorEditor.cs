using System.IO;
using UnityEditor;
using UnityEngine;
using System.Linq;

public class Texture3DGeneratorEditor : EditorWindow
{
    private string folderPath = "Assets/Textures/Images"; // 图片所在的文件夹路径
    private int textureWidth = 128;
    private int textureHeight = 128;
    private int depth = 128;
    private Texture3D generatedTexture;

    [MenuItem("Tools/Texture3D Generator")]
    public static void ShowWindow()
    {
        GetWindow<Texture3DGeneratorEditor>("Texture3D Generator");
    }

    void OnGUI()
    {
        GUILayout.Label("3D Texture Generator Settings", EditorStyles.boldLabel);

        folderPath = EditorGUILayout.TextField("Folder Path", folderPath);
        textureWidth = EditorGUILayout.IntField("Texture Width", textureWidth);
        textureHeight = EditorGUILayout.IntField("Texture Height", textureHeight);
        depth = EditorGUILayout.IntField("Texture Depth", depth);

        if (GUILayout.Button("Generate 3D Texture"))
        {
            generatedTexture = Create3DTexture();
            if (generatedTexture != null)
            {
                Debug.Log("3D Texture generated successfully.");
            }
        }

        if (generatedTexture != null)
        {
            EditorGUILayout.ObjectField("Generated Texture", generatedTexture, typeof(Texture3D), false);
            if (GUILayout.Button("Save 3D Texture Asset"))
            {
                string path = EditorUtility.SaveFilePanelInProject("Save 3D Texture", "New3DTexture", "asset", "Please enter a file name to save the texture to");
                if (!string.IsNullOrEmpty(path))
                {
                    AssetDatabase.CreateAsset(generatedTexture, path);
                    AssetDatabase.SaveAssets();
                    Debug.Log("3D Texture saved as asset: " + path);
                }
            }
        }
    }

    Texture3D Create3DTexture()
    {
        Texture3D texture3D = new Texture3D(textureWidth, textureHeight, depth, TextureFormat.RGBA32, false);
        Color[] colors = new Color[textureWidth * textureHeight * depth];

        string[] files = Directory.GetFiles(folderPath, "*.tga").OrderBy(f => f).ToArray();
        if (files.Length != depth)
        {
            Debug.LogError("文件数量与3D纹理深度不匹配！");
            return null;
        }

        for (int i = 0; i < depth; i++)
        {
            string filePath = files[i];
            Texture2D sliceTexture = AssetDatabase.LoadAssetAtPath<Texture2D>(filePath);
            if (sliceTexture == null)
            {
                Debug.LogError("无法加载图像: " + filePath);
                return null;
            }

            Color[] sliceColors = sliceTexture.GetPixels();
            for (int y = 0; y < textureHeight; y++)
            {
                for (int x = 0; x < textureWidth; x++)
                {
                    int colorIndex = x + y * textureWidth + i * textureWidth * textureHeight;
                    colors[colorIndex] = sliceColors[x + y * textureWidth];
                }
            }
        }

        texture3D.SetPixels(colors);
        texture3D.Apply();

        return texture3D;
    }
}
