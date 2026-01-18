import { useEffect, useRef, useState } from 'react'

// 定义全局 Window 接口，匹配 Swift 的调用
declare global {
  interface Window {
    updateMouseParams?: (dx: number, dy: number) => void;
    setCameraMode?: (mode: string) => void;
    updateSize?: (w: number, h: number) => void;
  }
}

export function useNativeBridge() {
  // 1. 鼠标位置使用 Ref (高性能，不触发重渲染)
  const mouseRef = useRef({ x: 0, y: 0 })
  
  // 2. 模式状态使用 State (低频切换，需要触发动画)
  const [cameraMode, setCameraModeState] = useState<'head' | 'body'>('head')

  useEffect(() => {
    // 挂载函数给 Swift 调用
    window.updateMouseParams = (dx, dy) => {
      mouseRef.current = { x: dx, y: dy }
    }

    window.setCameraMode = (mode) => {
      if (mode === 'head' || mode === 'body') {
        setCameraModeState(mode)
      }
    }
    
    // 尺寸更新主要由 CSS/ResizeObserver 自动处理，但也保留接口
    window.updateSize = (w, h) => {
      console.log(`Resized to ${w}x${h}`)
    }

    // 清理
    return () => {
      delete window.updateMouseParams
      delete window.setCameraMode
      delete window.updateSize
    }
  }, [])

  return { mouseRef, cameraMode }
}
