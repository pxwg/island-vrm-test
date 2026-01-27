import { useState, useRef, useMemo } from 'react'
import { Canvas } from '@react-three/fiber'
import { Avatar } from './components/Avatar'
import { CameraRig } from './components/CameraRig'
import { CameraConfigurator } from './components/CameraConfigurator'
import { ScissorDirector } from './components/ScissorDirector'
import { useNativeBridge } from './hooks/useBridge'
import { DEFAULT_CONFIG } from './utils/layout'
import type { ViewportConfig } from './utils/layout'
import * as THREE from 'three'

function App() {
  // [修改] 解构出 agentState, performance 和 cameraConfig
  const { mouseRef, cameraMode: nativeMode, windowSize: swiftSize, agentState, performance, cameraConfig } = useNativeBridge()
  
  const IS_DEBUG_MODE = false
  
  const [debugMode, setDebugMode] = useState<'head' | 'body'>('head')
  const activeMode = IS_DEBUG_MODE ? debugMode : nativeMode

  const [manualOverride, setManualOverride] = useState<Partial<ViewportConfig>>({})

  const activeConfig = useMemo(() => {
      const base = DEFAULT_CONFIG[activeMode]
      let dynamicWidth = base.width
      let dynamicHeight = base.height
      
      if (swiftSize && swiftSize.width > 0) {
          dynamicWidth = swiftSize.width
          dynamicHeight = swiftSize.height
      }

      return {
          ...base,
          width: manualOverride.width ?? dynamicWidth,
          height: manualOverride.height ?? dynamicHeight,
          name: (swiftSize ? "[Swift Sync] " : "[Manual] ") + base.name
      }
  }, [activeMode, swiftSize, manualOverride])

  const cameraRef = useRef<THREE.PerspectiveCamera | null>(null)
  const orbitRef = useRef<any>(null)

  const headNodeRef = useRef<THREE.Object3D | null>(null)

  return (
    <div style={{ width: '100vw', height: '100vh', background: IS_DEBUG_MODE ? '#111' : 'transparent' }}>
      
      {IS_DEBUG_MODE && (
        <CameraConfigurator 
            currentMode={activeMode} 
            currentConfig={activeConfig}
            onConfigChange={(newConf) => setManualOverride(prev => ({...prev, ...newConf}))}
            onModeChange={setDebugMode}
            cameraRef={cameraRef}
            orbitRef={orbitRef}
        />
      )}

      <Canvas
        onCreated={({ camera }) => {
            cameraRef.current = camera as THREE.PerspectiveCamera
        }}
        gl={{ alpha: true, antialias: true }}
      >
        <ScissorDirector config={activeConfig} active={IS_DEBUG_MODE} />

        <directionalLight position={[1, 1, 1]} intensity={1.2} />
        <ambientLight intensity={0.8} />

        {/* [修改] 传递 agentState, performance 和 cameraConfig */}
        <Avatar 
            mouseRef={mouseRef} 
            mode={activeMode} 
            headNodeRef={headNodeRef} 
            agentState={agentState} 
            performance={performance}
            cameraConfig={cameraConfig}
        />
        <CameraRig 
            ref={orbitRef} 
            mode={activeMode} 
            debug={IS_DEBUG_MODE} 
            headNodeRef={headNodeRef} 
            nativeConfig={cameraConfig}
        />
      </Canvas>
    </div>
  )
}

export default App
