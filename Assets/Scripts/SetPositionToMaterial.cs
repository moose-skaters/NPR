using UnityEngine;

public class SetPositionToMaterial : MonoBehaviour
{
    [Header("Transforms to Track")]
    public Transform headForwardTransform;
    public Transform headRightTransform;

    [Header("Renderer to Modify")]
    public Material targetMaterial;

    void Update()
    {
        if (headForwardTransform != null && headRightTransform != null && targetMaterial != null)
        {
            // 获取headForwardTransform和headRightTransform的位置
            Vector3 headForwardPos = headForwardTransform.position;
            Vector3 headRightPos = headRightTransform.position;

            // 将位置传递给材质的参数
           
            targetMaterial.SetVector("_HeadFoward", headForwardPos);
            targetMaterial.SetVector("_HeadRight", headRightPos);
        }
    }
}