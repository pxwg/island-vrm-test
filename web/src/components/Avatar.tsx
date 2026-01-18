import { useEffect, useRef } from 'react'
import { useFrame, useThree, useLoader } from '@react-three/fiber'
import { GLTFLoader } from 'three-stdlib'
import * as THREE from 'three'
import { VRMLoaderPlugin, VRM } from '@pixiv/three-vrm'
import { VRMAnimationLoaderPlugin, createVRMAnimationClip } from '@pixiv/three-vrm-animation'

interface AvatarProps {
  mouseRef: React.MutableRefObject<{ x: number; y: number }>
  mode: 'head' | 'body'
}

export function Avatar({ mouseRef, mode }: AvatarProps) {
  const { camera, scene } = useThree()
  const vrmRef = useRef<VRM | null>(null)
  const mixerRef = useRef<THREE.AnimationMixer | null>(null)
  
  // === 状态 Refs (不触发重渲染) ===
  const currentYaw = useRef(0)
  const currentPitch = useRef(0)
  // 摄像机当前的观察点 (用于 lerp 平滑)
  const currentLookAt = useRef(new THREE.Vector3(0, 1.4, 0))
  // 预计算的身体适配距离
  const bodyFitDistance = useRef(1.5)
  // 眼球追踪的目标物体
  const lookAtTargetRef = useRef<THREE.Object3D>(new THREE.Object3D())

  // 1. 加载资源
  const gltf = useLoader(GLTFLoader, './avatar.vrm', (loader) => {
    (loader as any).register((parser: any) => new VRMLoaderPlugin(parser))
  })
  const { scene: vrmScene, userData } = gltf
  
  const gltfAnim = useLoader(GLTFLoader, './idle.vrma', (loader) => {
    (loader as any).register((parser: any) => new VRMAnimationLoaderPlugin(parser))
  })
  const { userData: animUserData } = gltfAnim

  // 2. 初始化逻辑
  useEffect(() => {
    const vrm = userData.vrm as VRM
    if (!vrm) return
    vrmRef.current = vrm

    // (A) 模型初始化
    vrm.scene.rotation.y = Math.PI // 转身面向镜头
    
    // (B) 设置眼球追踪目标
    // 需要把目标对象加到场景中，否则 VRM 可能找不到世界坐标
    scene.add(lookAtTargetRef.current)
    if (vrm.lookAt) {
        vrm.lookAt.target = lookAtTargetRef.current
    }

    // (C) 计算全身/半身模式的最佳距离
    const calculateBodyFitDistance = () => {
        const headNode = vrm.humanoid.getRawBoneNode("head")
        const hipsNode = vrm.humanoid.getRawBoneNode("hips")
        if (!headNode || !hipsNode) return

        vrm.scene.updateMatrixWorld(true)
        const headPos = headNode.getWorldPosition(new THREE.Vector3())
        const hipsPos = hipsNode.getWorldPosition(new THREE.Vector3())
        
        // 估算可视高度 (头顶到臀部下方)
        const visibleHeight = (headPos.y + 0.18) - (hipsPos.y + 0.15)
        
        // 根据摄像机 FOV 计算能容纳这个高度的距离
        // @ts-ignore: camera.fov exists on PerspectiveCamera
        const fov = camera.fov || 40
        const fovRad = (fov * Math.PI) / 180
        bodyFitDistance.current = (visibleHeight / 2) / Math.tan(fovRad / 2) * 1.5
    }
    calculateBodyFitDistance()

    // (D) 播放动画
    if (animUserData.vrmAnimations && animUserData.vrmAnimations[0]) {
      const mixer = new THREE.AnimationMixer(vrm.scene)
      const clip = createVRMAnimationClip(animUserData.vrmAnimations[0], vrm)
      mixer.clipAction(clip).play()
      mixerRef.current = mixer
    }

    // 清理
    return () => {
        scene.remove(lookAtTargetRef.current)
    }
  }, [userData, animUserData, camera, scene])

  // 3. 核心渲染循环 (每帧执行)
  useFrame((state, delta) => {
    const vrm = vrmRef.current
    if (!vrm) return

    // --- A. 更新基础动画 ---
    if (mixerRef.current) mixerRef.current.update(delta)
    vrm.update(delta)

    // --- B. 鼠标跟随计算 ---
    const { x: mouseX, y: mouseY } = mouseRef.current
    const isClosedMode = (mode === 'head')
    
    // 灵动岛折叠时，大幅减弱追踪强度，防止“埋头”
    const trackingIntensity = isClosedMode ? 0.25 : 1.0
    const sensitivity = 0.002
    const maxYaw = THREE.MathUtils.degToRad(50)
    const maxPitch = THREE.MathUtils.degToRad(30)

    // 计算目标角度
    const targetYaw = THREE.MathUtils.clamp(
      mouseX * sensitivity * trackingIntensity,
      -maxYaw * trackingIntensity,
      maxYaw * trackingIntensity
    )
    const targetPitch = THREE.MathUtils.clamp(
      mouseY * sensitivity * trackingIntensity,
      -maxPitch * trackingIntensity,
      maxPitch * trackingIntensity
    )

    // 平滑插值 (Lerp)
    currentYaw.current = THREE.MathUtils.lerp(currentYaw.current, targetYaw, 0.1)
    currentPitch.current = THREE.MathUtils.lerp(currentPitch.current, targetPitch, 0.1)

    // --- C. 驱动骨骼旋转 (脊柱->脖子->头 联动) ---
    const head = vrm.humanoid.getRawBoneNode('head')
    const neck = vrm.humanoid.getRawBoneNode('neck')
    const spine = vrm.humanoid.getRawBoneNode('upperChest') || vrm.humanoid.getRawBoneNode('chest')

    if (spine) {
        spine.rotation.y += currentYaw.current * 0.2
        spine.rotation.x += currentPitch.current * 0.2
    }
    if (neck) {
        neck.rotation.y += currentYaw.current * 0.3
        neck.rotation.x += currentPitch.current * 0.3
    }
    if (head) {
        head.rotation.y += currentYaw.current * 0.5
        head.rotation.x += currentPitch.current * 0.5
    }

    // --- D. 智能运镜 (Camera Follow) ---
    // 获取最新的骨骼世界坐标
    if (!head) return // 保护
    
    // 强制更新矩阵以获取准确位置
    vrm.scene.updateMatrixWorld()
    
    const headPos = head.getWorldPosition(new THREE.Vector3())
    let hipsPos = new THREE.Vector3(headPos.x, headPos.y * 0.55, headPos.z)
    const hipsNode = vrm.humanoid.getRawBoneNode("hips")
    if (hipsNode) hipsPos = hipsNode.getWorldPosition(new THREE.Vector3())

    // 计算目标位置
    const targetLookAt = new THREE.Vector3()
    const targetCamPos = new THREE.Vector3()

    if (isClosedMode) {
        // [Head Mode] 专注头部，距离近，Y轴偏移小
        targetLookAt.set(headPos.x, headPos.y + 0.05, headPos.z)
        targetCamPos.set(headPos.x, headPos.y + 0.05, headPos.z + 0.55)
    } else {
        // [Body Mode] 全身/半身，视点中心在头和臀部之间
        const viewCenterY = (headPos.y + 0.18 + hipsPos.y + 0.15) / 2
        targetLookAt.set(headPos.x, viewCenterY, headPos.z)
        targetCamPos.set(headPos.x, viewCenterY, headPos.z + bodyFitDistance.current)
    }

    // 摄像机平滑移动
    state.camera.position.lerp(targetCamPos, 0.05)
    
    // 摄像机注视点平滑移动 (使用 Ref 存储上一次的 lookAt)
    currentLookAt.current.lerp(targetLookAt, 0.05)
    state.camera.lookAt(currentLookAt.current)

    // --- E. 眼球追踪 (LookAt Target) ---
    // 根据当前的头部角度，反推眼球应该看哪里，增加生动感
    if (lookAtTargetRef.current) {
        lookAtTargetRef.current.position.set(
            headPos.x + Math.sin(currentYaw.current),
            headPos.y + Math.tan(currentPitch.current),
            headPos.z + Math.cos(currentYaw.current)
        )
    }
  })

  return <primitive object={vrmScene} />
}
