// web/src/App.tsx
import { Canvas } from '@react-three/fiber'
import { Avatar } from './components/Avatar'
import { useNativeBridge } from './hooks/useBridge'

function App() {
  const { mouseRef, cameraMode } = useNativeBridge()

  return (
    // 1. 设置 Canvas 背景透明
    <div style={{ width: '100vw', height: '100vh', background: 'transparent' }}>
      <Canvas
        camera={{ position: [0, 1.4, 0.6], fov: 40 }}
        gl={{ alpha: true, antialias: true }} // 关键：允许透明背景
      >
        {/* 灯光设置 */}
        <directionalLight position={[1, 1, 1]} intensity={1.2} />
        <ambientLight intensity={0.8} />

        {/* 我们的主角 */}
        <Avatar mouseRef={mouseRef} mode={cameraMode} />
      </Canvas>
    </div>
  )
}

export default App
