<template>
  <div class="glass-container">
    <div class="glass-background"></div>
    <el-container class="oui-container" style="height: calc(100vh - 16px);">
      <el-aside width="auto" class="glass-aside">
        <el-scrollbar>
          <div v-if="!isCollapse" style="text-align: center;" class="brand-section">
            <div class="brand-logo">
              <div class="logo-orb"></div>
            </div>
            <el-link type="primary" @click="$router.push('/')" :underline="false" class="brand-link">
              {{ $oui.state.hostname }}
            </el-link>
          </div>
          <el-divider v-if="!isCollapse" class="glass-divider"/>
          <el-menu unique-opened router :default-active="selectedMenu" :collapse="isCollapse" class="glass-menu">
            <template v-for="menu in menus" :key="menu.path">
              <el-sub-menu v-if="menu.children" :index="menu.path" class="glass-submenu">
                <template #title>
                  <el-icon v-if="menu.svg" class="menu-icon"><div v-html="renderSvg('svg', menu.svg)"></div></el-icon>
                  <span class="menu-text">{{ $t('menus.' + menu.title) }}</span>
                </template>
                <el-menu-item v-for="submenu in menu.children" :key="submenu.path" :index="submenu.path" class="glass-menu-item">
                  <template #title>{{ $t('menus.' + submenu.title) }}</template>
                </el-menu-item>
              </el-sub-menu>
              <el-menu-item v-else :index="menu.path" class="glass-menu-item">
                <el-icon v-if="menu.svg" class="menu-icon"><div v-html="renderSvg('svg', menu.svg)"></div></el-icon>
                <template #title>{{ $t('menus.' + menu.title) }}</template>
              </el-menu-item>
            </template>
          </el-menu>
        </el-scrollbar>
      </el-aside>
      <el-container class="main-container">
        <el-header class="glass-header">
          <el-icon @click="isCollapse = !isCollapse" class="collapse-icon" :size="25">
            <component :is="isCollapse ? 'Expand' : 'Fold'"/>
          </el-icon>
          <el-space size="large" class="header-actions">
            <el-icon color="#64b5f6" size="24" class="action-icon" @click="$oui.state.isDark = !$oui.state.isDark">
              <component :is="$oui.state.isDark ? MoonIcon : SunnySharpIcon"/>
            </el-icon>
            <el-dropdown @command="lang => $oui.setLocale(lang)" class="action-dropdown">
              <span class="el-dropdown-link glass-button">
                <el-icon><TranslateIcon/></el-icon>
              </span>
              <template #dropdown>
                <el-dropdown-menu class="glass-dropdown">
                  <el-dropdown-item v-for="i in localeOptions" :key="i.key" :command="i.key" :class="{selected: i.key === $oui.state.locale}">{{ i.label }}</el-dropdown-item>
                </el-dropdown-menu>
              </template>
            </el-dropdown>
            <el-dropdown @command="handleUserAction" class="action-dropdown">
              <span class="el-dropdown-link glass-button">
                <el-icon><Avatar/></el-icon>
              </span>
              <template #dropdown>
                <el-dropdown-menu class="glass-dropdown">
                  <el-dropdown-item command="logout" :icon="LogoutIcon">{{ $t('Logout') }}</el-dropdown-item>
                  <el-dropdown-item command="reboot" icon="SwitchButton">{{ $t('Reboot') }}</el-dropdown-item>
                </el-dropdown-menu>
              </template>
            </el-dropdown>
          </el-space>
        </el-header>
        <el-main class="glass-main">
          <el-scrollbar>
            <div class="content-wrapper">
              <router-view/>
            </div>
            <el-backtop target=".oui-container .el-container .el-scrollbar__wrap" class="glass-backtop"/>
          </el-scrollbar>
        </el-main>
        <el-footer class="glass-footer">
        </el-footer>
      </el-container>
    </el-container>
  </div>
</template>

<script>
import {
  Translate as TranslateIcon
} from '@vicons/carbon'

