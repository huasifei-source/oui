<template>
  <div class="wireless-container">

    <!-- 全局操作 -->
    <div class="global-actions" v-if="!loading">
      <el-card shadow="never" class="action-card">
        <div class="action-content">
          <div class="action-info">
            <el-icon class="action-icon"><Setting /></el-icon>
            <span>{{ $t('Wireless Service Control') }}</span>
          </div>
          <div class="action-buttons">
            <el-button type="success" @click="restartWireless" :loading="restarting" size="large">
              <el-icon><Refresh /></el-icon>
              {{ $t('Restart Wireless') }}
            </el-button>
          </div>
        </div>
      </el-card>
    </div>

    <!-- 加载状态 -->
    <div v-if="loading" class="loading-container">
      <el-icon class="is-loading loading-icon"><Loading /></el-icon>
      <span class="loading-text">{{ $t('Loading...') }}</span>
    </div>
    
    <!-- 无线电管理 -->
    <div v-else class="radio-grid">
      <div v-for="(radio, radioName) in radioConfigs" :key="radioName" class="radio-card">
        <el-card shadow="hover" class="radio-main-card">
          <!-- 卡片头部 -->
          <template #header>
            <div class="radio-header">
              <div class="radio-title">
                <el-icon class="radio-icon">
                  <svg viewBox="0 0 24 24" fill="currentColor">
                    <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10s10-4.48 10-10S17.52 2 12 2zm-1 17.93c-3.94-.49-7-3.85-7-7.93s3.05-7.44 7-7.93v15.86zm2-15.86c3.94.49 7 3.85 7 7.93s-3.05 7.44-7 7.93V4.07z"/>
                  </svg>
                </el-icon>
                <span class="radio-name">{{ getRadioDisplayName(radioName) }}</span>
                <el-tag :type="getRadioStatus(radioName).type" size="small" class="status-tag">
                  {{ getRadioStatus(radioName).text }}
                </el-tag>
              </div>
              <div class="radio-actions">
                <el-switch 
                  v-model="radio.enabled" 
                  size="large"
                  :active-text="$t('Enable')"
                  :inactive-text="$t('Disable')"
                  @change="markRadioChanged(radioName)"
                />
              </div>
            </div>
          </template>

          <!-- 状态信息 -->
          <div class="radio-status" v-if="radio.enabled">
            <div class="status-grid">
              <div class="status-item">
                <span class="status-label">{{ $t('Band') }}</span>
                <span class="status-value">{{ getRadioBand(radioName) }}</span>
              </div>
              <div class="status-item">
                <span class="status-label">{{ $t('Channel') }}</span>
                <span class="status-value">{{ getRadioChannel(radioName) }}</span>
              </div>
              <div class="status-item">
                <span class="status-label">{{ $t('HT Mode') }}</span>
                <span class="status-value">{{ getRadioHtMode(radioName) }}</span>
              </div>
              <div class="status-item">
                <span class="status-label">{{ $t('Interfaces') }}</span>
                <span class="status-value">{{ getInterfaceCount(radioName) }}</span>
              </div>
            </div>
          </div>

          <!-- 配置表单 -->
          <div v-if="radio.enabled" class="radio-config">
            <el-divider>{{ $t('Radio Configuration') }}</el-divider>
            <el-form :model="radio" label-width="120px" size="default" class="config-form">
              <el-row :gutter="20">
                <el-col :span="12">
                  <el-form-item :label="$t('Channel')">
                    <el-select v-model="radio.channel" @change="markRadioChanged(radioName)" style="width: 100%">
                      <el-option label="Auto" value="auto"/>
                      <el-option v-for="ch in getChannelOptions(radioName)" :key="ch.value" 
                                :label="ch.label" :value="ch.value"/>
                    </el-select>
                  </el-form-item>
                </el-col>
                <el-col :span="12">
                  <el-form-item :label="$t('HT Mode')">
                    <el-select v-model="radio.htmode" @change="markRadioChanged(radioName)" style="width: 100%">
                      <el-option v-for="mode in getHtModeOptions(radioName)" :key="mode.value" 
                                :label="mode.label" :value="mode.value"/>
                    </el-select>
                  </el-form-item>
                </el-col>
              </el-row>
            </el-form>

            <!-- 接口配置 - Tab形式 -->
            <el-divider>{{ $t('Wireless Interfaces') }}</el-divider>
            <div class="interface-section">
              <div class="interface-actions">
                <el-button type="primary" @click="showAddInterfaceDialog(radioName)" size="small">
                  <el-icon><Plus /></el-icon>
                  {{ $t('Add Interface') }}
                </el-button>
              </div>
              
              <el-tabs 
                v-model="activeInterfaceTabs[radioName]" 
                type="card" 
                class="interface-tabs"
                v-if="getRadioInterfaceList(radioName).length > 0"
              >
                <el-tab-pane 
                  v-for="(iface, ifaceName) in getRadioInterfaces(radioName)" 
                  :key="ifaceName"
                  :label="getInterfaceDisplayName(iface, ifaceName, radioName)"
                  :name="ifaceName"
                >
                  <div class="interface-content">
                    <!-- 接口状态 -->
                    <div class="interface-status">
                      <div class="interface-header">
                        <span class="interface-name">{{ getInterfaceDisplayName(iface, ifaceName, radioName) }}</span>
                        <div class="interface-controls">
                          <el-switch 
                            v-model="iface.enabled" 
                            :active-text="$t('Enable')"
                            :inactive-text="$t('Disable')"
                            @change="markInterfaceChanged(ifaceName)"
                          />
                          <el-button type="danger" size="small" @click="deleteInterface(ifaceName)">
                            <el-icon><Delete /></el-icon>
                          </el-button>
                        </div>
                      </div>
                    </div>

                    <!-- 接口配置表单 -->
                    <el-form :model="iface" label-width="120px" size="default" v-if="iface.enabled" class="interface-form">
                      <el-row :gutter="20">
                        <el-col :span="24">
                          <el-form-item :label="$t('SSID')">
                            <el-input v-model="iface.ssid" @change="markInterfaceChanged(ifaceName)"/>
                          </el-form-item>
                        </el-col>
                      </el-row>
                      <el-row :gutter="20">
                        <el-col :span="12">
                          <el-form-item :label="$t('Encryption')">
                            <el-select v-model="iface.encryption" @change="onEncryptionChange(ifaceName)" style="width: 100%">
                              <el-option v-for="enc in encryptionModes" :key="enc.value" 
                                        :label="enc.label" :value="enc.value"/>
                            </el-select>
                          </el-form-item>
                        </el-col>
                        <el-col :span="12" v-if="needsPassword(iface.encryption)">
                          <el-form-item :label="$t('Password')">
                            <el-input v-model="iface.key" type="password" show-password 
                                     @change="markInterfaceChanged(ifaceName)"/>
                          </el-form-item>
                        </el-col>
                      </el-row>
                      <el-row :gutter="20">
                        <el-col :span="12">
                          <el-form-item :label="$t('Hidden Network')">
                            <el-switch v-model="iface.hidden" @change="markInterfaceChanged(ifaceName)"/>
                          </el-form-item>
                        </el-col>
                      </el-row>
                    </el-form>
                  </div>
                </el-tab-pane>
              </el-tabs>
              
              <div v-else class="no-interfaces">
                <el-empty :description="$t('No interfaces configured')" :image-size="80"/>
              </div>
            </div>

            <!-- 保存按钮 -->
            <div class="save-actions" v-if="hasChanges(radioName)">
              <el-alert 
                :title="$t('Configuration changed')" 
                type="warning" 
                :description="$t('Please save to apply changes')"
                show-icon 
                :closable="false"
                class="save-alert"
              />
              <div class="save-buttons">
                <el-button @click="resetRadioChanges(radioName)" size="default">
                  {{ $t('Reset') }}
                </el-button>
                <el-button type="primary" @click="saveRadioConfig(radioName)" :loading="saving" size="default">
                  <el-icon><Check /></el-icon>
                  {{ $t('Save & Apply') }}
                </el-button>
              </div>
            </div>
          </div>
        </el-card>
      </div>
    </div>


    
    <!-- 添加接口对话框 -->
    <el-dialog v-model="addInterfaceDialogVisible" :title="$t('Add Wireless Interface')" width="600px">
      <el-form :model="newInterface" label-width="120px">
        <el-form-item :label="$t('SSID')" required>
          <el-input v-model="newInterface.ssid" placeholder="Enter SSID"/>
        </el-form-item>
        
        <el-form-item :label="$t('Encryption')">
          <el-select v-model="newInterface.encryption" @change="onNewEncryptionChange">
            <el-option v-for="enc in encryptionModes" :key="enc.value" 
                      :label="enc.label" :value="enc.value"/>
          </el-select>
        </el-form-item>
        
        <el-form-item v-if="needsPassword(newInterface.encryption)" :label="$t('Password')" required>
          <el-input v-model="newInterface.key" type="password" show-password/>
        </el-form-item>
        
        <el-form-item :label="$t('Hidden Network')">
          <el-switch v-model="newInterface.hidden"/>
        </el-form-item>
      </el-form>
      
      <template #footer>
        <span>
          <el-button @click="addInterfaceDialogVisible = false">{{ $t('Cancel') }}</el-button>
          <el-button type="primary" @click="addInterface" :loading="saving">{{ $t('Add') }}</el-button>
        </span>
      </template>
    </el-dialog>
  </div>
