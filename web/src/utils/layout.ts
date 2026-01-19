// [修改] 更新默认配置以匹配 Swift 中的 NotchConfig
export const DEFAULT_CONFIG = {
  // Head 模式：对应 Swift 中的 NotchConfig.VRM.headSize (30x30)
  head: {
    width: 30,
    height: 30,
    radius: '8px', // 对应 NotchConfig.VRM.headCornerRadius
    name: 'Compact Head',
  },

  // Body 模式：对应 Swift 中的 expandedWebWidth (320) 和 openSize.height (190)
  body: {
    width: 320, // 640 * 0.5
    height: 190, // NotchConfig.openSize.height
    radius: '12px', // 对应 NotchConfig.VRM.bodyCornerRadius
    name: 'Expanded Body',
  },
};

export interface ViewportConfig {
  width: number;
  height: number;
  radius: string;
  name: string;
}

export function calculateLayout(
  config: ViewportConfig,
  windowWidth: number,
  windowHeight: number
) {
  // 缩放比例：让模拟框占据屏幕的 60% (保持不变，方便调试查看)
  const scale = Math.min(
    (windowWidth * 0.6) / config.width,
    (windowHeight * 0.6) / config.height
  );

  const width = config.width * scale;
  const height = config.height * scale;

  const x = (windowWidth - width) / 2;
  const y = (windowHeight - height) / 2;

  return {
    width,
    height,
    x,
    y,
    scale,
    radius: config.radius,
    name: config.name,
  };
}
