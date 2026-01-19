import { useEffect, useRef } from 'react'
import { useFrame, useThree, useLoader } from '@react-three/fiber'
import { GLTFLoader } from 'three-stdlib'
import * as THREE from 'three'
import { VRMLoaderPlugin, VRM } from '@pixiv/three-vrm'
import { VRMAnimationLoaderPlugin, createVRMAnimationClip } from '@pixiv/three-vrm-animation'
import type { AgentPerformance, AgentState } from '../hooks/useBridge'

interface AvatarProps {
  mouseRef: React.MutableRefObject<{ x: number; y: number }>
  mode: 'head' | 'body'
  headNodeRef?: React.MutableRefObject<THREE.Object3D | null>
  // [新增] 接收状态和指令
  agentState?: AgentState
  performance?: AgentPerformance | null
}

export function Avatar({ mouseRef, mode, headNodeRef, performance }: AvatarProps) {
  const { scene } = useThree()
  const vrmRef = useRef<VRM | null>(null)
  
  // === 动画混合器相关 Refs ===
  const mixerRef = useRef<THREE.AnimationMixer | null>(null)
  const actionsRef = useRef<{
    current: THREE.AnimationAction | null,
    next: THREE.AnimationAction | null
  }>({ current: null, next: null })

  // === 状态 Refs ===
  const currentYaw = useRef(0)
  const currentPitch = useRef(0)
  const lookAtTargetRef = useRef<THREE.Object3D>(new THREE.Object3D())

  // [新增] 表情控制 Refs
  const currentExpressionRef = useRef<string>('neutral')
  const expressionWeightRef = useRef(0)

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
    
    // (B) 保存头部节点
    if (headNodeRef) {
        const head = vrm.humanoid.getRawBoneNode('head')
        if (head) headNodeRef.current = head
    }
    
    // (C) 设置眼球追踪
    scene.add(lookAtTargetRef.current)
    if (vrm.lookAt) {
        vrm.lookAt.target = lookAtTargetRef.current
    }

    // (D) 循环动画设置
    if (animUserData.vrmAnimations && animUserData.vrmAnimations[0]) {
      const mixer = new THREE.AnimationMixer(vrm.scene)
      mixerRef.current = mixer

      const clip1 = createVRMAnimationClip(animUserData.vrmAnimations[0], vrm)
      const clip2 = clip1.clone()

      const action1 = mixer.clipAction(clip1)
      const action2 = mixer.clipAction(clip2)

      action1.setLoop(THREE.LoopOnce, 1)
      action1.clampWhenFinished = true
      
      action2.setLoop(THREE.LoopOnce, 1)
      action2.clampWhenFinished = true

      action1.play()

      actionsRef.current = { current: action1, next: action2 }
    }

    return () => {
        scene.remove(lookAtTargetRef.current)
    }
  }, [userData, animUserData, scene, headNodeRef])

  // [新增] 监听 Performance 指令 (设置目标表情)
  useEffect(() => {
    if (!performance || !vrmRef.current) return
    
    if (performance.face) {
        currentExpressionRef.current = performance.face
        // 重置权重以触发重新过渡（可选，视具体需求而定，这里不重置以保持连续性）
        // expressionWeightRef.current = 0 
    }
    
    // 如果有动作 performance.action，可以在这里处理
  }, [performance])

  // 4. 渲染循环
  useFrame((_, delta) => {
    const vrm = vrmRef.current
    if (!vrm) return

    // === A. 智能动画循环 ===
    if (mixerRef.current && actionsRef.current.current && actionsRef.current.next) {
        mixerRef.current.update(delta)

        const activeAction = actionsRef.current.current
        const nextAction = actionsRef.current.next
        const clipDuration = activeAction.getClip().duration
        const fadeDuration = Math.min(1.0, clipDuration * 0.4)

        if (activeAction.time > (clipDuration - fadeDuration) && !nextAction.isRunning()) {
            nextAction.reset()
            nextAction.play()
            activeAction.crossFadeTo(nextAction, fadeDuration, true)
            actionsRef.current.current = nextAction
            actionsRef.current.next = activeAction
        }
    }

    // === B. 表情平滑过渡 ===
    if (vrm.expressionManager) {
        const targetWeight = performance?.intensity ?? 1.0
        // 简单的线性插值 (Lerp)
        const lerpSpeed = 5.0 * delta
        expressionWeightRef.current = THREE.MathUtils.lerp(expressionWeightRef.current, targetWeight, lerpSpeed)

        // 设置当前表情权重，其他表情设为0
        // 注意：VRM 1.0 标准表情预设名通常全小wl
        const presetName = currentExpressionRef.current
        
        // 这一步比较暴力，实际项目中可能需要维护一个表情列表来分别重置
        vrm.expressionManager.setValue(presetName, expressionWeightRef.current)
        vrm.expressionManager.update()
    }
    
    vrm.update(delta)

    // === C. 鼠标跟随逻辑 ===
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

    // === D. 眼球追踪 ===
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
