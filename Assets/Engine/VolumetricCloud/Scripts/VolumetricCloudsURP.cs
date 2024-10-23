using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using static VolumetricCloudsRenderPassSetting;

public class VolumetricCloudsURP : ScriptableRendererFeature
{

    private VolumetricCloudsRenderPass m_VolumetricCloudsRenderPass;

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        
        var stack = VolumeManager.instance.stack;
        VolumetricCloudsRenderPassSetting cloudsVolume = stack.GetComponent<VolumetricCloudsRenderPassSetting>();

        bool isActivate = cloudsVolume != null && cloudsVolume.IsActive();

        if (renderingData.cameraData.postProcessEnabled && isActivate && 
            (renderingData.cameraData.cameraType == CameraType.Game || renderingData.cameraData.cameraType == CameraType.SceneView))
        {
            m_VolumetricCloudsRenderPass.m_CloudsVolumeSettings = cloudsVolume;
            renderer.EnqueuePass(m_VolumetricCloudsRenderPass);
        }
    }

    public override void Create()
    {

        if (m_VolumetricCloudsRenderPass == null)
        {
            m_VolumetricCloudsRenderPass = new VolumetricCloudsRenderPass();
            m_VolumetricCloudsRenderPass.renderPassEvent = RenderPassEvent.AfterRenderingSkybox;
            if (m_VolumetricCloudsRenderPass == null)
            {
                Debug.Log("Can't Init VolumetricCloudsRenderPass");
                return;
            }
        }
    }

    protected override void Dispose(bool disposing)
    {

        if (m_VolumetricCloudsRenderPass != null)
        {
            m_VolumetricCloudsRenderPass.Dispose();
        }

    }
}

public class VolumetricCloudsRenderPass : ScriptableRenderPass
{
    string m_ShaderName = "Sky/VolumetricClouds";
    string m_ProfilerTag = "VolumetricClouds";
    string m_TracingProfilerTag = "VolumetricClouds Tracing";
    string m_PrepareProfileTag = "VolumetricClouds Prepare";
    string m_ReprojectProfileTag = "VolumetricClouds Reprojection";
    string m_UpsampleProfileTag = "VolumetricClouds Upsample And Combine";
    string m_CombineProfileTag = "VolumetricClouds Combine";

    public VolumetricCloudsRenderPassSetting m_CloudsVolumeSettings;

    private Material m_VolumetricCloudsMaterial;

    // Pass0 Prepare
    private RTHandle m_HalfResolutionDepthCheckerboardMinMaxHandle;
    // Pass1 Tracing
    private RenderTargetIdentifier[] m_CloudsHandles = new RenderTargetIdentifier[2];
    private RTHandle m_CloudsLightingHandle;
    private RTHandle m_CloudsDepthHandle;
    // Pass2 Reproject 
    private RTHandle m_PreviousHistory0Handle;
    private RTHandle m_PreviousHistory1Handle;
    private RTHandle m_CurrentHistory0Handle;
    private RTHandle m_CurrentHistory1Handle;

    bool m_HistoryValidity = false;
    // Pass3 Upsample
    private RTHandle m_UpscaleHandle;

    private const string _LocalClouds = "LOCAL_VOLUMETRIC_CLOUDS";

    // RTHandle Name
    string _HalfResolutionDepthCheckerboardMinMaxTexture = "_HalfResolutionDepthCheckerboardMinMaxTexture";

    string _VolumetricCloudsLightingTexture = "_VolumetricCloudsLightingTexture";
    string _VolumetricCloudsDepthTexture = "_VolumetricCloudsDepthTexture";

    string _CurrentHistory0Texture = "_CurrentHistory0Texture";
    string _CurrentHistory1Texture = "_CurrentHistory1Texture";

    string _PreviousHistory0Texture = "_PreviousHistory0Texture";
    string _PreviousHistory1Texture = "_PreviousHistory1Texture";

    string _UpscaleTexture = "_UpscaleTexture";
    // BlitarUpsamling weight
    float[] m_distanceBasedWeights_3x3 = new float[] {  0.324652f, 0.535261f, 0.119433f, 0.535261f, 0.882497f, 0.196912f, 0.119433f, 0.196912f, 0.0439369f, 
                                                        0.119433f, 0.535261f, 0.324652f, 0.196912f, 0.882497f, 0.535261f, 0.0439369f, 0.196912f, 0.119433f, 
                                                        0.119433f, 0.196912f, 0.0439369f, 0.535261f, 0.882497f, 0.196912f, 0.324652f, 0.535261f, 0.119433f, 
                                                        0.0439369f, 0.196912f, 0.119433f, 0.196912f, 0.882497f, 0.535261f, 0.119433f, 0.535261f, 0.324652f };
    Vector4[] _DistanceBasedWeights36 = new Vector4[12];
    
    Vector3 prevSunDirection;
    Matrix4x4 prevViewProjectionMatrix;
    // Vector2Int previousViewportSize;

    public VolumetricCloudsRenderPass()
    {
        if (m_VolumetricCloudsMaterial == null)
            m_VolumetricCloudsMaterial = CoreUtils.CreateEngineMaterial(Shader.Find(m_ShaderName));
    }

    static class ShaderIDs
    {
        internal static readonly int _LowResolutionEvaluation = Shader.PropertyToID("_LowResolutionEvaluation");
        internal static readonly int _EnableIntegration = Shader.PropertyToID("_EnableIntegration");

        internal static readonly int _SubPixelIndex = Shader.PropertyToID("_SubPixelIndex");
        internal static readonly int _StateFrameIndexMod8 = Shader.PropertyToID("_StateFrameIndexMod8");

        // BlueNoise
        internal static readonly int _BlueNoiseDimensions = Shader.PropertyToID("_BlueNoiseDimensions");
        internal static readonly int _BlueNoiseModuloMasks = Shader.PropertyToID("_BlueNoiseModuloMasks");
        internal static readonly int _BlueNoiseIntensity = Shader.PropertyToID("_BlueNoiseIntensity");

        internal static readonly int _FinalSizeXY = Shader.PropertyToID("_FinalSizeXY");
        internal static readonly int _IntermediateSizeXY = Shader.PropertyToID("_IntermediateSizeXY");
        internal static readonly int _TraceSizeXY = Shader.PropertyToID("_TraceSizeXY");

        internal static readonly int _EarthRadius = Shader.PropertyToID("_EarthRadius");
        internal static readonly int _CloudLayerBottomAltitude = Shader.PropertyToID("_CloudLayerBottomAltitude");
        internal static readonly int _CloudLayerThickness = Shader.PropertyToID("_CloudLayerThickness");
        internal static readonly int _RayMarchingMaxDistance = Shader.PropertyToID("_RayMarchingMaxDistance");

        internal static readonly int _MaxCloudDistance = Shader.PropertyToID("_MaxCloudDistance");
        internal static readonly int _NumPrimarySteps = Shader.PropertyToID("_NumPrimarySteps");
        internal static readonly int _NumLightSteps = Shader.PropertyToID("_NumLightSteps");

        internal static readonly int _SunLightColor = Shader.PropertyToID("_SunLightColor");
        internal static readonly int _SunDirection = Shader.PropertyToID("_SunDirection");
        internal static readonly int _SunRight = Shader.PropertyToID("_SunRight");
        internal static readonly int _SunUp = Shader.PropertyToID("_SunUp");

        internal static readonly int _WindDirection = Shader.PropertyToID("_WindDirection");
        internal static readonly int _LargeWindSpeed = Shader.PropertyToID("_LargeWindSpeed");
        internal static readonly int _MediumWindSpeed = Shader.PropertyToID("_MediumWindSpeed");
        internal static readonly int _SmallWindSpeed = Shader.PropertyToID("_SmallWindSpeed");

        internal static readonly int _CloudMapTiling = Shader.PropertyToID("_CloudMapTiling");
      

        internal static readonly int _AltitudeDistortionFirstLayer = Shader.PropertyToID("_AltitudeDistortionFirstLayer");
        internal static readonly int _AltitudeDistortionSecondLayer = Shader.PropertyToID("_AltitudeDistortionSecondLayer");