import {
  Moon as MoonIcon,
  SunnySharp as SunnySharpIcon,
  LogOutOutline as LogoutIcon
} from '@vicons/ionicons5'

export default {
  props: {
    menus: {
      type: Array,
      required: true
    }
  },
  components: {
    TranslateIcon
  },
  data() {
    return {
      selectedMenu: '',
      isCollapse: false
    }
  },
  setup() {
    return {
      LogoutIcon,
      MoonIcon,
      SunnySharpIcon
    }
  },
  computed: {
    localeOptions() {
      const titles = {
        'en': 'English',
        'ja-JP': '日本語',
        'zh-CN': '简体中文',
        'zh-TW': '繁體中文'
      }

      const options = this.$i18n.availableLocales.map(locale => {
        return {
          label: titles[locale] ?? locale,
          key: locale
        }
      })

      options.unshift({
        label: this.$t('Auto'),
        key: 'auto'
      })

      return options
    }
  },
  methods: {
    renderSvg(el, opt) {
      const props = []
      const children = []

      Object.keys(opt).forEach(key => {
        if (key.startsWith('-')) {
          props.push(`${key.substring(1)}="${opt[key]}"`)
        } else {
          if (Array.isArray(opt[key]))
            opt[key].forEach(item => children.push(this.renderSvg(key, item)))
          else
            children.push(this.renderSvg(key, opt[key]))
        }
      })

      return `<${el} ${props.join(' ')}>${children.join(' ')}</${el}>`
    },
    handleUserAction(command) {
      if (command === 'logout') {
        this.$oui.logout()
        this.$router.push('/login')
      } else if (command === 'reboot') {
        this.$confirm(this.$t('RebootConfirm'), this.$t('Reboot'), {
          type: 'warning'
        }).then(() => {
          this.$oui.ubus('system', 'reboot').then(() => {
            const loading = this.$loading({
              lock: true,
              text: this.$t('Rebooting') + '...',
              background: 'rgba(0, 0, 0, 0.7)'
            })

            this.$oui.reconnect().then(() => {
              loading.close()
              this.$router.push('/login')
            })
          })
        })
      }
    }
  },
  mounted() {
    this.selectedMenu = this.$route.path
  }
}
</script>

<style scoped>
/* Glass Container with dynamic background */
.glass-container {
  position: relative;
  min-height: 100vh;
  overflow: hidden;
}

.glass-background {
  position: fixed;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background: linear-gradient(135deg, 
    rgba(100, 181, 246, 0.1) 0%,
    rgba(25, 118, 210, 0.15) 25%,
    rgba(13, 71, 161, 0.2) 50%,
    rgba(100, 181, 246, 0.15) 75%,
    rgba(227, 242, 253, 0.1) 100%);
  animation: glassBg 20s ease-in-out infinite;
  z-index: -1;
}

@keyframes glassBg {
  0%, 100% { 
    background: linear-gradient(135deg, 
      rgba(100, 181, 246, 0.1) 0%,
      rgba(25, 118, 210, 0.15) 25%,
      rgba(13, 71, 161, 0.2) 50%,
      rgba(100, 181, 246, 0.15) 75%,
      rgba(227, 242, 253, 0.1) 100%);
  }
  50% { 
    background: linear-gradient(225deg, 
      rgba(227, 242, 253, 0.1) 0%,
      rgba(100, 181, 246, 0.15) 25%,
      rgba(25, 118, 210, 0.2) 50%,
      rgba(13, 71, 161, 0.15) 75%,
      rgba(100, 181, 246, 0.1) 100%);
  }
}

/* Main Container */
.oui-container {
  background: transparent;
  position: relative;
  z-index: 1;
}

/* Glass Aside */
.glass-aside {
  background: rgba(255, 255, 255, 0.15);
  backdrop-filter: blur(20px);
  border: 1px solid rgba(255, 255, 255, 0.2);
  border-radius: 0 20px 20px 0;
  box-shadow: 0 8px 32px rgba(31, 38, 135, 0.37);
  position: relative;
  overflow: hidden;
}

