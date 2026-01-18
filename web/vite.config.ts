import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  base: './', // 关键：确保构建后的资源路径为相对路径
  build: {
    outDir: '../WebResources', // 直接构建到 Swift 项目的资源目录，替换原来的文件夹
    emptyOutDir: true,
  },
});