        internal static readonly int _ShapeScaleFirstLayer = Shader.PropertyToID("_ShapeScaleFirstLayer");
        internal static readonly int _ShapeFirstLayerFactor = Shader.PropertyToID("_ShapeFirstLayerFactor");
        internal static readonly int _ShapeScaleSecondLayer = Shader.PropertyToID("_ShapeScaleSecondLayer");
        internal static readonly int _ShapeSecondLayerFactor = Shader.PropertyToID("_ShapeSecondLayerFactor");
        internal static readonly int _ShapeNoiseOffset = Shader.PropertyToID("_ShapeNoiseOffset");
        internal static readonly int _VerticalShapeNoiseOffset = Shader.PropertyToID("_VerticalShapeNoiseOffset");
        internal static readonly int _VerticalShapeWindDisplacement = Shader.PropertyToID("_VerticalShapeWindDisplacement");
        
       
        internal static readonly int _ErosionScaleFirstLayer = Shader.PropertyToID("_ErosionScaleFirstLayer");
        internal static readonly int _ErosionFactorFirstLayer = Shader.PropertyToID("_ErosionFactorFirstLayer");
        
        internal static readonly int _ErosionScaleSecondLayer = Shader.PropertyToID("_ErosionScaleSecondLayer");
        internal static readonly int _ErosionFactorSecondLayer = Shader.PropertyToID("_ErosionFactorSecondLayer");
        
        internal static readonly int _ErosionFactorCompensationFirstLayer = Shader.PropertyToID("_ErosionFactorCompensationFirstLayer");
        internal static readonly int _ErosionFactorCompensationSecondLayer = Shader.PropertyToID("_ErosionFactorCompensationSecondLayer");
        internal static readonly int billowy_type_gradient = Shader.PropertyToID("billowy_type_gradient");
        internal static readonly int wispy_noise_gradient = Shader.PropertyToID("wispy_noise_gradient");
        
        internal static readonly int _PackingNoiseChannelRWeight  = Shader.PropertyToID("_PackingNoiseChannelRWeight");
        internal static readonly int _PackingNoiseChannelGWeight  = Shader.PropertyToID("_PackingNoiseChannelGWeight");
        internal static readonly int _PackingNoiseChannelBWeight  = Shader.PropertyToID("_PackingNoiseChannelBWeight");
        internal static readonly int _PackingNoiseChannelAWeight  = Shader.PropertyToID("_PackingNoiseChannelAWeight");
        
        internal static readonly int _HHFNoiseFrequencyHigh  = Shader.PropertyToID("_HHFNoiseFrequencyHigh");
        internal static readonly int _HHFNoiseFrequencyLow  = Shader.PropertyToID("_HHFNoiseFrequencyLow");
        internal static readonly int _HHFNoiseType = Shader.PropertyToID("_HHFNoiseType");

        internal static readonly int _FadeInStart = Shader.PropertyToID("_FadeInStart");
        internal static readonly int _FadeInDistance = Shader.PropertyToID("_FadeInDistance");
        internal static readonly int _HeightGradientMin = Shader.PropertyToID("_HeightGradientMin");
        internal static readonly int _HeightGradientMax = Shader.PropertyToID("_HeightGradientMax");

        internal static readonly int _Albedo = Shader.PropertyToID("_Albedo");

        internal static readonly int _PhaseG0 = Shader.PropertyToID("_PhaseG0");
        internal static readonly int _PhaseG1 = Shader.PropertyToID("_PhaseG1");
        internal static readonly int _PhaseBlendWeight = Shader.PropertyToID("_PhaseBlendWeight");
        internal static readonly int _MsScattFactor = Shader.PropertyToID("_MsScattFactor");
        internal static readonly int _MsExtinFactor = Shader.PropertyToID("_MsExtinFactor");
        internal static readonly int _MsPhaseFactor = Shader.PropertyToID("_MsPhaseFactor");

        internal static readonly int _SilverIntensity = Shader.PropertyToID("_SilverIntensity");
        internal static readonly int _AmbientLuminanceIntensity = Shader.PropertyToID("_AmbientLuminanceIntensity");
        internal static readonly int _AmbientLightingTint = Shader.PropertyToID("_AmbientLightingTint");
        internal static readonly int _AmbientLightingBottomVisibility = Shader.PropertyToID("_AmbientLightingBottomVisibility");
        internal static readonly int _CloudDensityFirstLayer = Shader.PropertyToID("_CloudDensityFirstLayer");
        internal static readonly int _CloudFirstLayerdDensityPow = Shader.PropertyToID("_CloudFirstLayerdDensityPow");
        internal static readonly int _CloudDensitySecondLayer = Shader.PropertyToID("_CloudDensitySecondLayer");
        internal static readonly int _CloudSecondLayerdDensityPow = Shader.PropertyToID("_CloudSecondLayerdDensityPow");
        internal static readonly int _CurVPMatrix = Shader.PropertyToID("_CurVPMatrix");
        internal static readonly int _PreviousVPMatrix = Shader.PropertyToID("_PreviousVPMatrix");
        internal static readonly int _DistanceBasedWeights = Shader.PropertyToID("_DistanceBasedWeights");
        
        // RTHandle
        // Prepare
        internal static readonly int _DepthTexture = Shader.PropertyToID("_DepthTexture");

        // Tracing
        internal static readonly int _HalfResolutionDepthCheckerboardMinMaxTexture = Shader.PropertyToID("_HalfResolutionDepthCheckerboardMinMaxTexture");
        // Reproject
        internal static readonly int _HistoryVolumetricClouds0Texture = Shader.PropertyToID("_HistoryVolumetricClouds0Texture");
        internal static readonly int _HistoryVolumetricClouds1Texture = Shader.PropertyToID("_HistoryVolumetricClouds1Texture");
        internal static readonly int _HalfResDepthBuffer = Shader.PropertyToID("_HalfResDepthBuffer");
        internal static readonly int _FullResDepthBuffer = Shader.PropertyToID("_FullResDepthBuffer");
        internal static readonly int _CloudsLightingTexture = Shader.PropertyToID("_CloudsLightingTexture");
        internal static readonly int _CloudsDepthTexture = Shader.PropertyToID("_CloudsDepthTexture");
        internal static readonly int _TemporalAccumulationFactor = Shader.PropertyToID("_TemporalAccumulationFactor");
        internal static readonly int _CloudHistoryInvalidation = Shader.PropertyToID("_CloudHistoryInvalidation");
        
        // Upsample And Combine
        internal static readonly int _SceneDepthTexture = Shader.PropertyToID("_SceneDepthTexture");

        internal static readonly int _VolumetricCloudsTexture = Shader.PropertyToID("_VolumetricCloudsTexture");
        internal static readonly int _DepthStatusTexture = Shader.PropertyToID("_DepthStatusTexture");
        
        // Combine
        internal static readonly int _VolumetricCloudsUpscaleTexture = Shader.PropertyToID("_VolumetricCloudsUpscaleTexture");
    }

    internal int RayTracingFrameIndex(int FrameCount, int targetFrameCount)
    {
        return FrameCount % targetFrameCount;
    }

