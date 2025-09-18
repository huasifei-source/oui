import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  plugins: [vue()],
  build: {
    lib: {
      entry: 'index.vue',
      name: 'oui-app-wireless-repeater',
      fileName: 'index'
    },
    rollupOptions: {
      external: ['vue', 'element-plus']
    }
  }
})
