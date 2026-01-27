import { useEffect, useRef, useState } from 'react'

// === 1. 定义协议类型 ===
export interface AgentPerformance {
  face: 'neutral' | 'joy' | 'angry' | 'sorrow' | 'fun' | 'surprise';
  intensity?: number;
  action?: string; // 例如 'nod', 'shake', 'wave'
  audio_url?: string;
  // [新增]
  duration?: number;
}

export type AgentState = 'idle' | 'listening' | 'thinking';

declare global {
  interface Window {
    updateMouseParams?: (dx: number, dy: number) => void;
    setCameraMode?: (mode: string) => void;
    updateSize?: (w: number, h: number) => void;
    // [新增] 核心指令接口
    triggerPerformance?: (data: AgentPerformance) => void;
    setAgentState?: (state: AgentState) => void;
    // [新增] 相机配置接口
    setCameraConfig?: (config: CameraConfig) => void;
    updateCameraConfig?: (config: CameraConfig) => void;
    __pendingCameraConfig?: CameraConfig;
  }
}

// [新增] 相机配置类型定义
export interface CameraConfig {
  head: CameraSetting;
  body: CameraSetting;
  lerpSpeed: number;
  // [新增] 鼠标跟随配置
  followMouse: boolean;
}

interface CameraSetting {
  position: { x: number; y: number; z: number };
  target: { x: number; y: number; z: number };
  fov: number;
}

export function useNativeBridge() {
  const mouseRef = useRef({ x: 0, y: 0 })
  const [cameraMode, setCameraModeState] = useState<'head' | 'body'>('head')
  const [windowSize, setWindowSize] = useState<{ width: number, height: number } | null>(null)
  
  // [新增] 状态暴露
  const [agentState, setAgentState] = useState<AgentState>('idle')
  const [performance, setPerformance] = useState<AgentPerformance | null>(null)
  
  // [新增] 相机配置状态
  const [cameraConfig, setCameraConfig] = useState<CameraConfig | null>(null)

  useEffect(() => {
    window.updateMouseParams = (dx, dy) => {
      mouseRef.current = { x: dx, y: dy }
    }

    window.setCameraMode = (mode) => {
      if (mode === 'head' || mode === 'body') {
        setCameraModeState(mode)
      }
    }
    
    window.updateSize = (w, h) => {
      setWindowSize({ width: w, height: h })
    }

    // [新增] 实现协议接口
    window.triggerPerformance = (data) => {
      console.log("[Bridge] Performance:", data)
      setPerformance({ ...data, intensity: data.intensity ?? 1.0 })
    }

    window.setAgentState = (state) => {
      console.log("[Bridge] State:", state)
      setAgentState(state)
    }
    
    // [新增] 相机配置接口
    window.setCameraConfig = (config) => {
      console.log("[Bridge] Initial camera config:", config)
      setCameraConfig(config)
    }
    
    window.updateCameraConfig = (config) => {
      console.log("[Bridge] Updated camera config:", config)
      setCameraConfig(config)
    }
    
    // [新增] 检查是否有待处理的配置（早期注入的情况）
    if (window.__pendingCameraConfig) {
      console.log("[Bridge] Applying pending camera config")
      setCameraConfig(window.__pendingCameraConfig)
      delete window.__pendingCameraConfig
    }

    return () => {
      delete window.updateMouseParams
      delete window.setCameraMode
      delete window.updateSize
      delete window.triggerPerformance
      delete window.setAgentState
      delete window.setCameraConfig
      delete window.updateCameraConfig
    }
  }, [])

  return { mouseRef, cameraMode, windowSize, agentState, performance, cameraConfig }
}