    private void UpdateMaterialProperties(ref RenderingData renderingData)
    {
        if (m_VolumetricCloudsMaterial == null)
        {
            m_VolumetricCloudsMaterial = CoreUtils.CreateEngineMaterial(Shader.Find(m_ShaderName));
        }

        RenderTextureDescriptor desc = renderingData.cameraData.cameraTargetDescriptor;
        int screenWidth = desc.width;
        int screenHeight = desc.height;

        if (m_CloudsVolumeSettings._Local.value)
        {
            m_VolumetricCloudsMaterial.EnableKeyword(_LocalClouds);
        }
        else
        {
            m_VolumetricCloudsMaterial.DisableKeyword(_LocalClouds);    
        }

        m_VolumetricCloudsMaterial.SetInt(ShaderIDs._SubPixelIndex, Time.frameCount % 4);

        int BlueNoiseScalarTextureSizeX = 128;
        int BlueNoiseScalarTextureSizeY = 8192;
        int DimensionsX = BlueNoiseScalarTextureSizeX;
        int DimensionsY = BlueNoiseScalarTextureSizeX;
        int DimensionsZ = BlueNoiseScalarTextureSizeY / BlueNoiseScalarTextureSizeX;

        uint ModuloMasksX = (1u << Mathf.FloorToInt(Mathf.Log(DimensionsX, 2))) - 1; // BlueNoiseScalarTextureSizeX - 1
        uint ModuloMasksY = (1u << Mathf.FloorToInt(Mathf.Log(DimensionsY, 2))) - 1; // BlueNoiseScalarTextureSizeY - 1
        uint ModuloMasksZ = (1u << Mathf.FloorToInt(Mathf.Log(DimensionsZ, 2))) - 1; // BlueNoiseScalarTextureSizeZ - 1

        m_VolumetricCloudsMaterial.SetFloat(ShaderIDs._BlueNoiseIntensity, m_CloudsVolumeSettings._BlueNoiseIntensity.value);
        m_VolumetricCloudsMaterial.SetVector(ShaderIDs._BlueNoiseDimensions, new Vector3(DimensionsX, DimensionsY, DimensionsZ));
        m_VolumetricCloudsMaterial.SetVector(ShaderIDs._BlueNoiseModuloMasks, new Vector3(ModuloMasksX, ModuloMasksY, ModuloMasksZ));
        m_VolumetricCloudsMaterial.SetInt(ShaderIDs._StateFrameIndexMod8, Time.frameCount % 16);

        if (m_CloudsVolumeSettings._CloudQualityMode == CloudQualityControl.QuarterRes)
        {
            m_VolumetricCloudsMaterial.SetInt(ShaderIDs._LowResolutionEvaluation, 1);
            m_VolumetricCloudsMaterial.SetInt(ShaderIDs._EnableIntegration, 1);

            m_VolumetricCloudsMaterial.SetVector(ShaderIDs._FinalSizeXY, new Vector2(screenWidth, screenHeight));
            m_VolumetricCloudsMaterial.SetVector(ShaderIDs._IntermediateSizeXY, new Vector2(Mathf.RoundToInt(screenWidth * 0.5f), Mathf.RoundToInt(screenHeight * 0.5f)));
            m_VolumetricCloudsMaterial.SetVector(ShaderIDs._TraceSizeXY, new Vector2(Mathf.RoundToInt(screenWidth * 0.25f), Mathf.RoundToInt(screenHeight * 0.25f)));
        }
        else if (m_CloudsVolumeSettings._CloudQualityMode == CloudQualityControl.HalfRes)
        {
            m_VolumetricCloudsMaterial.SetInt(ShaderIDs._LowResolutionEvaluation, 1);
            m_VolumetricCloudsMaterial.SetInt(ShaderIDs._EnableIntegration, 0);

            m_VolumetricCloudsMaterial.SetVector(ShaderIDs._FinalSizeXY, new Vector2(screenWidth, screenHeight));
            m_VolumetricCloudsMaterial.SetVector(ShaderIDs._IntermediateSizeXY, new Vector2(Mathf.RoundToInt(screenWidth * 0.5f), Mathf.RoundToInt(screenHeight * 0.5f))); 
            m_VolumetricCloudsMaterial.SetVector(ShaderIDs._TraceSizeXY, new Vector2(Mathf.RoundToInt(screenWidth * 0.5f), Mathf.RoundToInt(screenHeight * 0.5f)));
        }
        else if (m_CloudsVolumeSettings._CloudQualityMode == CloudQualityControl.FullRes)
        {
            m_VolumetricCloudsMaterial.SetInt(ShaderIDs._LowResolutionEvaluation, 0);
            m_VolumetricCloudsMaterial.SetInt(ShaderIDs._EnableIntegration, 0);

            m_VolumetricCloudsMaterial.SetVector(ShaderIDs._FinalSizeXY, new Vector2(screenWidth, screenHeight));
            m_VolumetricCloudsMaterial.SetVector(ShaderIDs._IntermediateSizeXY, new Vector2(screenWidth, screenHeight));
            m_VolumetricCloudsMaterial.SetVector(ShaderIDs._TraceSizeXY, new Vector2(screenWidth, screenHeight));
        }


        m_VolumetricCloudsMaterial.SetFloat(ShaderIDs._CloudLayerBottomAltitude, m_CloudsVolumeSettings._CloudLayerBottomAltitude.value);
        m_VolumetricCloudsMaterial.SetFloat(ShaderIDs._CloudLayerThickness, m_CloudsVolumeSettings._CloudLayerThickness.value);
        m_VolumetricCloudsMaterial.SetFloat(ShaderIDs._RayMarchingMaxDistance, m_CloudsVolumeSettings._RayMarchingMaxDistance.value);
        m_VolumetricCloudsMaterial.SetInt(ShaderIDs._NumPrimarySteps, m_CloudsVolumeSettings._NumPrimarySteps.value);
        m_VolumetricCloudsMaterial.SetInt(ShaderIDs._NumLightSteps, m_CloudsVolumeSettings._NumLightSteps.value);

        LightData lightData = renderingData.lightData;
        VisibleLight light = lightData.visibleLights[lightData.mainLightIndex];
        Vector3 sunForward = Vector3.Normalize(light.light.transform.forward);
        Vector3 sunRight = Vector3.Normalize(light.light.transform.right);
        Vector3 sunUp = Vector3.Normalize(light.light.transform.up);
        Color sunLightColor = light.finalColor;
        m_VolumetricCloudsMaterial.SetColor(ShaderIDs._SunLightColor, sunLightColor);
        m_VolumetricCloudsMaterial.SetVector(ShaderIDs._SunDirection, - sunForward);
        m_VolumetricCloudsMaterial.SetVector(ShaderIDs._SunRight, sunRight);
        m_VolumetricCloudsMaterial.SetVector(ShaderIDs._SunUp, sunUp);
        m_VolumetricCloudsMaterial.SetFloat(ShaderIDs._CloudDensityFirstLayer, m_CloudsVolumeSettings._CloudDensityFirstLayer.value);
        m_VolumetricCloudsMaterial.SetFloat(ShaderIDs._CloudFirstLayerdDensityPow, m_CloudsVolumeSettings._CloudFirstLayerdDensityPow.value);
        m_VolumetricCloudsMaterial.SetFloat(ShaderIDs._CloudDensitySecondLayer, m_CloudsVolumeSettings._CloudDensitySecondLayer.value);
        m_VolumetricCloudsMaterial.SetFloat(ShaderIDs._CloudSecondLayerdDensityPow, m_CloudsVolumeSettings._CloudSecondLayerdDensityPow.value);
        m_VolumetricCloudsMaterial.SetVector(ShaderIDs._WindDirection, new Vector2(m_CloudsVolumeSettings._WindDirection.value.x, m_CloudsVolumeSettings._WindDirection.value.y));
        m_VolumetricCloudsMaterial.SetFloat(ShaderIDs._LargeWindSpeed, m_CloudsVolumeSettings._LargeWindSpeed.value);
        m_VolumetricCloudsMaterial.SetFloat(ShaderIDs._MediumWindSpeed, m_CloudsVolumeSettings._MediumWindSpeed.value);
        m_VolumetricCloudsMaterial.SetFloat(ShaderIDs._SmallWindSpeed, m_CloudsVolumeSettings._SmallWindSpeed.value);
        m_VolumetricCloudsMaterial.SetFloat(ShaderIDs._VerticalShapeWindDisplacement, m_CloudsVolumeSettings._VerticalShapeWindDisplacement.value);
        m_VolumetricCloudsMaterial.SetFloat(ShaderIDs._ShapeScaleFirstLayer, m_CloudsVolumeSettings._ShapeScaleFirstLayer.value);
        m_VolumetricCloudsMaterial.SetFloat(ShaderIDs._ShapeFirstLayerFactor, m_CloudsVolumeSettings._ShapeFactorFirstLayer.value);
        m_VolumetricCloudsMaterial.SetFloat(ShaderIDs._ShapeScaleSecondLayer, m_CloudsVolumeSettings._ShapeScaleSecondLayer.value);
        m_VolumetricCloudsMaterial.SetFloat(ShaderIDs._ShapeSecondLayerFactor, m_CloudsVolumeSettings._ShapeFactorSecondLayer.value);
        m_VolumetricCloudsMaterial.SetVector(ShaderIDs._ShapeNoiseOffset, m_CloudsVolumeSettings._ShapeNoiseOffset.value);
        m_VolumetricCloudsMaterial.SetFloat(ShaderIDs._VerticalShapeNoiseOffset, m_CloudsVolumeSettings._VerticalShapeNoiseOffset.value);
        m_VolumetricCloudsMaterial.SetFloat(ShaderIDs._AltitudeDistortionFirstLayer, m_CloudsVolumeSettings._AltitudeDistortionFirstLayer.value);
        m_VolumetricCloudsMaterial.SetFloat(ShaderIDs._AltitudeDistortionSecondLayer, m_CloudsVolumeSettings._AltitudeDistortionSecondLayer.value);
        m_VolumetricCloudsMaterial.SetVector(ShaderIDs._CloudMapTiling, new Vector4(m_CloudsVolumeSettings._CloudMapTiling.value.x, m_CloudsVolumeSettings._CloudMapTiling.value.y, m_CloudsVolumeSettings._CloudMapTiling.value.z, m_CloudsVolumeSettings._CloudMapTiling.value.w));
        m_VolumetricCloudsMaterial.SetFloat(ShaderIDs._ErosionScaleFirstLayer, m_CloudsVolumeSettings._ErosionScaleFirstLayer.value);
        m_VolumetricCloudsMaterial.SetFloat(ShaderIDs._ErosionFactorFirstLayer, m_CloudsVolumeSettings._ErosionFactorFirstLayer.value);
        m_VolumetricCloudsMaterial.SetFloat(ShaderIDs._ErosionScaleSecondLayer, m_CloudsVolumeSettings._ErosionScaleSecondLayer.value);
        m_VolumetricCloudsMaterial.SetFloat(ShaderIDs._ErosionFactorSecondLayer, m_CloudsVolumeSettings._ErosionFactorSecondLayer.value);
        m_VolumetricCloudsMaterial.SetFloat(ShaderIDs._ErosionFactorCompensationFirstLayer, m_CloudsVolumeSettings._ErosionFactorCompensationFirstLayer.value);
        m_VolumetricCloudsMaterial.SetFloat(ShaderIDs._ErosionFactorCompensationSecondLayer, m_CloudsVolumeSettings._ErosionFactorCompensationSecondLayer.value);
        m_VolumetricCloudsMaterial.SetFloat(ShaderIDs.billowy_type_gradient, m_CloudsVolumeSettings.billowy_type_gradient.value);
        m_VolumetricCloudsMaterial.SetFloat(ShaderIDs.wispy_noise_gradient, m_CloudsVolumeSettings.wispy_noise_gradient.value);
        m_VolumetricCloudsMaterial.SetFloat(ShaderIDs._PackingNoiseChannelRWeight, m_CloudsVolumeSettings._PackingNoiseChannelRWeight.value);
        m_VolumetricCloudsMaterial.SetFloat(ShaderIDs._PackingNoiseChannelGWeight, m_CloudsVolumeSettings._PackingNoiseChannelGWeight.value);
        m_VolumetricCloudsMaterial.SetFloat(ShaderIDs._PackingNoiseChannelBWeight, m_CloudsVolumeSettings._PackingNoiseChannelBWeight.value);
        m_VolumetricCloudsMaterial.SetFloat(ShaderIDs._PackingNoiseChannelAWeight, m_CloudsVolumeSettings._PackingNoiseChannelAWeight.value);
        
        m_VolumetricCloudsMaterial.SetFloat(ShaderIDs._HHFNoiseFrequencyHigh, m_CloudsVolumeSettings._HHFNoiseFrequencyHigh.value);
        m_VolumetricCloudsMaterial.SetFloat(ShaderIDs._HHFNoiseFrequencyLow, m_CloudsVolumeSettings._HHFNoiseFrequencyLow.value);
        m_VolumetricCloudsMaterial.SetFloat(ShaderIDs._HHFNoiseType, m_CloudsVolumeSettings._HHFNoiseType.value);
        m_VolumetricCloudsMaterial.SetFloat(ShaderIDs._FadeInStart, m_CloudsVolumeSettings._FadeInStart.value);
        m_VolumetricCloudsMaterial.SetFloat(ShaderIDs._FadeInDistance, m_CloudsVolumeSettings._FadeInDistance.value);
        m_VolumetricCloudsMaterial.SetFloat(ShaderIDs._HeightGradientMin, m_CloudsVolumeSettings._HeightGradientMin.value);
        m_VolumetricCloudsMaterial.SetFloat(ShaderIDs._HeightGradientMax, m_CloudsVolumeSettings._HeightGradientMax.value);
        m_VolumetricCloudsMaterial.SetVector(ShaderIDs._Albedo, new Vector3(m_CloudsVolumeSettings._Albedo.value.x, m_CloudsVolumeSettings._Albedo.value.y, m_CloudsVolumeSettings._Albedo.value.z));
        m_VolumetricCloudsMaterial.SetFloat(ShaderIDs._PhaseG0, m_CloudsVolumeSettings._PhaseG0.value);
        m_VolumetricCloudsMaterial.SetFloat(ShaderIDs._PhaseG1, m_CloudsVolumeSettings._PhaseG1.value);
        m_VolumetricCloudsMaterial.SetFloat(ShaderIDs._PhaseBlendWeight, m_CloudsVolumeSettings._PhaseBlendWeight.value);
        m_VolumetricCloudsMaterial.SetFloat(ShaderIDs._MsScattFactor, m_CloudsVolumeSettings._MsScattFactor.value);
        m_VolumetricCloudsMaterial.SetFloat(ShaderIDs._MsExtinFactor, m_CloudsVolumeSettings._MsExtinFactor.value);
        m_VolumetricCloudsMaterial.SetFloat(ShaderIDs._MsPhaseFactor, m_CloudsVolumeSettings._MsPhaseFactor.value);
        m_VolumetricCloudsMaterial.SetFloat(ShaderIDs._SilverIntensity, m_CloudsVolumeSettings._SilverIntensity.value);
        m_VolumetricCloudsMaterial.SetFloat(ShaderIDs._AmbientLuminanceIntensity, m_CloudsVolumeSettings._AmbientLuminanceIntensity.value);
        m_VolumetricCloudsMaterial.SetVector(ShaderIDs._AmbientLightingTint, m_CloudsVolumeSettings._AmbientLightingTint.value);
        m_VolumetricCloudsMaterial.SetFloat(ShaderIDs._AmbientLightingBottomVisibility, m_CloudsVolumeSettings._AmbientLightingBottomVisibility.value);
        // Reprojection/Upsampling
        Matrix4x4 curViewProjMatrix = renderingData.cameraData.camera.nonJitteredProjectionMatrix * renderingData.cameraData.camera.worldToCameraMatrix;
        if (!m_HistoryValidity)
        {
            prevViewProjectionMatrix = curViewProjMatrix;
        }

        m_VolumetricCloudsMaterial.SetMatrix(ShaderIDs._PreviousVPMatrix, prevViewProjectionMatrix);
        m_VolumetricCloudsMaterial.SetMatrix(ShaderIDs._CurVPMatrix, curViewProjMatrix);

        prevViewProjectionMatrix = curViewProjMatrix;

        float[] _DistanceBasedWeights = new float[48];
        for (int p = 0; p < 4; ++p)
            for (int i = 0; i < 9; ++i)
                _DistanceBasedWeights[12 * p + i] = m_distanceBasedWeights_3x3[9 * p + i];

        for (int k = 0; k < 12; k++)
            _DistanceBasedWeights36[k] = new Vector4(_DistanceBasedWeights[k * 4 + 0], _DistanceBasedWeights[k * 4 + 1], 
                                                     _DistanceBasedWeights[k * 4 + 2], _DistanceBasedWeights[k * 4 + 3]);

        m_VolumetricCloudsMaterial.SetVectorArray(ShaderIDs._DistanceBasedWeights, _DistanceBasedWeights36);

        Vector3 curSunDirection = RenderSettings.sun.transform.forward;
        float sunAngleDiff = Vector3.Angle(curSunDirection, prevSunDirection);
        prevSunDirection = curSunDirection;

        m_VolumetricCloudsMaterial.SetFloat(ShaderIDs._CloudHistoryInvalidation, Mathf.Lerp(1.0f, 0.0f, Mathf.Clamp(sunAngleDiff / 10.0f, 0.0f, 1.0f)));
        m_VolumetricCloudsMaterial.SetFloat(ShaderIDs._TemporalAccumulationFactor, m_CloudsVolumeSettings._TemporalAccumulationFactor.value);

        float EarthRaidus = 6360000.0f;
        float absoluteCloudHeightest = (m_CloudsVolumeSettings._CloudLayerBottomAltitude.value + m_CloudsVolumeSettings._CloudLayerThickness.value + EarthRaidus);
        m_VolumetricCloudsMaterial.SetFloat(ShaderIDs._EarthRadius, EarthRaidus);
        m_VolumetricCloudsMaterial.SetFloat(ShaderIDs._MaxCloudDistance, Mathf.Sqrt(absoluteCloudHeightest * absoluteCloudHeightest - EarthRaidus * EarthRaidus));
        
    }

