import { useEffect, useRef, useState, forwardRef, useImperativeHandle } from 'react'
import { useFrame, useThree } from '@react-three/fiber'
import * as THREE from 'three'
import { OrbitControls } from '@react-three/drei'

interface CameraSetting {
    position: { x: number; y: number; z: number }
    target: { x: number; y: number; z: number }
    fov: number
}
  
interface CameraConfig {
    head: CameraSetting
    body: CameraSetting
    lerpSpeed: number
}
  
interface CameraRigProps {
    mode: 'head' | 'body'
    debug?: boolean
    headNodeRef?: React.MutableRefObject<THREE.Object3D | null>
}

export const CameraRig = forwardRef(({ mode, debug = false, headNodeRef }: CameraRigProps, ref) => {
  const { camera } = useThree()
  const [config, setConfig] = useState<CameraConfig | null>(null)
  
  const targetPos = useRef(new THREE.Vector3(0, 1.4, 0.6))
  const ZHTargetLookAt = useRef(new THREE.Vector3(0, 1.4, 0)) 
  const currentLookAt = useRef(new THREE.Vector3(0, 1.4, 0))
  const controlsRef = useRef<any>(null)

  const VISUAL_OFFSET_X = 0.05

  useImperativeHandle(ref, () => controlsRef.current)

  useEffect(() => {
    fetch('./camera.json')
      .then((res) => res.json())
      .then((data) => {
        setConfig(data)
        const setting = mode === 'head' ? data.head : data.body
        if (debug && camera instanceof THREE.PerspectiveCamera) {
             // Debug 模式保持原始数据，方便校准
             camera.position.set(setting.position.x, setting.position.y, setting.position.z)
             camera.fov = setting.fov
             camera.updateProjectionMatrix()
             if (controlsRef.current) {
                 controlsRef.current.target.set(setting.target.x, setting.target.y, setting.target.z)
                 controlsRef.current.update()
             }
        }
      })
      .catch(console.error)
  }, [debug]) 

  useEffect(() => {
    if (!config || debug) return 

    const setting = mode === 'head' ? config.head : config.body
    
    // 初始化相机位置（当骨骼未加载或非动态追踪状态时使用）
    if (mode !== 'head' || !headNodeRef?.current) {
        const rawPos = new THREE.Vector3(setting.position.x, setting.position.y, setting.position.z)
        const rawTarget = new THREE.Vector3(setting.target.x, setting.target.y, setting.target.z)

        // [核心修改] 逻辑反转：仅在 Head 模式下应用视觉偏移
        // Body 模式保持 camera.json 的原始居中数值
        if (mode === 'head') {
            rawPos.x += VISUAL_OFFSET_X
            rawTarget.x += VISUAL_OFFSET_X
        }

        targetPos.current.copy(rawPos)
        ZHTargetLookAt.current.copy(rawTarget)
    }
    
    if (camera instanceof THREE.PerspectiveCamera) {
        camera.fov = setting.fov
        camera.updateProjectionMatrix()
    }
  }, [mode, config, camera, debug, headNodeRef])

  useFrame((state) => {
    if (debug) return 

    // Head 模式下的动态追踪
    if (mode === 'head' && headNodeRef?.current) {
        const headPos = headNodeRef.current.getWorldPosition(new THREE.Vector3())
        
        // 让相机和观察点整体右移，视觉上人物就会相对左移
        const offsetX = headPos.x + VISUAL_OFFSET_X
        
        ZHTargetLookAt.current.set(offsetX, headPos.y + 0.05, headPos.z)
        // 保持 Z 轴相对距离不变 (+0.55)
        targetPos.current.set(offsetX, headPos.y + 0.05, headPos.z + 0.55)
    }
    // Body 模式现在没有特殊处理，会平滑过渡到上面 useEffect 设置的无偏移坐标

    const speed = config?.lerpSpeed || 0.05
    state.camera.position.lerp(targetPos.current, speed)
    currentLookAt.current.lerp(ZHTargetLookAt.current, speed)
    state.camera.lookAt(currentLookAt.current)
  })

  if (debug) {
    return (
        <>
            <OrbitControls ref={controlsRef} makeDefault />
            <mesh position={currentLookAt.current} scale={0.05} visible={false}>
                <sphereGeometry />
                <meshBasicMaterial color="hotpink" wireframe />
            </mesh>
        </>
    )
  }

  return null
})