.glass-aside::before {
  content: '';
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: linear-gradient(145deg, 
    rgba(255, 255, 255, 0.1) 0%,
    rgba(255, 255, 255, 0.05) 50%,
    rgba(255, 255, 255, 0.1) 100%);
  z-index: -1;
}

/* Brand Section */
.brand-section {
  padding: 20px;
  margin-bottom: 10px;
}

.brand-logo {
  margin-bottom: 15px;
  display: flex;
  justify-content: center;
}

.logo-orb {
  width: 50px;
  height: 50px;
  background: linear-gradient(135deg, #64b5f6, #1976d2, #0d47a1);
  border-radius: 50%;
  position: relative;
  box-shadow: 0 8px 25px rgba(25, 118, 210, 0.4);
  animation: logoFloat 3s ease-in-out infinite;
}

.logo-orb::before {
  content: '';
  position: absolute;
  top: 15%;
  left: 15%;
  width: 30%;
  height: 30%;
  background: rgba(255, 255, 255, 0.6);
  border-radius: 50%;
  filter: blur(1px);
}

@keyframes logoFloat {
  0%, 100% { transform: translateY(0px) rotate(0deg); }
  50% { transform: translateY(-5px) rotate(180deg); }
}

.brand-link {
  font-size: 18px !important;
  font-weight: 600 !important;
  color: #1976d2 !important;
  text-shadow: 0 2px 4px rgba(255, 255, 255, 0.5);
}

/* Glass Menu */
.glass-menu {
  background: transparent !important;
  border: none !important;
}

.glass-menu-item, .glass-submenu {
  margin: 4px 8px;
  border-radius: 12px;
  transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
  position: relative;
  overflow: hidden;
}

.glass-menu-item:hover, .glass-submenu:hover {
  background: rgba(25, 118, 210, 0.15) !important;
  backdrop-filter: blur(10px);
  transform: translateX(5px);
  box-shadow: 0 4px 15px rgba(25, 118, 210, 0.2);
}

.glass-menu-item.is-active {
  background: rgba(25, 118, 210, 0.25) !important;
  backdrop-filter: blur(10px);
  box-shadow: 0 4px 20px rgba(25, 118, 210, 0.3);
}

.menu-icon {
  margin-right: 8px;
  color: #1976d2;
}

.menu-text {
  color: #0d47a1;
  font-weight: 500;
}

/* Glass Divider */
.glass-divider {
  border-color: rgba(25, 118, 210, 0.2) !important;
  margin: 15px 0 !important;
}

/* Main Container */
.main-container {
  margin-left: 10px;
}

/* Glass Header */
.glass-header {
  background: rgba(255, 255, 255, 0.25) !important;
  backdrop-filter: blur(20px);
  border: 1px solid rgba(255, 255, 255, 0.3);
  border-radius: 20px 20px 0 0;
  box-shadow: 0 4px 20px rgba(31, 38, 135, 0.2);
  display: flex;
  justify-content: space-between;
  align-items: center;
  height: 60px !important;
  padding: 0 25px;
  position: relative;
  overflow: hidden;
}

.glass-header::before {
  content: '';
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: linear-gradient(90deg, 
    rgba(255, 255, 255, 0.1) 0%,
    rgba(255, 255, 255, 0.05) 50%,
    rgba(255, 255, 255, 0.1) 100%);
  z-index: -1;
}

.collapse-icon {
  color: #1976d2;
  cursor: pointer;
  transition: all 0.3s ease;
  padding: 8px;
  border-radius: 50%;
  background: rgba(25, 118, 210, 0.1);
}

.collapse-icon:hover {
  background: rgba(25, 118, 210, 0.2);
  transform: scale(1.1);
}

.header-actions {
  display: flex;
  align-items: center;
  gap: 15px;
}

.action-icon {
  cursor: pointer;
  transition: all 0.3s ease;
  padding: 8px;
  border-radius: 50%;
  background: rgba(100, 181, 246, 0.1);
}

.action-icon:hover {
  background: rgba(100, 181, 246, 0.2);
  transform: scale(1.1);
}

.glass-button {
  padding: 8px 12px;
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.2);
  backdrop-filter: blur(10px);
  border: 1px solid rgba(255, 255, 255, 0.3);
  transition: all 0.3s ease;
  color: #1976d2 !important;
}