    public void OnCameraSetUpTest(CommandBuffer cmd, ref RenderingData renderingData)
    {
        if (m_VolumetricCloudsMaterial == null)
        {
            Debug.LogWarning("VolumetricClouds Material is not initialized. Creating new material.");
            m_VolumetricCloudsMaterial = CoreUtils.CreateEngineMaterial(Shader.Find(m_ShaderName));
        }

        RenderTextureDescriptor desc = renderingData.cameraData.cameraTargetDescriptor;
        desc.msaaSamples = 1;
        desc.useMipMap = false;
        desc.depthBufferBits = 0;

        int screenWidth = desc.width;
        int screenHeight = desc.height;

        if (m_CloudsVolumeSettings._CloudQualityMode == CloudQualityControl.QuarterRes)
        {
            // Full Resolution 
            desc.colorFormat = RenderTextureFormat.ARGBFloat; // float4(cloudLigthing.rgb, transmittance);
            desc.width = screenWidth;
            desc.height = screenHeight;
            //RenderingUtils.ReAllocateIfNeeded(ref m_UpscaleHandle, desc, FilterMode.Bilinear, TextureWrapMode.Clamp, name: _UpscaleTexture);
            if (m_UpscaleHandle == null || m_UpscaleHandle.rt.width != desc.width ||
                m_UpscaleHandle.rt.height != desc.height)
            {
                m_UpscaleHandle = RTHandles.Alloc(desc.width, desc.height,1,DepthBits.None,GraphicsFormat.R32G32B32A32_SFloat,FilterMode.Bilinear,TextureWrapMode.Clamp ,name: _UpscaleTexture);
            }

            // Half Resolution
            desc.colorFormat = RenderTextureFormat.RFloat;
            desc.width = Mathf.RoundToInt(screenWidth * 0.5f);
            desc.height = Mathf.RoundToInt(screenHeight * 0.5f);
            // RenderingUtils.ReAllocateIfNeeded(ref m_HalfResolutionDepthCheckerboardMinMaxHandle, desc, FilterMode.Bilinear, TextureWrapMode.Clamp,
            //     name: _HalfResolutionDepthCheckerboardMinMaxTexture);
            if (m_HalfResolutionDepthCheckerboardMinMaxHandle == null || m_HalfResolutionDepthCheckerboardMinMaxHandle.rt.width != desc.width ||
                m_HalfResolutionDepthCheckerboardMinMaxHandle.rt.height != desc.height)
            {
                m_HalfResolutionDepthCheckerboardMinMaxHandle = RTHandles.Alloc(desc.width, desc.height,1,DepthBits.None,GraphicsFormat.R32_SFloat,FilterMode.Bilinear,TextureWrapMode.Clamp ,name: _HalfResolutionDepthCheckerboardMinMaxTexture);
            }
            

            desc.colorFormat = RenderTextureFormat.ARGBFloat; // float4(cloudLigthing.rgb, transmittance);
            desc.width = Mathf.RoundToInt(screenWidth * 0.5f);
            desc.height = Mathf.RoundToInt(screenHeight * 0.5f);
            //RenderingUtils.ReAllocateIfNeeded(ref m_PreviousHistory0Handle, desc, FilterMode.Bilinear, TextureWrapMode.Clamp, name: _PreviousHistory0Texture);
            if (m_PreviousHistory0Handle == null || m_PreviousHistory0Handle.rt.width != desc.width ||
                m_PreviousHistory0Handle.rt.height != desc.height)
            {
                m_PreviousHistory0Handle = RTHandles.Alloc(desc.width, desc.height,1,DepthBits.None,GraphicsFormat.R32G32B32A32_SFloat,FilterMode.Bilinear,TextureWrapMode.Clamp ,name: _PreviousHistory0Texture);
            }

            desc.colorFormat = RenderTextureFormat.ARGBFloat; // float4(cloudLigthing.rgb, transmittance);
            desc.width = Mathf.RoundToInt(screenWidth * 0.5f);
            desc.height = Mathf.RoundToInt(screenHeight * 0.5f);
            //RenderingUtils.ReAllocateIfNeeded(ref m_CurrentHistory0Handle, desc, FilterMode.Bilinear, TextureWrapMode.Clamp, name: _CurrentHistory0Texture);
            if (m_CurrentHistory0Handle == null || m_CurrentHistory0Handle.rt.width != desc.width ||
                m_CurrentHistory0Handle.rt.height != desc.height)
            {
                m_CurrentHistory0Handle = RTHandles.Alloc(desc.width, desc.height,1,DepthBits.None,GraphicsFormat.R32G32B32A32_SFloat,FilterMode.Bilinear,TextureWrapMode.Clamp ,name: _CurrentHistory0Texture);
            }
            
            desc.colorFormat = RenderTextureFormat.RGB111110Float; // float3(sampleCount, sceneDeviceZ, cloudDepthDeviceZ)
            desc.width = Mathf.RoundToInt(screenWidth * 0.5f);
            desc.height = Mathf.RoundToInt(screenHeight * 0.5f);
            //enderingUtils.ReAllocateIfNeeded(ref m_PreviousHistory1Handle, desc, FilterMode.Bilinear, TextureWrapMode.Clamp, name: _PreviousHistory1Texture);
            if (m_PreviousHistory1Handle == null || m_PreviousHistory1Handle.rt.width != desc.width ||
                m_PreviousHistory1Handle.rt.height != desc.height)
            {
                m_PreviousHistory1Handle = RTHandles.Alloc(desc.width, desc.height,1,DepthBits.None,GraphicsFormat.B10G11R11_UFloatPack32,FilterMode.Bilinear,TextureWrapMode.Clamp ,name: _PreviousHistory1Texture);
            }

            desc.colorFormat = RenderTextureFormat.RGB111110Float;
            desc.width = Mathf.RoundToInt(screenWidth * 0.5f);
            desc.height = Mathf.RoundToInt(screenHeight * 0.5f);
            //RenderingUtils.ReAllocateIfNeeded(ref m_CurrentHistory1Handle, desc, FilterMode.Bilinear, TextureWrapMode.Clamp, name: _CurrentHistory1Texture);
            if (m_CurrentHistory1Handle == null || m_CurrentHistory1Handle.rt.width != desc.width ||
                m_CurrentHistory1Handle.rt.height != desc.height)
            {
                m_CurrentHistory1Handle = RTHandles.Alloc(desc.width, desc.height,1,DepthBits.None,GraphicsFormat.B10G11R11_UFloatPack32,FilterMode.Bilinear,TextureWrapMode.Clamp ,name: _CurrentHistory1Texture);
            }
            
            // Quat Resolution
            desc.colorFormat = RenderTextureFormat.ARGBFloat; // float4(cloudLigthing.rgb, transmittance);
            desc.width = Mathf.RoundToInt(screenWidth * 0.25f);
            desc.height = Mathf.RoundToInt(screenHeight * 0.25f);
            //RenderingUtils.ReAllocateIfNeeded(ref m_CloudsLightingHandle, desc, FilterMode.Bilinear, TextureWrapMode.Clamp, name: _VolumetricCloudsLightingTexture);
            if (m_CloudsLightingHandle == null || m_CloudsLightingHandle.rt.width != desc.width ||
                m_CloudsLightingHandle.rt.height != desc.height)
            {
                m_CloudsLightingHandle = RTHandles.Alloc(desc.width, desc.height,1,DepthBits.None,GraphicsFormat.R32G32B32A32_SFloat,FilterMode.Bilinear,TextureWrapMode.Clamp ,name: _VolumetricCloudsLightingTexture);
            }

            desc.colorFormat = RenderTextureFormat.RFloat; // float(cloudDepth)
            desc.width = Mathf.RoundToInt(screenWidth * 0.25f);
            desc.height = Mathf.RoundToInt(screenHeight * 0.25f);
            //RenderingUtils.ReAllocateIfNeeded(ref m_CloudsDepthHandle, desc, FilterMode.Bilinear, TextureWrapMode.Clamp, name: _VolumetricCloudsDepthTexture);
            if (m_CloudsDepthHandle == null || m_CloudsDepthHandle.rt.width != desc.width ||
                m_CloudsDepthHandle.rt.height != desc.height)
            {
                m_CloudsDepthHandle = RTHandles.Alloc(desc.width, desc.height,1,DepthBits.None,GraphicsFormat.R32_SFloat,FilterMode.Bilinear,TextureWrapMode.Clamp ,name: _VolumetricCloudsDepthTexture);
            }
        }
        else if (m_CloudsVolumeSettings._CloudQualityMode == CloudQualityControl.HalfRes)
        {

            desc.colorFormat = RenderTextureFormat.ARGBFloat; // float4(cloudLigthing.rgb, transmittance);
            desc.width = Mathf.RoundToInt(screenWidth * 0.5f);
            desc.height = Mathf.RoundToInt(screenHeight * 0.5f);
            //RenderingUtils.ReAllocateIfNeeded(ref m_CloudsLightingHandle, desc, FilterMode.Bilinear, TextureWrapMode.Clamp, name: _VolumetricCloudsLightingTexture);
            if (m_CloudsLightingHandle == null || m_CloudsLightingHandle.rt.width != desc.width ||
                m_CloudsLightingHandle.rt.height != desc.height)
            {
                m_CloudsLightingHandle = RTHandles.Alloc(desc.width, desc.height,1,DepthBits.None,GraphicsFormat.R32G32B32A32_SFloat,FilterMode.Bilinear,TextureWrapMode.Clamp ,name: _VolumetricCloudsLightingTexture);
            }

            desc.colorFormat = RenderTextureFormat.RFloat; // float(cloudDepth)
            desc.width = Mathf.RoundToInt(screenWidth * 0.5f);
            desc.height = Mathf.RoundToInt(screenHeight * 0.5f);
            //RenderingUtils.ReAllocateIfNeeded(ref m_CloudsDepthHandle, desc, FilterMode.Bilinear, TextureWrapMode.Clamp, name: _VolumetricCloudsDepthTexture);
            if (m_CloudsDepthHandle == null || m_CloudsDepthHandle.rt.width != desc.width ||
                m_CloudsDepthHandle.rt.height != desc.height)
            {
                m_CloudsDepthHandle = RTHandles.Alloc(desc.width, desc.height,1,DepthBits.None,GraphicsFormat.R32_SFloat,FilterMode.Bilinear,TextureWrapMode.Clamp ,name: _VolumetricCloudsDepthTexture);
            }

            desc.colorFormat = RenderTextureFormat.ARGBFloat; // float4(cloudLigthing.rgb, transmittance);
            desc.width = Mathf.RoundToInt(screenWidth * 0.5f);
            desc.height = Mathf.RoundToInt(screenHeight * 0.5f);
            //RenderingUtils.ReAllocateIfNeeded(ref m_PreviousHistory0Handle, desc, FilterMode.Bilinear, TextureWrapMode.Clamp, name: _PreviousHistory0Texture);
            if (m_PreviousHistory0Handle == null || m_PreviousHistory0Handle.rt.width != desc.width ||
                m_PreviousHistory0Handle.rt.height != desc.height)
            {
                m_PreviousHistory0Handle = RTHandles.Alloc(desc.width, desc.height,1,DepthBits.None,GraphicsFormat.R32G32B32A32_SFloat,FilterMode.Bilinear,TextureWrapMode.Clamp ,name: _PreviousHistory0Texture);
            }

            desc.colorFormat = RenderTextureFormat.ARGBFloat; // float4(cloudLigthing.rgb, transmittance);
            desc.width = Mathf.RoundToInt(screenWidth * 0.5f);
            desc.height = Mathf.RoundToInt(screenHeight * 0.5f);
            //RenderingUtils.ReAllocateIfNeeded(ref m_CurrentHistory0Handle, desc, FilterMode.Bilinear, TextureWrapMode.Clamp, name: _CurrentHistory0Texture);
            if (m_CurrentHistory0Handle == null || m_CurrentHistory0Handle.rt.width != desc.width ||
                m_CurrentHistory0Handle.rt.height != desc.height)
            {
                m_CurrentHistory0Handle = RTHandles.Alloc(desc.width, desc.height,1,DepthBits.None,GraphicsFormat.R32G32B32A32_SFloat,FilterMode.Bilinear,TextureWrapMode.Clamp ,name: _CurrentHistory0Texture);
            }

            desc.colorFormat = RenderTextureFormat.RGB111110Float; // float3(sampleCount, sceneDeviceZ, cloudDepthDeviceZ)
            desc.width = Mathf.RoundToInt(screenWidth * 0.5f);
            desc.height = Mathf.RoundToInt(screenHeight * 0.5f);
            //RenderingUtils.ReAllocateIfNeeded(ref m_PreviousHistory1Handle, desc, FilterMode.Bilinear, TextureWrapMode.Clamp, name: _PreviousHistory1Texture);
            if (m_PreviousHistory1Handle == null || m_PreviousHistory1Handle.rt.width != desc.width ||
                m_PreviousHistory1Handle.rt.height != desc.height)
            {
                m_PreviousHistory1Handle = RTHandles.Alloc(desc.width, desc.height,1,DepthBits.None,GraphicsFormat.B10G11R11_UFloatPack32,FilterMode.Bilinear,TextureWrapMode.Clamp ,name: _PreviousHistory1Texture);
            }

            desc.colorFormat = RenderTextureFormat.RGB111110Float;
            desc.width = Mathf.RoundToInt(screenWidth * 0.5f);
            desc.height = Mathf.RoundToInt(screenHeight * 0.5f);
            //RenderingUtils.ReAllocateIfNeeded(ref m_CurrentHistory1Handle, desc, FilterMode.Bilinear, TextureWrapMode.Clamp, name: _CurrentHistory1Texture);
            if (m_CurrentHistory1Handle == null || m_CurrentHistory1Handle.rt.width != desc.width ||
                m_CurrentHistory1Handle.rt.height != desc.height)
            {
                m_CurrentHistory1Handle = RTHandles.Alloc(desc.width, desc.height,1,DepthBits.None,GraphicsFormat.B10G11R11_UFloatPack32,FilterMode.Bilinear,TextureWrapMode.Clamp ,name: _CurrentHistory1Texture);
            }

            // Full Resolution 
            desc.colorFormat = RenderTextureFormat.ARGBFloat; // float4(cloudLigthing.rgb, transmittance);
            desc.width = screenWidth;
            desc.height = screenHeight;
            //RenderingUtils.ReAllocateIfNeeded(ref m_UpscaleHandle, desc, FilterMode.Bilinear, TextureWrapMode.Clamp, name: _UpscaleTexture);
            if (m_UpscaleHandle == null || m_UpscaleHandle.rt.width != desc.width ||
                m_UpscaleHandle.rt.height != desc.height)
            {
                m_UpscaleHandle = RTHandles.Alloc(desc.width, desc.height,1,DepthBits.None,GraphicsFormat.R32G32B32A32_SFloat,FilterMode.Bilinear,TextureWrapMode.Clamp ,name: _UpscaleTexture);
            }

        }
        else if (m_CloudsVolumeSettings._CloudQualityMode == CloudQualityControl.FullRes)
        {
            desc.colorFormat = RenderTextureFormat.ARGBFloat; // float4(cloudLigthing.rgb, transmittance);
            desc.width = Mathf.RoundToInt(screenWidth);
            desc.height = Mathf.RoundToInt(screenHeight);
            //RenderingUtils.ReAllocateIfNeeded(ref m_CloudsLightingHandle, desc, FilterMode.Bilinear, TextureWrapMode.Clamp, name: _VolumetricCloudsLightingTexture);
            if (m_CloudsLightingHandle == null || m_CloudsLightingHandle.rt.width != desc.width ||
                m_CloudsLightingHandle.rt.height != desc.height)
            {
                m_CloudsLightingHandle = RTHandles.Alloc(desc.width, desc.height,1,DepthBits.None,GraphicsFormat.R32G32B32A32_SFloat,FilterMode.Bilinear,TextureWrapMode.Clamp ,name: _VolumetricCloudsLightingTexture);
            }

            desc.colorFormat = RenderTextureFormat.RFloat; // float(cloudDepth)
            desc.width = Mathf.RoundToInt(screenWidth);
            desc.height = Mathf.RoundToInt(screenHeight);
            //RenderingUtils.ReAllocateIfNeeded(ref m_CloudsDepthHandle, desc, FilterMode.Bilinear, TextureWrapMode.Clamp, name: _VolumetricCloudsDepthTexture);
            if (m_CloudsDepthHandle == null || m_CloudsDepthHandle.rt.width != desc.width ||
                m_CloudsDepthHandle.rt.height != desc.height)
            {
                m_CloudsDepthHandle = RTHandles.Alloc(desc.width, desc.height,1,DepthBits.None,GraphicsFormat.R32_SFloat,FilterMode.Bilinear,TextureWrapMode.Clamp ,name: _VolumetricCloudsDepthTexture);
            }
        }
    }