</template>

<script>
import { Loading, Plus, Delete, Check, Setting, Refresh } from '@element-plus/icons-vue'

export default {
  components: {
    Loading, Plus, Delete, Check, Setting, Refresh
  },
  data() {
    return {
      loading: true,
      saving: false,
      restarting: false,
      wirelessStatus: {},
      radioConfigs: {},
      interfaceConfigs: {},
      encryptionModes: [],
      frequencyLists: {}, // 存储每个 radio 的频段列表
      addInterfaceDialogVisible: false,
      currentRadio: '',
      newInterface: {
        ssid: '',
        mode: 'ap',
        encryption: 'none',
        key: '',
        hidden: false,
        network: 'lan'
      },
      // 新增状态管理
      originalRadioConfigs: {}, // 原始配置，用于重置
      originalInterfaceConfigs: {}, // 原始接口配置
      changedRadios: new Set(), // 已修改的 radio
      changedInterfaces: new Set(), // 已修改的接口
      activeInterfaceTabs: {}, // 每个 radio 的活跃 tab
      isDarkMode: false // 深色模式状态
    }
  },
  created() {
    this.loadData()
  },
  mounted() {
    // 监听系统主题变化
    if (window.matchMedia) {
      const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)')
    }
  },
  beforeUnmount() {
    // 清理事件监听器
    if (window.matchMedia) {
      const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)')
    }
  },
  methods: {
    async loadData() {
      this.loading = true
      try {
        await Promise.all([
          this.loadWirelessStatus(),
          this.loadWirelessConfig(),
          this.loadEncryptionModes(),
          this.loadFrequencyLists()
        ])
        this.initTabStates()
      } catch (error) {
        this.$message.error(this.$t('Failed to load wireless data'))
      }
      this.loading = false
    },
    
    async loadWirelessStatus() {
      try {
        const { status } = await this.$oui.call('wireless', 'get_wireless_status')
        this.wirelessStatus = status || {}
      } catch (error) {
        console.error('Failed to load wireless status:', error)
      }
    },
    
    async loadWirelessConfig() {
      try {
        const { radios, interfaces } = await this.$oui.call('wireless', 'get_wireless_config')
        
        // 转换配置格式
        this.radioConfigs = {}
        this.originalRadioConfigs = {}
        for (const [radioName, radio] of Object.entries(radios || {})) {
          const config = {
            ...radio,
            enabled: !radio.disabled
          }
          this.radioConfigs[radioName] = { ...config }
          this.originalRadioConfigs[radioName] = { ...config }
        }
        
        this.interfaceConfigs = {}
        this.originalInterfaceConfigs = {}
        for (const [ifaceName, iface] of Object.entries(interfaces || {})) {
          const config = {
            ...iface,
            enabled: !iface.disabled,
            mode: 'ap', // 强制设置为 AP 模式
            network: 'lan' // 强制设置为 lan 网络
          }
          this.interfaceConfigs[ifaceName] = { ...config }
          this.originalInterfaceConfigs[ifaceName] = { ...config }
        }
        
        // 清空修改状态
        this.changedRadios.clear()
        this.changedInterfaces.clear()
      } catch (error) {
        console.error('Failed to load wireless config:', error)
      }
    },
    
    async loadEncryptionModes() {
      try {
        const { modes } = await this.$oui.call('wireless', 'get_encryption_modes')
        this.encryptionModes = modes || []
      } catch (error) {
        console.error('Failed to load encryption modes:', error)
      }
    },
    
    async loadFrequencyLists() {
      try {
        this.frequencyLists = {}
        
        // 等待无线状态和配置加载完成
        await Promise.all([this.loadWirelessStatus(), this.loadWirelessConfig()])
        
        // 获取所有 radio 并加载其频段列表
        for (const [radioName] of Object.entries(this.radioConfigs)) {
          try {
            // 尝试从无线状态中获取第一个可用的接口
            const radioStatus = this.wirelessStatus[radioName]
            if (radioStatus && radioStatus.interfaces && radioStatus.interfaces.length > 0) {
              const firstInterface = radioStatus.interfaces[0]
              const deviceName = firstInterface.ifname || firstInterface.section
              
              if (deviceName) {
                const result = await this.$oui.ubus('iwinfo', 'freqlist', {
                  device: deviceName
                })
                this.frequencyLists[radioName] = result.results || []
              }
            } else {
              // 如果无线状态中没有接口，尝试从配置中查找
              const interfaceNames = Object.keys(this.interfaceConfigs).filter(name => 
                this.interfaceConfigs[name].device === radioName
              )
              
              if (interfaceNames.length > 0) {
                // 构造设备名称（通常是 phy-ap 格式）
                const phyName = radioName.replace('radio', 'phy')
                const deviceName = `${phyName}-ap0`
                
                try {
                  const result = await this.$oui.ubus('iwinfo', 'freqlist', {
                    device: deviceName
                  })
                  this.frequencyLists[radioName] = result.results || []
                } catch (error) {
                  console.error(`Failed to get freqlist for ${deviceName}, trying with radio name`)
                  // 如果上面的方式失败，直接使用 radio 名称
                  try {
                    const result = await this.$oui.ubus('iwinfo', 'freqlist', {
                      device: radioName
                    })
                    this.frequencyLists[radioName] = result.results || []
                  } catch (e) {
                    console.error(`Failed to get freqlist for ${radioName}:`, e)
                    this.frequencyLists[radioName] = []
                  }
                }
              }
            }
          } catch (error) {
            console.error(`Failed to load frequency list for ${radioName}:`, error)
            this.frequencyLists[radioName] = []
          }
        }
      } catch (error) {
        console.error('Failed to load frequency lists:', error)
      }
    },
    
    initTabStates() {
      // 初始化每个 radio 的第一个接口为活跃 tab
      for (const radioName of Object.keys(this.radioConfigs)) {
        const interfaces = this.getRadioInterfaceList(radioName)
        if (interfaces.length > 0) {
          this.activeInterfaceTabs[radioName] = interfaces[0]
        }
      }
    },
    
    // 状态获取方法
    getRadioStatus(radioName) {
      const status = this.wirelessStatus[radioName]
      if (!status) {
        return { type: 'info', text: this.$t('Unknown') }
      }
      return {
        type: status.up ? 'success' : 'danger',
        text: status.up ? this.$t('Active') : this.$t('Inactive')
      }
    },
    
    getRadioBand(radioName) {
      const status = this.wirelessStatus[radioName]
      return status?.config?.band || 'N/A'
    },
    
    getRadioChannel(radioName) {
      const status = this.wirelessStatus[radioName]
      return status?.config?.channel || 'auto'
    },
    
    getRadioHtMode(radioName) {
      const status = this.wirelessStatus[radioName]
      return status?.config?.htmode || 'N/A'
    },
    
    getInterfaceCount(radioName) {
      return this.getRadioInterfaceList(radioName).length
    },
    
    getRadioHwModes(radioName) {
      const status = this.wirelessStatus[radioName]
      return status?.config?.hwmodes_text || status?.interfaces?.[0]?.hwmodes_text || 'N/A'
    },
    
    getRadioTxPower(radioName) {
      const status = this.wirelessStatus[radioName]
      const power = status?.config?.txpower || status?.interfaces?.[0]?.txpower
      return power ? `${power}` : 'N/A'
    },
    
    getRadioFrequency(radioName) {
      const status = this.wirelessStatus[radioName]
      const freq = status?.config?.frequency || status?.interfaces?.[0]?.frequency
      return freq ? `${freq} MHz` : 'N/A'
    },
    
    getRadioHardware(radioName) {
      const status = this.wirelessStatus[radioName]
      return status?.config?.hardware?.name || status?.interfaces?.[0]?.hardware?.name || 'N/A'
    },
    
    getHtModeOptions(radioName) {
      const displayName = this.getRadioDisplayName(radioName)
      
      if (displayName === '2.4G') {
        // 2.4G 频段只显示 20MHz 和 40MHz
        return [
          { value: 'HT20', label: '20MHz (HT20)' },
          { value: 'HT40', label: '40MHz (HT40)' }
        ]
      } else {
        // 5G 频段显示更多选项
        return [
          { value: 'HE20', label: '20MHz (HE20)' },
          { value: 'HE40', label: '40MHz (HE40)' },
          { value: 'HE80', label: '80MHz (HE80)' },
          { value: 'HE160', label: '160MHz (HE160)' }
        ]
      }
    },
    
    getRadioInterfaces(radioName) {
      const interfaces = {}
      for (const [ifaceName, iface] of Object.entries(this.interfaceConfigs)) {
        if (iface.device === radioName) {
          interfaces[ifaceName] = iface
        }
      }
      return interfaces
    },
    
    getRadioInterfaceList(radioName) {
      return Object.keys(this.getRadioInterfaces(radioName))
    },
    
    // 获取 Radio 显示名称（2.4G, 5G 等）
    getRadioDisplayName(radioName) {
      const status = this.wirelessStatus[radioName]
      let band = status?.config?.band || this.radioConfigs[radioName]?.band || ''
      
      // 如果没有band信息，尝试从频率判断
      if (!band) {
        const frequency = status?.config?.frequency || status?.interfaces?.[0]?.frequency
        if (frequency) {
          if (frequency >= 2400 && frequency <= 2500) {
            band = '2g'
          } else if (frequency >= 5000 && frequency <= 6000) {
            band = '5g'
          } else if (frequency >= 6000 && frequency <= 7000) {
            band = '6g'
          }
        }
      }
      
      // 如果还是没有频段信息，从动态频段列表判断
      if (!band) {
        const frequencyList = this.frequencyLists[radioName] || []
        if (frequencyList.length > 0) {
          const avgFreq = frequencyList.reduce((sum, freq) => sum + freq.mhz, 0) / frequencyList.length
          if (avgFreq >= 2400 && avgFreq <= 2500) {
            band = '2g'
          } else if (avgFreq >= 5000 && avgFreq <= 6000) {
            band = '5g'
          } else if (avgFreq >= 6000 && avgFreq <= 7000) {
            band = '6g'
          }
        }
      }
      
      // 统计同频段的 radio 数量
      const sameBandRadios = Object.keys(this.radioConfigs).filter(rName => {
        const rStatus = this.wirelessStatus[rName]
        let rBand = rStatus?.config?.band || this.radioConfigs[rName]?.band || ''
        
        // 同样的逻辑判断其他radio的频段
        if (!rBand) {
          const rFrequency = rStatus?.config?.frequency || rStatus?.interfaces?.[0]?.frequency
          if (rFrequency) {
            if (rFrequency >= 2400 && rFrequency <= 2500) {
              rBand = '2g'
            } else if (rFrequency >= 5000 && rFrequency <= 6000) {
              rBand = '5g'
            } else if (rFrequency >= 6000 && rFrequency <= 7000) {
              rBand = '6g'
            }
          }
        }
        
        return rBand === band
      })
      
      let displayName = ''
      if (band === '2g') {
        displayName = '2.4G'
      } else if (band === '5g') {
        displayName = '5G'
      } else if (band === '6g') {
        displayName = '6G'
      } else {
        // 如果还是无法判断，基于radio名称
        displayName = radioName.includes('1') ? '5G' : '2.4G'
      }
      
      // 如果有多个相同频段的 radio，添加序号
      if (sameBandRadios.length > 1) {
        const index = sameBandRadios.indexOf(radioName)
        displayName += ` (${index + 1})`
      }
      
      return displayName
    },
    
    // 获取接口显示名称（SSID1, SSID2 等）
    getInterfaceDisplayName(iface, ifaceName, radioName) {
      const radioInterfaces = this.getRadioInterfaceList(radioName)
      const index = radioInterfaces.indexOf(ifaceName)
      
      if (iface.ssid) {
        // 如果有多个接口，显示为 SSID1, SSID2 等
        if (radioInterfaces.length > 1) {
          return `${iface.ssid}${index + 1}`
        } else {
          return iface.ssid
        }
      } else {
        // 没有 SSID 时显示默认名称
        return `SSID${index + 1}`
      }
    },
    
    getChannelOptions(radioName) {
      const frequencyList = this.frequencyLists[radioName] || []
      
      // 如果没有频段列表，返回空数组
      if (frequencyList.length === 0) {
        console.warn(`No frequency list available for ${radioName}`)
        return []
      }
      
      // 将频段列表转换为信道选项
      const options = frequencyList.map(freq => ({
        label: `${freq.channel} (${freq.mhz} MHz)`,
        value: freq.channel.toString()
      }))
      
      console.log(`Channel options for ${radioName}:`, options)
      return options
    },
    
    needsPassword(encryption) {
      return encryption && encryption !== 'none' && encryption !== ''
    },
    
    // 修改追踪方法
    markRadioChanged(radioName) {
      this.changedRadios.add(radioName)
    },
    
    markInterfaceChanged(ifaceName) {
      this.changedInterfaces.add(ifaceName)
      // 同时标记相关的 radio 为已修改
      const iface = this.interfaceConfigs[ifaceName]
      if (iface && iface.device) {
        this.changedRadios.add(iface.device)
      }
    },
    
    hasChanges(radioName) {
      return this.changedRadios.has(radioName)
    },
    
    // 保存和重置方法
    async saveRadioConfig(radioName) {
      this.saving = true
      try {
        const radio = this.radioConfigs[radioName]
        
        // 保存 radio 配置
        await this.$oui.call('wireless', 'set_radio_config', {
          radio: radioName,
          disabled: !radio.enabled,
          channel: radio.channel,
          htmode: radio.htmode
        })
        
        // 保存相关接口配置
        for (const [ifaceName, iface] of Object.entries(this.getRadioInterfaces(radioName))) {
          if (this.changedInterfaces.has(ifaceName)) {
            await this.$oui.call('wireless', 'set_interface_config', {
              interface: ifaceName,
              disabled: !iface.enabled,
              ssid: iface.ssid,
              mode: 'ap', // 强制设置为 AP 模式
              encryption: iface.encryption,
              key: iface.key,
              hidden: iface.hidden,
              network: 'lan'  // 固定为 lan 网络
            })
          }
        }
        
        // 重新加载配置（应用更改但不重启服务）
        await this.$oui.reloadConfig('wireless')
        
        // 重新加载本地配置状态
        await this.reloadWirelessConfig()
        
        this.$message.success(this.$t('Configuration saved and applied'))
      } catch (error) {
        this.$message.error(this.$t('Failed to save configuration'))
        console.error('Save error:', error)
      }
      this.saving = false
    },
    
    resetRadioChanges(radioName) {
      // 重置 radio 配置
      if (this.originalRadioConfigs[radioName]) {
        this.radioConfigs[radioName] = { ...this.originalRadioConfigs[radioName] }
      }
      
      // 重置相关接口配置
      for (const ifaceName of this.getRadioInterfaceList(radioName)) {
        if (this.originalInterfaceConfigs[ifaceName]) {
          this.interfaceConfigs[ifaceName] = { ...this.originalInterfaceConfigs[ifaceName] }
        }
        this.changedInterfaces.delete(ifaceName)
      }
      
      this.changedRadios.delete(radioName)
    },
    
    async reloadWirelessConfig() {
      // 重新加载配置但不重启服务
      await this.loadWirelessConfig()
      await this.loadWirelessStatus()
    },
    
    onEncryptionChange(ifaceName) {
      const iface = this.interfaceConfigs[ifaceName]
      if (!this.needsPassword(iface.encryption)) {
        iface.key = ''
      }
      this.markInterfaceChanged(ifaceName)
    },
    
    onNewEncryptionChange() {
      if (!this.needsPassword(this.newInterface.encryption)) {
        this.newInterface.key = ''
      }
    },
    
    showAddInterfaceDialog(radioName) {
      this.currentRadio = radioName
      this.newInterface = {
        ssid: '',
        mode: 'ap',
        encryption: 'none',
        key: '',
        hidden: false,
        network: 'lan'
      }
      this.addInterfaceDialogVisible = true
    },
    
    async addInterface() {
      if (!this.newInterface.ssid) {
        this.$message.error(this.$t('Please enter SSID'))
        return
      }
      
      if (this.needsPassword(this.newInterface.encryption) && !this.newInterface.key) {
        this.$message.error(this.$t('Please enter password'))
        return
      }
      
      this.saving = true
      try {
        const { section } = await this.$oui.call('wireless', 'add_wireless_interface', {
          device: this.currentRadio,
          ssid: this.newInterface.ssid,
          mode: this.newInterface.mode,
          encryption: this.newInterface.encryption,
          key: this.newInterface.key,
          hidden: this.newInterface.hidden,
          network: 'lan'  // 固定为 lan 网络
        })
        
        this.addInterfaceDialogVisible = false
        await this.loadWirelessConfig()
        
        // 切换到新添加的接口 tab
        this.activeInterfaceTabs[this.currentRadio] = section
        
        this.$message.success(this.$t('Interface added successfully'))
      } catch (error) {
        this.$message.error(this.$t('Failed to add interface'))
      }
      this.saving = false
    },
    
    async deleteInterface(ifaceName) {
      this.$confirm(this.$t('Are you sure you want to delete this interface?'), this.$t('Confirm'), {
        type: 'warning'
      }).then(async () => {
        try {
          await this.$oui.call('wireless', 'delete_wireless_interface', {
            interface: ifaceName
          })
          await this.loadWirelessConfig()
          this.initTabStates()
          this.$message.success(this.$t('Interface deleted successfully'))
        } catch (error) {
          this.$message.error(this.$t('Failed to delete interface'))
        }
      })
    },
    
    async restartWireless() {
      this.restarting = true
      try {
        await this.$oui.call('wireless', 'restart_wireless')
        this.$message.success(this.$t('Wireless service restarted'))
        // 等待一下再重新加载状态
        setTimeout(() => {
          this.loadWirelessStatus()
        }, 3000)
      } catch (error) {
        this.$message.error(this.$t('Failed to restart wireless service'))
      }
      this.restarting = false
    },
    
  }
}
</script>