.glass-button:hover {
  background: rgba(255, 255, 255, 0.3);
  transform: translateY(-2px);
  box-shadow: 0 4px 15px rgba(25, 118, 210, 0.2);
}

/* Glass Main */
.glass-main {
  background: rgba(255, 255, 255, 0.1) !important;
  backdrop-filter: blur(20px);
  border: 1px solid rgba(255, 255, 255, 0.2);
  border-top: none;
  border-bottom: none;
  position: relative;
  overflow: hidden;
}

.content-wrapper {
  padding: 20px;
  min-height: calc(100vh - 200px);
}

/* Glass Footer */
.glass-footer {
  background: rgba(255, 255, 255, 0.25) !important;
  backdrop-filter: blur(20px);
  border: 1px solid rgba(255, 255, 255, 0.3);
  border-radius: 0 0 20px 20px;
  box-shadow: 0 -4px 20px rgba(31, 38, 135, 0.2);
  height: 50px !important;
  display: flex;
  align-items: center;
  justify-content: center;
}

.copyright {
  text-align: center;
  font-size: 12px;
  color: #1565c0;
  margin: 0;
}

.copyright a {
  color: #1976d2;
  text-decoration: none;
  font-weight: 500;
}

.copyright a:hover {
  color: #0d47a1;
  text-decoration: underline;
}

/* Glass Dropdown */
.glass-dropdown {
  background: rgba(255, 255, 255, 0.9) !important;
  backdrop-filter: blur(20px);
  border: 1px solid rgba(255, 255, 255, 0.3);
  border-radius: 12px;
  box-shadow: 0 8px 32px rgba(31, 38, 135, 0.37);
}

.glass-backtop {
  background: rgba(25, 118, 210, 0.8) !important;
  backdrop-filter: blur(10px);
  border: 1px solid rgba(255, 255, 255, 0.3);
}

/* Element Plus Overrides */
:deep(.el-dropdown-menu__item).selected {
  background: rgba(25, 118, 210, 0.15) !important;
  color: #1976d2 !important;
}

:deep(.el-menu-item):hover {
  background: transparent !important;
}

:deep(.el-sub-menu__title):hover {
  background: transparent !important;
}

:deep(.el-scrollbar__bar) {
  opacity: 0.3;
}

:deep(.el-scrollbar__thumb) {
  background: rgba(25, 118, 210, 0.5);
  border-radius: 10px;
}

/* Responsive Design */
@media (max-width: 768px) {
  .glass-aside {
    border-radius: 0;
  }
  
  .glass-header {
    border-radius: 0;
    padding: 0 15px;
  }
  
  .main-container {
    margin-left: 0;
  }
  
  .content-wrapper {
    padding: 15px;
  }
}

/* Animation for menu items */
.glass-menu-item, .glass-submenu {
  animation: slideInLeft 0.3s ease-out;
}

@keyframes slideInLeft {
  from {
    opacity: 0;
    transform: translateX(-20px);
  }
  to {
    opacity: 1;
    transform: translateX(0);
  }
}

/* Liquid effect on hover */
.glass-button, .action-icon, .collapse-icon {
  position: relative;
  overflow: hidden;
}

.glass-button::before, .action-icon::before, .collapse-icon::before {
  content: '';
  position: absolute;
  top: 50%;
  left: 50%;
  width: 0;
  height: 0;
  background: radial-gradient(circle, rgba(255, 255, 255, 0.3) 0%, transparent 70%);
  transition: all 0.6s ease;
  border-radius: 50%;
  transform: translate(-50%, -50%);
}

.glass-button:hover::before, .action-icon:hover::before, .collapse-icon:hover::before {
  width: 100%;
  height: 100%;
}
</style>

<i18n src="./locale.json"/>