    public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
    {
        OnCameraSetUpTest(cmd, ref renderingData);
    }

    public void ExecuteTest(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        RenderTargetIdentifier cameraColorHandle = renderingData.cameraData.renderer.cameraColorTarget;
        RenderTargetIdentifier cameraDepthHandle = renderingData.cameraData.renderer.cameraDepthTarget;

        UpdateMaterialProperties(ref renderingData);
        RenderVolumetricClouds(context, cameraColorHandle, cameraDepthHandle);
    }

    float ScaleHeightFromLayerDepth(float d)
    {
        // Exp[-d / H] = 0.001
        // -d / H = Log[0.001]
        // H = d / -Log[0.001]
        return d * 0.144765f;
    }

    private void RenderVolumetricClouds(ScriptableRenderContext context, RenderTargetIdentifier cameraColorHandle, RenderTargetIdentifier cameraDepthHandle)
    {
        if (m_CloudsVolumeSettings._CloudQualityMode == CloudQualityControl.QuarterRes)
        {
            RenderVolumetricClouds_Accumulation(context, cameraColorHandle, cameraDepthHandle);
        }
        else if (m_CloudsVolumeSettings._CloudQualityMode == CloudQualityControl.HalfRes)
        {
            RenderVolumetricClouds_HalfResolution(context, cameraColorHandle, cameraDepthHandle);
        }
        else if (m_CloudsVolumeSettings._CloudQualityMode == CloudQualityControl.FullRes)
        {
            RenderVolumetricClouds_FullResolution(context, cameraColorHandle, cameraDepthHandle);
        }
    }

