    using System;
    using UnityEngine;
    using UnityEngine.Rendering.Universal;
    using UnityEngine.Rendering;

[VolumeComponentMenu("CYEffects/VolumetricCloudsRenderPassSetting")]
public class VolumetricCloudsRenderPassSetting : VolumeComponent, IPostProcessComponent
{
    /// <summary>
    /// Quality of the volumetric clouds controled by volclouds tracing resolution.
    /// </summary>
    public enum CloudQualityControl
    {
        FullRes,
        HalfRes,
        QuarterRes
    }

    /// <summary>
    /// A <see cref="VolumeParameter"/> that holds a <see cref="CloudQualityControl"/> value.
    /// </summary>
    [Serializable]
    public sealed class CloudQualityControlParameter : VolumeParameter<CloudQualityControl>
    {
        /// <summary>
        /// Creates a new <see cref="CloudQualityControlParameter"/> instance.
        /// </summary>
        /// <param name="value">The initial value to store in the parameter.</param>
        /// <param name="overrideState">The initial override state for the parameter.</param>
        public CloudQualityControlParameter(CloudQualityControl value, bool overrideState = false) : base(value, overrideState) { }
    }

    public BoolParameter _Enable = new BoolParameter(true);
    public CloudQualityControlParameter _CloudQualityMode = new CloudQualityControlParameter(CloudQualityControl.QuarterRes);
    public BoolParameter _Local = new BoolParameter(true);
    public ClampedFloatParameter _BlueNoiseIntensity = new ClampedFloatParameter(1.0f, 0.0f, 1.0f);
    public ClampedFloatParameter _CloudLayerBottomAltitude = new ClampedFloatParameter(1500f, 200f, 4000f);
    public ClampedFloatParameter _CloudLayerThickness = new ClampedFloatParameter(3000f, 200f, 40000f);
    public ClampedFloatParameter _RayMarchingMaxDistance = new ClampedFloatParameter(10000f, 200f, 200000f);
    public ClampedIntParameter   _NumPrimarySteps = new ClampedIntParameter(64, 8, 1024);
    public ClampedIntParameter   _NumLightSteps = new ClampedIntParameter(6, 1, 32);
    public ClampedFloatParameter _FadeInStart = new ClampedFloatParameter(0.0f, 0.0f, 100000.0f);
    public ClampedFloatParameter _FadeInDistance = new ClampedFloatParameter(5000.0f, 0.0f, 200000.0f);
    public ClampedFloatParameter _HeightGradientMin = new ClampedFloatParameter(0.0f, 0.0f, 1.0f);
    public ClampedFloatParameter _HeightGradientMax = new ClampedFloatParameter(1.0f, 0.0f, 1.0f);
    
    
    public FloatParameter        _CloudDensityFirstLayer = new FloatParameter(2.0f);
    public FloatParameter        _CloudFirstLayerdDensityPow = new FloatParameter(1.0f);
    public FloatParameter        _CloudDensitySecondLayer = new FloatParameter(2.0f);
    public FloatParameter        _CloudSecondLayerdDensityPow = new FloatParameter(1.0f);
    public Vector2Parameter      _WindDirection = new Vector2Parameter(new Vector2(0f, 0f));
    public ClampedFloatParameter _MediumWindSpeed = new ClampedFloatParameter(0, 0f, 100f);
    public ClampedFloatParameter _LargeWindSpeed = new ClampedFloatParameter(0, 0f, 100f);
    public ClampedFloatParameter _SmallWindSpeed = new ClampedFloatParameter(0, 0f, 100f);
    public ClampedFloatParameter _VerticalShapeWindDisplacement = new ClampedFloatParameter(0.0f, 0.0f, 1.0f);
    public ClampedFloatParameter _ShapeScaleFirstLayer = new ClampedFloatParameter(1, 0, 100);
    public ClampedFloatParameter _ShapeFactorFirstLayer = new ClampedFloatParameter(1, 0, 1);
    public ClampedFloatParameter _ShapeScaleSecondLayer = new ClampedFloatParameter(1, 0, 100);
    public ClampedFloatParameter _ShapeFactorSecondLayer = new ClampedFloatParameter(1, 0, 1);
    public Vector2Parameter      _ShapeNoiseOffset = new Vector2Parameter(new Vector2(0f, 0f));
    public ClampedFloatParameter _VerticalShapeNoiseOffset = new ClampedFloatParameter(0, -1000, 1000);
    public ClampedFloatParameter _AltitudeDistortionFirstLayer = new ClampedFloatParameter(0, -1000, 1000);
    public ClampedFloatParameter _AltitudeDistortionSecondLayer = new ClampedFloatParameter(0, -1000, 1000);
    public Vector4Parameter      _CloudMapTiling = new Vector4Parameter(new Vector4(100, 100, 0, 0));
    public ClampedFloatParameter _ErosionFactorFirstLayer = new ClampedFloatParameter(1, 0, 1);
    public ClampedFloatParameter _ErosionScaleFirstLayer = new ClampedFloatParameter(1, 0, 100);
    public ClampedFloatParameter _ErosionFactorSecondLayer = new ClampedFloatParameter(1, 0, 1);
    public ClampedFloatParameter _ErosionScaleSecondLayer = new ClampedFloatParameter(1, 0, 100);
    public ClampedFloatParameter _ErosionFactorCompensationFirstLayer = new ClampedFloatParameter(1, 0, 1);
    public ClampedFloatParameter _ErosionFactorCompensationSecondLayer = new ClampedFloatParameter(1, 0, 1);
    public ClampedFloatParameter billowy_type_gradient = new ClampedFloatParameter(1, 0, 1);
    public ClampedFloatParameter wispy_noise_gradient = new ClampedFloatParameter(1, 0, 1);
    public ClampedFloatParameter _PackingNoiseChannelRWeight  = new ClampedFloatParameter(1, 0, 1);
    public ClampedFloatParameter _PackingNoiseChannelGWeight  = new ClampedFloatParameter(1, 0, 1);
    public ClampedFloatParameter _PackingNoiseChannelBWeight  = new ClampedFloatParameter(0.3f, 0, 1);
    public ClampedFloatParameter _PackingNoiseChannelAWeight  = new ClampedFloatParameter(0.3f, 0, 1);
    