<style scoped>
/* CSS 变量定义 */
.wireless-container {
  --bg-gradient-light: linear-gradient(135deg, #f5f7fa 0%, #c3cfe2 100%);
  --bg-gradient-dark: linear-gradient(135deg, #1a1a1a 0%, #2d2d2d 100%);
  --card-bg-light: rgba(255, 255, 255, 0.95);
  --card-bg-dark: rgba(42, 42, 42, 0.95);
  --card-border-light: rgba(255, 255, 255, 0.2);
  --card-border-dark: rgba(255, 255, 255, 0.1);
  --text-primary-light: #303133;
  --text-primary-dark: #e4e4e7;
  --text-secondary-light: #606266;
  --text-secondary-dark: #a1a1aa;
  --status-bg-light: linear-gradient(135deg, #f8fafc 0%, #e2e8f0 100%);
  --status-bg-dark: linear-gradient(135deg, #1e293b 0%, #0f172a 100%);
  --status-text-light: #334155;
  --status-text-dark: #cbd5e1;
  --status-border-light: #cbd5e1;
  --status-border-dark: #475569;
  --interface-bg-light: #fafafa;
  --interface-bg-dark: #1f1f1f;
  --interface-card-light: white;
  --interface-card-dark: #2a2a2a;
  --save-bg-light: #fff9e6;
  --save-bg-dark: #1c1917;
  --save-border-light: #ffd04b;
  --save-border-dark: #ca8a04;
  --no-interface-border-light: #e4e7ed;
  --no-interface-border-dark: #4b5563;
  --shadow-light: rgba(0, 0, 0, 0.1);
  --shadow-dark: rgba(0, 0, 0, 0.3);
  /* 新增：header和action区域的更深灰色色调 */
  --header-bg-light: linear-gradient(135deg, #dbeafe 0%, #93c5fd 100%);
  --header-bg-dark: linear-gradient(135deg, #1f2937 0%, #111827 100%);
  --header-text-light: #ffffff;
  --header-text-dark: #f9fafb;
  --header-border-light: #93c5fd;
  --header-border-dark: #374151;
}

.wireless-container {
  padding: 20px;
  min-height: 100vh;
  background: var(--bg-gradient-light);
  transition: background 0.3s ease;
}

/* 深色模式 */
.dark .wireless-container {
  background: var(--bg-gradient-dark);
}

.loading-container {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  height: 400px;
  color: var(--text-secondary-light);
  transition: color 0.3s ease;
}

.dark .loading-container {
  color: var(--text-secondary-dark);
}

.loading-icon {
  font-size: 48px;
  margin-bottom: 16px;
  color: #409EFF;
}

.loading-text {
  font-size: 16px;
}

.radio-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(800px, 1fr));
  gap: 24px;
  margin-bottom: 24px;
}

.radio-card {
  animation: fadeInUp 0.6s ease-out;
}

@keyframes fadeInUp {
  from {
    opacity: 0;
    transform: translateY(30px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.radio-main-card {
  border-radius: 16px;
  box-shadow: 0 8px 32px var(--shadow-light);
  border: 1px solid var(--card-border-light);
  background: var(--card-bg-light);
  backdrop-filter: blur(10px);
  transition: all 0.3s ease;
}

.dark .radio-main-card {
  box-shadow: 0 8px 32px var(--shadow-dark);
  border: 1px solid var(--card-border-dark);
  background: var(--card-bg-dark);
}

.radio-main-card:hover {
  transform: translateY(-4px);
  box-shadow: 0 12px 40px rgba(0, 0, 0, 0.15);
}

.dark .radio-main-card:hover {
  box-shadow: 0 12px 40px rgba(0, 0, 0, 0.4);
}

.radio-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin: -8px 0;
}

.radio-title {
  display: flex;
  align-items: center;
  gap: 12px;
}

.radio-icon {
  font-size: 24px;
  color: #409EFF;
}

.radio-name {
  font-size: 18px;
  font-weight: 600;
  color: #1a1a1a;
  transition: color 0.3s ease;
}

.dark .radio-name {
  color: var(--header-text-dark);
}

.radio-actions {
  display: flex;
  align-items: center;
  gap: 12px;
}

.radio-status {
  margin-bottom: 24px;
  padding: 16px;
  background: var(--status-bg-light);
  border-radius: 12px;
  color: var(--status-text-light);
  border: 1px solid var(--status-border-light);
  transition: all 0.3s ease;
}

.dark .radio-status {
  background: var(--status-bg-dark);
  color: var(--status-text-dark);
  border: 1px solid var(--status-border-dark);
}

.status-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(140px, 1fr));
  gap: 16px;
}

.status-item {
  text-align: center;
}

.status-label {
  display: block;
  font-size: 12px;
  opacity: 0.7;
  margin-bottom: 4px;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  font-weight: 500;
}

.status-value {
  display: block;
  font-size: 14px;
  font-weight: 600;
  color: #1e293b;
  transition: color 0.3s ease;
}

.dark .status-value {
  color: #cbd5e1;
}

.radio-config {
  margin-top: 24px;
}

.config-form {
  margin-bottom: 24px;
}

.interface-section {
  margin-top: 16px;
}

.interface-actions {
  margin-bottom: 16px;
  display: flex;
  justify-content: flex-start;
}

.interface-tabs {
  margin-bottom: 16px;
}

.interface-content {
  background: var(--interface-bg-light);
  border-radius: 8px;
  padding: 16px;
  transition: background 0.3s ease;
}

.dark .interface-content {
  background: var(--interface-bg-dark);
}

.interface-status {
  margin-bottom: 16px;
}

.interface-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 12px;
  background: var(--interface-card-light);
  border-radius: 8px;
  box-shadow: 0 2px 8px var(--shadow-light);
  transition: all 0.3s ease;
}

.dark .interface-header {
  background: var(--interface-card-dark);
  box-shadow: 0 2px 8px var(--shadow-dark);
}

.interface-name {
  font-weight: 600;
  color: var(--text-primary-light);
  transition: color 0.3s ease;
}

.dark .interface-name {
  color: var(--text-primary-dark);
}

.interface-controls {
  display: flex;
  align-items: center;
  gap: 12px;
}

.interface-form {
  background: var(--interface-card-light);
  padding: 16px;
  border-radius: 8px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.05);
  transition: all 0.3s ease;
}

.dark .interface-form {
  background: var(--interface-card-dark);
  box-shadow: 0 2px 8px var(--shadow-dark);
}

.no-interfaces {
  text-align: center;
  padding: 40px;
  background: var(--interface-card-light);
  border-radius: 8px;
  border: 2px dashed var(--no-interface-border-light);
  transition: all 0.3s ease;
}

.dark .no-interfaces {
  background: var(--interface-card-dark);
  border: 2px dashed var(--no-interface-border-dark);
}

.save-actions {
  margin-top: 24px;
  padding: 16px;
  background: var(--save-bg-light);
  border-radius: 8px;
  border: 1px solid var(--save-border-light);
  transition: all 0.3s ease;
}

.dark .save-actions {
  background: var(--save-bg-dark);
  border: 1px solid var(--save-border-dark);
}

.save-alert {
  margin-bottom: 16px;
}

.save-buttons {
  display: flex;
  justify-content: flex-end;
  gap: 12px;
}

.global-actions {
  margin-bottom: 24px;
}

.action-card {
  border-radius: 12px;
  background: var(--header-bg-light);
  border: 1px solid var(--header-border-light);
  transition: all 0.3s ease;
}

.dark .action-card {
  background: var(--header-bg-dark);
  border: 1px solid var(--header-border-dark);
}

.action-content {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 8px 0;
}

.action-buttons {
  display: flex;
  gap: 12px;
  align-items: center;
}

.action-info {
  display: flex;
  align-items: center;
  gap: 12px;
  color: var(--header-text-light);
  font-size: 16px;
  font-weight: 500;
  transition: color 0.3s ease;
}

.dark .action-info {
  color: var(--header-text-dark);
}

.action-icon {
  font-size: 20px;
}

/* Element Plus 样式覆盖 */
:deep(.el-card__header) {
  background: rgba(255, 255, 255, 0.8);
  border-bottom: 1px solid rgba(0, 0, 0, 0.06);
  border-radius: 16px 16px 0 0;
  padding: 20px 24px;
  transition: all 0.3s ease;
}

.dark :deep(.el-card__header) {
  background: linear-gradient(135deg, #374151 0%, #4b5563 100%);
  border-bottom: 1px solid rgba(255, 255, 255, 0.1);
}

:deep(.el-card__body) {
  padding: 24px;
}

:deep(.el-divider) {
  margin: 24px 0 16px 0;
}

:deep(.el-divider__text) {
  background: rgba(255, 255, 255, 0.9);
  color: #606266;
  font-weight: 500;
  padding: 0 16px;
  transition: all 0.3s ease;
}

.dark :deep(.el-divider__text) {
  background: rgba(42, 42, 42, 0.9);
  color: #a1a1aa;
}

.dark :deep(.el-divider) {
  border-color: rgba(255, 255, 255, 0.1);
}

:deep(.el-form-item) {
  margin-bottom: 18px;
}

:deep(.el-form-item__label) {
  font-weight: 500;
  color: #303133;
  transition: color 0.3s ease;
}

.dark :deep(.el-form-item__label) {
  color: #f1f5f9;
}

:deep(.el-tabs__item) {
  font-weight: 500;
  transition: color 0.3s ease;
}

.dark :deep(.el-tabs__item) {
  color: #a1a1aa;
}

.dark :deep(.el-tabs__item.is-active) {
  color: #60a5fa;
}

.dark :deep(.el-tabs__active-bar) {
  background-color: #60a5fa;
}

.dark :deep(.el-tabs__nav-wrap::after) {
  background-color: rgba(255, 255, 255, 0.1);
}

:deep(.el-tabs__content) {
  padding-top: 16px;
}

:deep(.el-button) {
  border-radius: 8px;
  font-weight: 500;
}

:deep(.el-switch) {
  --el-switch-on-color: #409EFF;
}

.dark :deep(.el-switch) {
  --el-switch-on-color: #60a5fa;
}

:deep(.el-tag) {
  border-radius: 6px;
  font-weight: 500;
}

/* 输入框深色模式 */
.dark :deep(.el-input__wrapper) {
  background-color: #374151;
  border-color: #4b5563;
}

.dark :deep(.el-input__inner) {
  color: #e4e4e7;
  background-color: transparent;
}

.dark :deep(.el-input__inner::placeholder) {
  color: #9ca3af;
}

.dark :deep(.el-input__wrapper:hover) {
  border-color: #60a5fa;
}

.dark :deep(.el-input__wrapper.is-focus) {
  border-color: #60a5fa;
  box-shadow: 0 0 0 1px #60a5fa inset;
}

/* 选择框深色模式 */
.dark :deep(.el-select .el-input__wrapper) {
  background-color: #374151;
  border-color: #4b5563;
}

.dark :deep(.el-select-dropdown) {
  background-color: #374151;
  border-color: #4b5563;
}

.dark :deep(.el-select-dropdown__item) {
  color: #e4e4e7;
}

.dark :deep(.el-select-dropdown__item:hover) {
  background-color: #4b5563;
}

.dark :deep(.el-select-dropdown__item.selected) {
  background-color: #60a5fa;
  color: white;
}

/* 对话框深色模式 */
.dark :deep(.el-dialog) {
  background-color: #2a2a2a;
  border: 1px solid rgba(255, 255, 255, 0.1);
}

.dark :deep(.el-dialog__header) {
  border-bottom: 1px solid rgba(255, 255, 255, 0.1);
}

.dark :deep(.el-dialog__title) {
  color: #e4e4e7;
}

.dark :deep(.el-dialog__body) {
  color: #a1a1aa;
}

/* 消息提示深色模式 */
.dark :deep(.el-message) {
  background-color: #374151;
  border-color: #4b5563;
  color: #e4e4e7;
}

/* Empty 组件深色模式 */
.dark :deep(.el-empty__description p) {
  color: #a1a1aa;
}

/* 响应式设计 */
@media (max-width: 1200px) {
  .radio-grid {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 768px) {
  .wireless-container {
    padding: 12px;
  }
  
  .radio-header {
    flex-direction: column;
    gap: 12px;
    align-items: flex-start;
  }
  
  .status-grid {
    grid-template-columns: repeat(2, 1fr);
  }
  
  .interface-header {
    flex-direction: column;
    gap: 12px;
    align-items: flex-start;
  }
  
  .action-content {
    flex-direction: column;
    gap: 16px;
    text-align: center;
  }
  
  .action-buttons {
    flex-direction: column;
    width: 100%;
  }
  
  .action-buttons .el-button {
    width: 100%;
  }
}
</style>

<i18n src="./locale.json"/>