    private void RenderVolumetricClouds_Accumulation(ScriptableRenderContext context, RenderTargetIdentifier cameraColorHandle, RenderTargetIdentifier cameraDepthHandle)
    {
        CommandBuffer cmd = CommandBufferPool.Get();
        
        //Vector2Int _HistoryViewportSize = m_PreviousHistory0Handle.GetScaledSize();
        //Vector2Int _HistoryBufferSize = new Vector2Int(m_PreviousHistory0Handle.rt.width, m_PreviousHistory0Handle.rt.height);

        using (new ProfilingScope(cmd, new ProfilingSampler(m_ProfilerTag)))
        {
            using (new ProfilingScope(cmd, new ProfilingSampler(m_PrepareProfileTag)))
            {
                cmd.SetRenderTarget(m_HalfResolutionDepthCheckerboardMinMaxHandle);
                    
                //m_VolumetricCloudsMaterial.SetTexture(ShaderIDs._DepthTexture, cameraDepthHandle);
                cmd.SetGlobalTexture(ShaderIDs._DepthTexture, cameraDepthHandle);

                Blitter.BlitTexture(cmd, cameraColorHandle, new Vector4(1.0f, 1.0f, 0.0f, 0.0f), m_VolumetricCloudsMaterial, pass: 0);
            }

            using (new ProfilingScope(cmd, new ProfilingSampler(m_TracingProfilerTag)))
            {
                // MRT
                m_CloudsHandles[0] = m_CloudsLightingHandle;
                m_CloudsHandles[1] = m_CloudsDepthHandle;
                cmd.SetRenderTarget(m_CloudsHandles, m_CloudsDepthHandle);

                m_VolumetricCloudsMaterial.SetTexture(ShaderIDs._HalfResolutionDepthCheckerboardMinMaxTexture, m_HalfResolutionDepthCheckerboardMinMaxHandle);

                Blitter.BlitTexture(cmd, cameraColorHandle, new Vector4(1.0f, 1.0f, 0.0f, 0.0f), m_VolumetricCloudsMaterial, pass: 1);
            }


            using (new ProfilingScope(cmd, new ProfilingSampler(m_ReprojectProfileTag)))
            {
                
                if (!m_HistoryValidity)
                {
                    CoreUtils.SetRenderTarget(cmd, m_PreviousHistory0Handle, clearFlag: ClearFlag.Color, clearColor: Color.black);
                    CoreUtils.SetRenderTarget(cmd, m_PreviousHistory1Handle, clearFlag: ClearFlag.Color, clearColor: Color.black);
                }


                // MRT
                m_CloudsHandles[0] = m_CurrentHistory0Handle;
                m_CloudsHandles[1] = m_CurrentHistory1Handle;
                cmd.SetRenderTarget(m_CloudsHandles, m_CurrentHistory1Handle);

                m_VolumetricCloudsMaterial.SetTexture(ShaderIDs._HalfResDepthBuffer, m_HalfResolutionDepthCheckerboardMinMaxHandle);
                m_VolumetricCloudsMaterial.SetTexture(ShaderIDs._HistoryVolumetricClouds0Texture, m_PreviousHistory0Handle);
                m_VolumetricCloudsMaterial.SetTexture(ShaderIDs._HistoryVolumetricClouds1Texture, m_PreviousHistory1Handle);
                m_VolumetricCloudsMaterial.SetTexture(ShaderIDs._CloudsLightingTexture, m_CloudsLightingHandle);
                m_VolumetricCloudsMaterial.SetTexture(ShaderIDs._CloudsDepthTexture, m_CloudsDepthHandle);

                Blitter.BlitTexture(cmd, cameraColorHandle, new Vector4(1.0f, 1.0f, 0.0f, 0.0f), m_VolumetricCloudsMaterial, pass: 2);
            }

            using (new ProfilingScope(cmd, new ProfilingSampler(m_UpsampleProfileTag)))
            {

                //m_VolumetricCloudsMaterial.SetTexture(ShaderIDs._SceneDepthTexture, cameraDepthHandle);
                cmd.SetGlobalTexture(ShaderIDs._SceneDepthTexture, cameraDepthHandle);
                m_VolumetricCloudsMaterial.SetTexture(ShaderIDs._VolumetricCloudsTexture, m_CurrentHistory0Handle);
                m_VolumetricCloudsMaterial.SetTexture(ShaderIDs._DepthStatusTexture, m_CurrentHistory1Handle);

                cmd.Blit(cameraColorHandle,cameraColorHandle,m_VolumetricCloudsMaterial,pass: 3);
                //Blitter.BlitCameraTexture(cmd, cameraColorHandle, cameraColorHandle, m_VolumetricCloudsMaterial, pass: 3);
            }

            // CopyPass
            {
                cmd.CopyTexture(m_CurrentHistory0Handle, m_PreviousHistory0Handle);
                cmd.CopyTexture(m_CurrentHistory1Handle, m_PreviousHistory1Handle);
                m_HistoryValidity = true;
            }

        }

        context.ExecuteCommandBuffer(cmd);
        cmd.Clear();
        CommandBufferPool.Release(cmd);
    }

