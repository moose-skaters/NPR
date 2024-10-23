using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
public class DrawFogRenderPassFeature : ScriptableRendererFeature
{
    class DrawFogRenderPass : ScriptableRenderPass
    {

        //private ProfilingSampler m_ProfilingRenderPostProcessing = new ProfilingSampler("Draw Fog");
        private string m_ProfilingRenderPostProcessing = "DrawFog";
      
        //RTHandle m_Source;

       
        //适配本项目专用的雾效面片参数
        Material fogMaterial;

        

        public void initFog()
        {
            // 如果已有 fogMaterial，销毁它以避免内存泄漏
            // if (fogMaterial != null)
            // {
            //     Object.Destroy(fogMaterial);
            // }
            // Load the shader from the specified path
            Shader fogShader = Shader.Find("Personal/Atmospherics/Height_Fog_Global");
    
            // Check if the shader is found
            if (fogShader != null)
            {
                // Create a new material with the fog shader
                fogMaterial = new Material(fogShader);
                //Debug.Log("Fog material successfully created.");
            }
            else
            {
                Debug.LogError("Failed to find the Height Fog shader at the specified path.");
            }
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            
            //m_Source = renderingData.cameraData.renderer.cameraColorTargetHandle;
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            var cmd = CommandBufferPool.Get();
            // RTHandle cameraColorHandle = renderingData.cameraData.renderer.cameraColorTargetHandle;
           
            
            
            using (new ProfilingScope(cmd, new ProfilingSampler(m_ProfilingRenderPostProcessing)))
            {
                //绘制雾效
                
                cmd.SetViewProjectionMatrices(Matrix4x4.identity, Matrix4x4.identity);
                
                cmd.DrawMesh(RenderingUtils.fullscreenMesh, Matrix4x4.identity, fogMaterial, 0, 0);
                
                cmd.SetViewProjectionMatrices(
                    renderingData.cameraData.camera.worldToCameraMatrix,
                    renderingData.cameraData.camera.projectionMatrix
                );
                
             
                    
                    
                
            }
            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();
            CommandBufferPool.Release(cmd);
        }

        public override void OnCameraCleanup(CommandBuffer cmd)
        {
            
        }
    }

    DrawFogRenderPass m_DrawFogPass;
    [System.Serializable]
    public class Settings
    {
        public RenderPassEvent RenderPassEvent = RenderPassEvent.AfterRenderingSkybox;
        
        
    }
    public Settings settings;
    public override void Create()
    {
        m_DrawFogPass = new DrawFogRenderPass();
        m_DrawFogPass.renderPassEvent = settings.RenderPassEvent;
       
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        
        m_DrawFogPass.initFog();
        
        renderer.EnqueuePass(m_DrawFogPass);
        
    }
}

