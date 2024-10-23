using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using static VolumetricCloudsRenderPassSetting;
[ExecuteAlways]
public class CustomLutGenerator : MonoBehaviour
{
    
    private VolumetricCloudsRenderPassSetting clouds; // 体积云设置组件

    private Texture2D m_CumulusLutPresetMap;//积云LUT
    private Color[] m_CumulusLutColorArray;
    
    private Texture2D m_AltoStratusLutPresetMap;//层云LUT
    private Color[] m_AltoStratusLutColorArray;
    
    private Texture2D m_CumulonimbusLutPresetMap;//积雨云LUT
    private Color[] CumulonimbusLutColorArray;
    
    void Update()
    {
        var stack = VolumeManager.instance.stack;
        clouds = stack.GetComponent<VolumetricCloudsRenderPassSetting>();
        PrepareCustomLutData(ref m_CumulusLutPresetMap,128, m_CumulusLutColorArray,clouds.CumulusDensityCurve,clouds.CumulusErosionCurve,clouds.CumulusCloudTypeHeightCurve);
        PrepareCustomLutData(ref m_AltoStratusLutPresetMap,128, m_AltoStratusLutColorArray,clouds.AltoStratusDensityCurve,clouds.AltoStratusErosionCurve,clouds.AltoStratusCloudTypeHeightCurve);
        PrepareCustomLutData(ref m_CumulonimbusLutPresetMap,128, CumulonimbusLutColorArray,clouds.CumulonimbusDensityCurve,clouds.CumulonimbusErosionCurve,clouds.CumulonimbusCloudTypeHeightCurve);
        Shader.SetGlobalTexture("_CumulusLutPresetMap",m_CumulusLutPresetMap);
        Shader.SetGlobalTexture("_AltoStratusLutPresetMap",m_AltoStratusLutPresetMap);
        Shader.SetGlobalTexture("_CumulonimbusLutPresetMap",m_CumulonimbusLutPresetMap);
    }
    
    void PrepareCustomLutData(ref Texture2D customLutPresetMap, int customLutMapResolution,   Color[] customLutColorArray ,AnimationCurveParameter densityCurve ,AnimationCurveParameter erosionCurve ,AnimationCurveParameter cloudTypeHeightLerp)
    {
        if (customLutPresetMap == null)
        {
            customLutPresetMap = new Texture2D(1, customLutMapResolution, GraphicsFormat.R16G16B16A16_SFloat, TextureCreationFlags.None)
            {
                name = "Custom LUT Curve",
                filterMode = FilterMode.Bilinear,
                wrapMode = TextureWrapMode.Clamp
            };
            customLutPresetMap.hideFlags = HideFlags.HideAndDontSave;
        }

        if (customLutColorArray == null || customLutColorArray.Length != customLutMapResolution)
        {
            customLutColorArray = new Color[customLutMapResolution];
        }

        var pixels = customLutColorArray;

        var densityCurveValue = densityCurve.value;
        var erosionCurveValue = erosionCurve.value;
        var cloudTypeHeightLerpValue = cloudTypeHeightLerp.value;
        
        
        
        if (densityCurve == null || densityCurveValue.length == 0)
        {
            for (int i = 0; i < customLutMapResolution; i++)
                pixels[i] = Color.white;
        }
        else
        {
            float step = 1.0f / (customLutMapResolution - 1f);

            for (int i = 0; i < customLutMapResolution; i++)
            {
                float currTime = step * i;
                float density = Mathf.Clamp(densityCurveValue.Evaluate(currTime), 0.0f, 1.0f);
                float erosion = Mathf.Clamp(erosionCurveValue.Evaluate(currTime), 0.0f, 1.0f);
                float cloudType = Mathf.Clamp(cloudTypeHeightLerpValue.Evaluate(currTime), 0.0f, 1.0f);
                pixels[i] = new Color(density, erosion, cloudType, 1.0f);
            }
        }

        customLutPresetMap.SetPixels(pixels);
        customLutPresetMap.Apply();
    }

}