    public ClampedFloatParameter  _HHFNoiseFrequencyHigh  = new ClampedFloatParameter(4.0f, 0, 10);  
    public ClampedFloatParameter  _HHFNoiseFrequencyLow  = new ClampedFloatParameter(2.0f, 0, 10);    
    public ClampedFloatParameter  _HHFNoiseType = new ClampedFloatParameter(0.5f, 0.0f, 1.0f);
    public ClampedFloatParameter   _PowderEffectIntensity = new ClampedFloatParameter(1, 0, 1);
    public AnimationCurveParameter CumulusDensityCurve = new AnimationCurveParameter(new AnimationCurve());
    public AnimationCurveParameter CumulusErosionCurve = new AnimationCurveParameter(new AnimationCurve());
    public AnimationCurveParameter CumulusCloudTypeHeightCurve = new AnimationCurveParameter(new AnimationCurve());
    public AnimationCurveParameter AltoStratusDensityCurve = new AnimationCurveParameter(new AnimationCurve());
    public AnimationCurveParameter AltoStratusErosionCurve = new AnimationCurveParameter(new AnimationCurve());
    public AnimationCurveParameter AltoStratusCloudTypeHeightCurve = new AnimationCurveParameter(new AnimationCurve());
    public AnimationCurveParameter CumulonimbusDensityCurve = new AnimationCurveParameter(new AnimationCurve());
    public AnimationCurveParameter CumulonimbusErosionCurve = new AnimationCurveParameter(new AnimationCurve());
    public AnimationCurveParameter CumulonimbusCloudTypeHeightCurve = new AnimationCurveParameter(new AnimationCurve());
    public Vector3Parameter _Albedo = new Vector3Parameter(new Vector3(1, 1, 1));
    public ClampedFloatParameter _PhaseG0 = new ClampedFloatParameter(0.9f, -0.9999f, 0.9999f);
    public ClampedFloatParameter _PhaseG1 = new ClampedFloatParameter(0.9f, -0.9999f, 0.9999f);
    public ClampedFloatParameter _PhaseBlendWeight = new ClampedFloatParameter(0.5f, 0.0f, 1f);
    public ClampedFloatParameter _MsScattFactor = new ClampedFloatParameter(0.5f, 0.0f, 1f);
    public ClampedFloatParameter _MsExtinFactor = new ClampedFloatParameter(0.5f, 0.0f, 1f);
    public ClampedFloatParameter _MsPhaseFactor = new ClampedFloatParameter(0.5f, 0.0f, 1f);
    public ClampedFloatParameter _SilverIntensity = new ClampedFloatParameter(8.0f, 0.01f, 100.0f);
    public Vector3Parameter _AmbientLightingTint = new Vector3Parameter(new Vector3(1.0f, 1.0f, 1.0f));
    public ClampedFloatParameter _AmbientLightingBottomVisibility = new ClampedFloatParameter(1.0f, 0.0f, 1.0f);
    public ClampedFloatParameter _AmbientLuminanceIntensity = new ClampedFloatParameter(1.0f, 0.0f, 10.0f);
    public ClampedFloatParameter _TemporalAccumulationFactor = new ClampedFloatParameter(0.95f, 0.0f, 1.0f);

    



    public bool IsActive()
    {
        return _Enable.value;
    }

    public bool IsTileCompatible()
    {
        return false;
    }
}
