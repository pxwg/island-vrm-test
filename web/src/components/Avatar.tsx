import { useEffect, useRef } from 'react'
import { useFrame, useThree, useLoader } from '@react-three/fiber'
import { GLTFLoader } from 'three-stdlib'
import * as THREE from 'three'
import { VRMLoaderPlugin, VRM } from '@pixiv/three-vrm'
import { VRMAnimationLoaderPlugin, createVRMAnimationClip } from '@pixiv/three-vrm-animation'

interface AvatarProps {
  mouseRef: React.MutableRefObject<{ x: number; y: number }>
  mode: 'head' | 'body'
  headNodeRef?: React.MutableRefObject<THREE.Object3D | null>
}

export function Avatar({ mouseRef, mode, headNodeRef }: AvatarProps) {
  const { scene } = useThree()
  const vrmRef = useRef<VRM | null>(null)
  
  // === 动画混合器相关 Refs ===
  const mixerRef = useRef<THREE.AnimationMixer | null>(null)
  // 我们需要两个 Action 来实现“自己过渡给自己”
  const actionsRef = useRef<{
    current: THREE.AnimationAction | null,
    next: THREE.AnimationAction | null
  }>({ current: null, next: null })

  // === 状态 Refs ===
  const currentYaw = useRef(0)
  const currentPitch = useRef(0)
  const lookAtTargetRef = useRef<THREE.Object3D>(new THREE.Object3D())

  // 1. 加载 VRM 模型
  const gltf = useLoader(GLTFLoader, './avatar.vrm', (loader) => {
    (loader as any).register((parser: any) => new VRMLoaderPlugin(parser))
  })
  const { userData } = gltf
  const vrmScene = gltf.scene
  
  // 2. 加载 VRMA 动画
  const gltfAnim = useLoader(GLTFLoader, './idle.vrma', (loader) => {
    (loader as any).register((parser: any) => new VRMAnimationLoaderPlugin(parser))
  })
  const { userData: animUserData } = gltfAnim

  // 3. 初始化逻辑
  useEffect(() => {
    const vrm = userData.vrm as VRM
    if (!vrm) return
    vrmRef.current = vrm

    // (A) 模型初始化
    vrm.scene.rotation.y = Math.PI // 转身面向镜头
    
    // (B) 保存头部节点 (供外部摄像机使用)
    if (headNodeRef) {
        const head = vrm.humanoid.getRawBoneNode('head')
        if (head) headNodeRef.current = head
    }
    
    // (C) 设置眼球追踪
    scene.add(lookAtTargetRef.current)
    if (vrm.lookAt) {
        vrm.lookAt.target = lookAtTargetRef.current
    }

    // (D) 核心修改：设置无缝循环动画
    if (animUserData.vrmAnimations && animUserData.vrmAnimations[0]) {
      const mixer = new THREE.AnimationMixer(vrm.scene)
      mixerRef.current = mixer

      // 1. 创建原始 Clip
      const clip1 = createVRMAnimationClip(animUserData.vrmAnimations[0], vrm)
      // 2. 克隆一份完全一样的 Clip (为了能让动作 Crossfade 到它自己)
      const clip2 = clip1.clone()

      // 3. 创建两个 Action
      const action1 = mixer.clipAction(clip1)
      const action2 = mixer.clipAction(clip2)

      // 4. 关键：设置为 LoopOnce，因为我们要手动控制循环逻辑
      // 这样可以避免 AnimationMixer 自动跳回 0 帧造成的闪烁
      action1.setLoop(THREE.LoopOnce, 1)
      action1.clampWhenFinished = true
      
      action2.setLoop(THREE.LoopOnce, 1)
      action2.clampWhenFinished = true

      // 5. 启动第一个动作
      action1.play()

      // 6. 保存引用
      actionsRef.current = { current: action1, next: action2 }
    }

    return () => {
        scene.remove(lookAtTargetRef.current)
    }
  }, [userData, animUserData, scene, headNodeRef])

  // 4. 渲染循环
  useFrame((_, delta) => {
    const vrm = vrmRef.current
    if (!vrm) return

    // === A. 智能动画循环逻辑 ===
    if (mixerRef.current && actionsRef.current.current && actionsRef.current.next) {
        mixerRef.current.update(delta)

        const activeAction = actionsRef.current.current
        const nextAction = actionsRef.current.next
        const clipDuration = activeAction.getClip().duration
        
        // 定义过渡时间 (例如 1.0 秒)
        // 注意：如果动作很短，过渡时间不能超过动作时长的一半
        const fadeDuration = Math.min(1.0, clipDuration * 0.4)

        // 检测：如果当前动作快播完了，且下一个动作还没开始播
        // activeAction.time 是当前播放进度
        if (activeAction.time > (clipDuration - fadeDuration) && !nextAction.isRunning()) {
            
            // 1. 重置并播放下一个动作
            nextAction.reset()
            nextAction.play()

            // 2. 执行平滑过渡 (Crossfade)
            // 这会让 activeAction 慢慢变淡，nextAction 慢慢变强
            activeAction.crossFadeTo(nextAction, fadeDuration, true)

            // 3. 交换引用，现在的 next 变成未来的 current
            actionsRef.current.current = nextAction
            actionsRef.current.next = activeAction
        }
    }
    
    vrm.update(delta)

    // === B. 鼠标跟随逻辑 (保持不变) ===
    const { x: mouseX, y: mouseY } = mouseRef.current
    const isClosedMode = (mode === 'head')
    
    const trackingIntensity = isClosedMode ? 0.25 : 1.0
    const sensitivity = 0.002
    const maxYaw = THREE.MathUtils.degToRad(50)
    const maxPitch = THREE.MathUtils.degToRad(30)

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

    currentYaw.current = THREE.MathUtils.lerp(currentYaw.current, targetYaw, 0.1)
    currentPitch.current = THREE.MathUtils.lerp(currentPitch.current, targetPitch, 0.1)

    // 驱动骨骼旋转
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

    // === C. 眼球追踪 (保持不变) ===
    if (lookAtTargetRef.current && head) {
        vrm.scene.updateMatrixWorld()
        const headPos = head.getWorldPosition(new THREE.Vector3())
        
        lookAtTargetRef.current.position.set(
            headPos.x + Math.sin(currentYaw.current),
            headPos.y + Math.tan(currentPitch.current),
            headPos.z + Math.cos(currentYaw.current)
        )
    }
  })

  return <primitive object={vrmScene} />
}
