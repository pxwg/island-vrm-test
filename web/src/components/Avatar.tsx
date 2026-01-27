import { useEffect, useRef } from 'react' // [修改] 引入 useState (可选) 或继续使用 Ref
import { useFrame, useThree, useLoader } from '@react-three/fiber'
import { GLTFLoader } from 'three-stdlib'
import * as THREE from 'three'
import { VRMLoaderPlugin, VRM } from '@pixiv/three-vrm'
import { VRMAnimationLoaderPlugin, createVRMAnimationClip } from '@pixiv/three-vrm-animation'
import type { AgentPerformance, AgentState, CameraConfig } from '../hooks/useBridge'

interface AvatarProps {
  mouseRef: React.MutableRefObject<{ x: number; y: number }>
  mode: 'head' | 'body'
  headNodeRef?: React.MutableRefObject<THREE.Object3D | null>
  agentState?: AgentState
  performance?: AgentPerformance | null
  // [新增]
  cameraConfig?: CameraConfig | null
}

export function Avatar({ mouseRef, mode, headNodeRef, performance, cameraConfig }: AvatarProps) {
  const { scene } = useThree()
  const vrmRef = useRef<VRM | null>(null)
  
  // === 动画混合器 ===
  const mixerRef = useRef<THREE.AnimationMixer | null>(null)
  const actionsRef = useRef<{
    current: THREE.AnimationAction | null,
    next: THREE.AnimationAction | null
  }>({ current: null, next: null })

  // === 状态 Refs ===
  const currentYaw = useRef(0)
  const currentPitch = useRef(0)
  const lookAtTargetRef = useRef<THREE.Object3D>(new THREE.Object3D())

  // === [修改] 表情控制 Refs ===
  // 当前正在渲染的表情名称
  const currentExpressionRef = useRef<string>('neutral')
  // 目标权重 (用于 Lerp 插值)
  const targetWeightRef = useRef(0)
  // 当前实际权重
  const currentWeightRef = useRef(0)
  // 计时器引用，用于清除上一次的重置任务
  const expressionTimerRef = useRef<number | null>(null)

  // 1. 加载模型 (保持不变)
  const gltf = useLoader(GLTFLoader, './avatar.vrm', (loader) => {
    (loader as any).register((parser: any) => new VRMLoaderPlugin(parser))
  })
  const { userData } = gltf
  const vrmScene = gltf.scene
  
  // 2. 加载动画 (保持不变)
  const gltfAnim = useLoader(GLTFLoader, './idle.vrma', (loader) => {
    (loader as any).register((parser: any) => new VRMAnimationLoaderPlugin(parser))
  })
  const { userData: animUserData } = gltfAnim

  // 3. 初始化逻辑 (保持不变)
  useEffect(() => {
    const vrm = userData.vrm as VRM
    if (!vrm) return
    vrmRef.current = vrm
    vrm.scene.rotation.y = Math.PI 
    
    if (headNodeRef) {
        const head = vrm.humanoid.getRawBoneNode('head')
        if (head) headNodeRef.current = head
    }
    
    scene.add(lookAtTargetRef.current)
    if (vrm.lookAt) {
        vrm.lookAt.target = lookAtTargetRef.current
    }

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

  // === [核心修改] 监听 Performance 指令 ===
  useEffect(() => {
    if (!performance || !vrmRef.current) return
    
    // A. 处理表情 (Face)
    if (performance.face) {
        // 1. 清除之前的重置计时器 (防抖)
        if (expressionTimerRef.current) {
            clearTimeout(expressionTimerRef.current)
        }

        // 2. 立即设定新表情
        // 如果是从 neutral 变到 joy，我们希望 joy 的权重从 0 升到 intensity
        // 如果是从 joy 变到 angry，我们可能需要先重置旧表情 (这里为了平滑，简单处理为直接切换目标)
        
        // 如果当前已经在做这个表情，不重置 currentWeight，保证连续性
        if (currentExpressionRef.current !== performance.face) {
            // 切换表情时，为了避免跳变，可以将当前权重重置为0 (可选，视效果而定)
            // currentWeightRef.current = 0 
            
            // 重要：需要把上一个表情的权重归零，否则脸上会叠加多个表情
            if (vrmRef.current.expressionManager) {
                vrmRef.current.expressionManager.setValue(currentExpressionRef.current, 0)
            }
            currentExpressionRef.current = performance.face
        }

        // 3. 设定目标权重 (Fade In)
        targetWeightRef.current = performance.intensity ?? 1.0

        // 4. 设定自动重置计时器
        // 默认持续 5秒 (5000ms)，或者使用后端传入的 duration
        const duration = (performance.duration ?? 5.0) * 1000
        
        expressionTimerRef.current = window.setTimeout(() => {
            console.log("[Avatar] Expression reset to neutral")
            // 倒计时结束：将目标权重设为 0 (Fade Out)
            // 这样在 useFrame 中会平滑过渡回 Neutral (因为 Neutral 通常是所有 BlendShape 为 0 的状态)
            targetWeightRef.current = 0
        }, duration)
    }
    
    // B. 处理动作 (Action) - 这里可以使用 AnimationMixer 播放单次动作
    if (performance.action) {
       console.log("Play action:", performance.action)
       // TODO: 触发对应的 Animation Clip
    }

  }, [performance])

  // 4. 渲染循环
  useFrame((_, delta) => {
    const vrm = vrmRef.current
    if (!vrm) return

    // === A. 动画循环 (保持不变) ===
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

    // === B. [修改] 表情平滑过渡逻辑 ===
    if (vrm.expressionManager) {
        // 1. 平滑插值 current -> target
        // 速度设置为 3.0，意味着大约 0.3-0.5秒 完成表情切换
        const lerpSpeed = 3.0 * delta
        currentWeightRef.current = THREE.MathUtils.lerp(currentWeightRef.current, targetWeightRef.current, lerpSpeed)

        // 2. 应用表情
        // 注意：VRM 规范中 neutral 通常不需要设置，或者意味着所有 values 为 0
        // 如果 currentExpression 是 'neutral'，其实不需要 setValue，
        // 但为了逻辑统一，如果目标是 fading out (target=0)，我们仍然操作 currentExpression
        const presetName = currentExpressionRef.current
        
        // 简单的去抖动：如果权重非常小，视为 0
        if (currentWeightRef.current < 0.01) currentWeightRef.current = 0
        
        vrm.expressionManager.setValue(presetName, currentWeightRef.current)
        vrm.expressionManager.update()
    }
    
    vrm.update(delta)

    // === C. 鼠标跟随逻辑 (新增开关控制) ===
    // [新增] 检查 cameraConfig.followMouse，默认为 false
    const shouldFollow = cameraConfig?.followMouse ?? false
    
    const { x: mouseX, y: mouseY } = shouldFollow ? mouseRef.current : { x: 0, y: 0 }
    
    const isClosedMode = (mode === 'head')
    const trackingIntensity = isClosedMode ? 0.25 : 1.0
    const sensitivity = 0.002
    const maxYaw = THREE.MathUtils.degToRad(50)
    const maxPitch = THREE.MathUtils.degToRad(30)
    
    // 如果不跟随，targetYaw/Pitch 默认为 0，人物会看向正前方
    const targetYaw = THREE.MathUtils.clamp(mouseX * sensitivity * trackingIntensity, -maxYaw, maxYaw)
    const targetPitch = THREE.MathUtils.clamp(mouseY * sensitivity * trackingIntensity, -maxPitch, maxPitch)
    
    currentYaw.current = THREE.MathUtils.lerp(currentYaw.current, targetYaw, 0.1)
    currentPitch.current = THREE.MathUtils.lerp(currentPitch.current, targetPitch, 0.1)

    const head = vrm.humanoid.getRawBoneNode('head')
    const neck = vrm.humanoid.getRawBoneNode('neck')
    const spine = vrm.humanoid.getRawBoneNode('upperChest') || vrm.humanoid.getRawBoneNode('chest')
    if (spine) { spine.rotation.y += currentYaw.current * 0.2; spine.rotation.x += currentPitch.current * 0.2 }
    if (neck) { neck.rotation.y += currentYaw.current * 0.3; neck.rotation.x += currentPitch.current * 0.3 }
    if (head) { head.rotation.y += currentYaw.current * 0.5; head.rotation.x += currentPitch.current * 0.5 }

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