    private void RenderVolumetricClouds_HalfResolution(ScriptableRenderContext context, RenderTargetIdentifier cameraColorHandle, RenderTargetIdentifier cameraDepthHandle)
    {
        CommandBuffer cmd = CommandBufferPool.Get();

        using (new UnityEngine.Rendering.ProfilingScope(cmd, new ProfilingSampler(m_ProfilerTag)))
        {
            using (new ProfilingScope(cmd, new ProfilingSampler(m_TracingProfilerTag)))
            {
                // MRT
                m_CloudsHandles[0] = m_CloudsLightingHandle;
                m_CloudsHandles[1] = m_CloudsDepthHandle;
                cmd.SetRenderTarget(m_CloudsHandles, m_CloudsDepthHandle);

                //m_VolumetricCloudsMaterial.SetTexture(ShaderIDs._FullResDepthBuffer, cameraDepthHandle);
                cmd.SetGlobalTexture(ShaderIDs._FullResDepthBuffer, cameraDepthHandle);

                Blitter.BlitTexture(cmd, cameraColorHandle, new Vector4(1.0f, 1.0f, 0.0f, 0.0f), m_VolumetricCloudsMaterial, pass: 1);
            }

            using (new ProfilingScope(cmd, new ProfilingSampler(m_ReprojectProfileTag)))
            {
                if (!m_HistoryValidity)
                {
                    CoreUtils.SetRenderTarget(cmd, m_PreviousHistory0Handle, clearFlag: ClearFlag.Color, clearColor: Color.black);
                    CoreUtils.SetRenderTarget(cmd, m_PreviousHistory1Handle, clearFlag: ClearFlag.Color, clearColor: Color.black);
                }
                // MRT
                m_CloudsHandles[0] = m_CurrentHistory0Handle;
                m_CloudsHandles[1] = m_CurrentHistory1Handle;
                cmd.SetRenderTarget(m_CloudsHandles, m_CurrentHistory1Handle);

                //m_VolumetricCloudsMaterial.SetTexture(ShaderIDs._FullResDepthBuffer, cameraDepthHandle);
                cmd.SetGlobalTexture(ShaderIDs._FullResDepthBuffer, cameraDepthHandle);
                
                m_VolumetricCloudsMaterial.SetTexture(ShaderIDs._HistoryVolumetricClouds0Texture, m_PreviousHistory0Handle);
                m_VolumetricCloudsMaterial.SetTexture(ShaderIDs._HistoryVolumetricClouds1Texture, m_PreviousHistory1Handle);
                m_VolumetricCloudsMaterial.SetTexture(ShaderIDs._CloudsLightingTexture, m_CloudsLightingHandle);
                m_VolumetricCloudsMaterial.SetTexture(ShaderIDs._CloudsDepthTexture, m_CloudsDepthHandle);

                Blitter.BlitTexture(cmd, cameraColorHandle, new Vector4(1.0f, 1.0f, 0.0f, 0.0f), m_VolumetricCloudsMaterial, pass: 5);

            }

            using (new ProfilingScope(cmd, new ProfilingSampler(m_UpsampleProfileTag)))
            {

                //m_VolumetricCloudsMaterial.SetTexture(ShaderIDs._SceneDepthTexture, cameraDepthHandle);
                cmd.SetGlobalTexture(ShaderIDs._SceneDepthTexture, cameraDepthHandle);
                m_VolumetricCloudsMaterial.SetTexture(ShaderIDs._VolumetricCloudsTexture, m_CurrentHistory0Handle);
                m_VolumetricCloudsMaterial.SetTexture(ShaderIDs._DepthStatusTexture, m_CurrentHistory1Handle);
                cmd.Blit(cameraColorHandle,cameraColorHandle,m_VolumetricCloudsMaterial,pass: 3);
                //Blitter.BlitCameraTexture(cmd, cameraColorHandle, cameraColorHandle, m_VolumetricCloudsMaterial, pass: 3);
            }


            // CopyPass
            {
                cmd.CopyTexture(m_CurrentHistory0Handle, m_PreviousHistory0Handle);
                cmd.CopyTexture(m_CurrentHistory1Handle, m_PreviousHistory1Handle);
                m_HistoryValidity = true;
            }

        }

        context.ExecuteCommandBuffer(cmd);
        cmd.Clear();
        CommandBufferPool.Release(cmd);
    }

