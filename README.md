# 灵动岛上的 VRM 模型

在灵动岛上展示 VRM 模型的技术验证项目。

> [!WARNING]
> 本项目是一个技术验证项目，大量使用 vibe coding 技术。UI 代码大量参考 [Boring Notch](https://github.com/TheBoredTeam/boring.notch)

> [!IMPORTANT]
> 本项目作为**技术验证项目**，最终愿景为利用 VRM 与 AI 技术，探索面向高龄群体的 **“智能陪伴”** 与面向年轻群体的 **“高效虚拟助理”** 解决方案。
>
> **使用界限：**
> * 本项目并非为满足 **“虚拟恋人”**、**“恋爱模拟”** 或 **“情感替代”** 等需求而设计。
> * 项目中提供的所有被展示的模型资源仅作为技术验证与测试用例，不代表作者的个人倾向。
>
> **倡导：**
> 作者主张理性使用虚拟形象技术，将其作为辅助生活与提升效率的工具。我们 **不鼓励** 用户对虚拟角色产生过度情感投射或非理性的现实解离，并始终支持用户与现实世界建立良性的交互关系。

https://github.com/user-attachments/assets/fca4ba8c-1538-4334-b531-7d4d15a83065

- VRM model: [AvatarSample_A](https://hub.vroid.com/en/characters/2843975675147313744/models/5644550979324015604)
- VRMA motion: [VRM アニメーション 7 種セット（.vrma）](https://booth.pm/en/items/5512385)

## 功能

- 在灵动岛上展示 VRM 模型
- 鼠标位于灵动岛区域时，展开灵动岛，显示更多动作
- 头部与眼睛跟随鼠标移动
- 循环播放 VRMA 动作，即使原本动作不是循环的
- 允许手动调节模型位置与缩放，保证对于不同模型均能较好展示
  - 暂时通过修改代码中的常量实现，后续计划添加 UI 界面进行调节 (WIP)
  - 目前的使用方式：
    - `cd` 到`./web` 目录
    - 修改 `App.tsx` 中的 `const IS_DEBUG_MODE = false` 为 `true`
    - 运行`npm run dev` 启动开发服务器
    - 在对应的浏览器窗口中确定模型位置与缩放，并将复制的值更新回`public/camera.json`文件中
    - 重新编译项目 (记得将 `IS_DEBUG_MODE` 改回 `false`，并`cd`到项目根目录)
- 简单的 API 调用，用于配置人物的表情、话语等后端 (WIP)

### API 说明

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "AgentPerformance",
  "type": "object",
  "properties": {
    "face": {
      "type": "string",
      "description": "Agent's facial expression",
      "enum": [
        "neutral",
        "joy",
        "angry",
        "sorrow",
        "fun",
        "surprise"
      ]
    },
    "intensity": {
      "type": "number",
      "description": "Intensity of the expression (optional)",
      "minimum": 0
    },
    "action": {
      "type": "string",
      "description": "Agent's action, e.g., 'nod', 'shake', 'wave' (optional)"
    },
    "audio_url": {
      "type": "string",
      "description": "URL to the audio file (optional)",
      "format": "uri"
    },
    "duration": {
      "type": "number",
      "description": "Duration of the performance in seconds (optional)",
      "minimum": 0
    }
  },
  "required": [
    "face"
  ],
  "additionalProperties": false
}
```

## 快速开始

- git clone 本仓库
- 下载 VRM 模型与动作资源，放置在 `web/public/` 目录下，命名为`avatar.vrm` 和 `idle.vrma`
- 运行 `bash ./build.sh` 构建项目
- 执行编译后的可执行文件 (暂时需要 `sudo` 权限)
