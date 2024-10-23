using System.Collections;
using System.Collections.Generic;
using UnityEngine;
[ExecuteAlways]
public class CubeBounds : MonoBehaviour
{
   
    
    void Update()
    {
        // 获取Cube的Renderer组件
        Renderer renderer = GetComponent<Renderer>();

        // 计算Cube的AABB包围盒
        Bounds bounds = renderer.bounds;

        // 最大和最小坐标
        Vector3 min = bounds.min;
        Vector3 max = bounds.max;
    
        // 将最大和最小坐标传递给Shader
        Shader.SetGlobalVector("_MinBox", min);
        Shader.SetGlobalVector("_MaxBox", max);
        
        
    }
}