    private void RenderVolumetricClouds_FullResolution(ScriptableRenderContext context, RenderTargetIdentifier cameraColorHandle, RenderTargetIdentifier cameraDepthHandle)
    {
        CommandBuffer cmd = CommandBufferPool.Get();
        using (new ProfilingScope(cmd, new ProfilingSampler(m_ProfilerTag)))
        {

            using (new ProfilingScope(cmd, new ProfilingSampler(m_TracingProfilerTag)))
            {
                // MRT
                m_CloudsHandles[0] = m_CloudsLightingHandle;
                m_CloudsHandles[1] = m_CloudsDepthHandle;
                cmd.SetRenderTarget(m_CloudsHandles, m_CloudsDepthHandle);

                //m_VolumetricCloudsMaterial.SetTexture(ShaderIDs._FullResDepthBuffer, cameraDepthHandle);
                cmd.SetGlobalTexture(ShaderIDs._FullResDepthBuffer,cameraDepthHandle);
                Blitter.BlitTexture(cmd, cameraColorHandle, new Vector4(1.0f, 1.0f, 0.0f, 0.0f), m_VolumetricCloudsMaterial, pass: 1);
            }

            using (new ProfilingScope(cmd, new ProfilingSampler(m_CombineProfileTag)))
            {
                cmd.SetRenderTarget(cameraColorHandle);
                m_VolumetricCloudsMaterial.SetTexture(ShaderIDs._VolumetricCloudsUpscaleTexture, m_CloudsLightingHandle);
                
                //Blitter.BlitCameraTexture(cmd, m_CloudsLightingHandle, cameraColorHandle, m_VolumetricCloudsMaterial, pass: 4);
                Blitter.BlitTexture(cmd, cameraColorHandle, new Vector4(1.0f, 1.0f, 0.0f, 0.0f), m_VolumetricCloudsMaterial, pass: 4);
            }


        }

        context.ExecuteCommandBuffer(cmd);
        cmd.Clear();
        CommandBufferPool.Release(cmd);
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        UpdateMaterialProperties(ref renderingData);
        ExecuteTest(context, ref renderingData);
    }

    public void Dispose()
    {
        if (m_HalfResolutionDepthCheckerboardMinMaxHandle != null)
        {
            m_HalfResolutionDepthCheckerboardMinMaxHandle.Release();
            m_HalfResolutionDepthCheckerboardMinMaxHandle = null;
        }

        if (m_CloudsLightingHandle != null)
        {
            m_CloudsLightingHandle.Release();
            m_CloudsLightingHandle = null;
        }

        if (m_CloudsDepthHandle != null)
        {
            m_CloudsDepthHandle.Release();
            m_CloudsDepthHandle = null;
        }

        if (m_PreviousHistory0Handle != null)
        {
            m_PreviousHistory0Handle.Release();
            m_PreviousHistory0Handle = null;
        }

        if (m_PreviousHistory1Handle != null)
        {
            m_PreviousHistory1Handle.Release();
            m_PreviousHistory1Handle = null;
        }

        if (m_CurrentHistory0Handle != null)
        {
            m_CurrentHistory0Handle.Release();
            m_CurrentHistory0Handle = null;
        }

        if (m_CurrentHistory1Handle != null)
        {
            m_CurrentHistory1Handle.Release();
            m_CurrentHistory1Handle = null;
        }

        if (m_UpscaleHandle != null)
        {
            m_UpscaleHandle.Release();
            m_UpscaleHandle = null;
        }

        if (m_VolumetricCloudsMaterial != null)
            CoreUtils.Destroy(m_VolumetricCloudsMaterial);
    }
}

