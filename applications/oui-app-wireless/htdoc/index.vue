<template>
  <div class="wireless-container">
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
                <span class="radio-name">{{ radioName }}</span>
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
                      <el-option v-for="ch in getChannelOptions(radio.band)" :key="ch.value" 
                                :label="ch.label" :value="ch.value"/>
                    </el-select>
                  </el-form-item>
                </el-col>
                <el-col :span="12">
                  <el-form-item :label="$t('HT Mode')">
                    <el-select v-model="radio.htmode" @change="markRadioChanged(radioName)" style="width: 100%">
                      <el-option v-for="mode in htModes" :key="mode.value" 
                                :label="mode.label" :value="mode.value"/>
                    </el-select>
                  </el-form-item>
                </el-col>
              </el-row>
              <el-row :gutter="20">
                <el-col :span="12">
                  <el-form-item :label="$t('TX Power')">
                    <el-input-number 
                      v-model.number="radio.txpower" 
                      :min="1" :max="30" 
                      style="width: 100%"
                      @change="markRadioChanged(radioName)"
                    />
                  </el-form-item>
                </el-col>
                <el-col :span="12">
                  <el-form-item :label="$t('Country')">
                    <el-input v-model="radio.country" @change="markRadioChanged(radioName)" style="width: 100%"/>
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
                  :label="getInterfaceTabLabel(iface, ifaceName)"
                  :name="ifaceName"
                >
                  <div class="interface-content">
                    <!-- 接口状态 -->
                    <div class="interface-status">
                      <div class="interface-header">
                        <span class="interface-name">{{ ifaceName }}</span>
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
                        <el-col :span="12">
                          <el-form-item :label="$t('SSID')">
                            <el-input v-model="iface.ssid" @change="markInterfaceChanged(ifaceName)"/>
                          </el-form-item>
                        </el-col>
                        <el-col :span="12">
                          <el-form-item :label="$t('Mode')">
                            <el-select v-model="iface.mode" @change="markInterfaceChanged(ifaceName)" style="width: 100%">
                              <el-option label="Access Point" value="ap"/>
                              <el-option label="Station" value="sta"/>
                              <el-option label="Ad-Hoc" value="adhoc"/>
                            </el-select>
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
                          <el-form-item :label="$t('Network')">
                            <el-select v-model="iface.network" @change="markInterfaceChanged(ifaceName)" style="width: 100%">
                              <el-option label="LAN" value="lan"/>
                              <el-option label="WAN" value="wan"/>
                            </el-select>
                          </el-form-item>
                        </el-col>
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

    <!-- 全局操作 -->
    <div class="global-actions" v-if="!loading">
      <el-card shadow="never" class="action-card">
        <div class="action-content">
          <div class="action-info">
            <el-icon class="action-icon"><Setting /></el-icon>
            <span>{{ $t('Wireless Service Control') }}</span>
          </div>
          <el-button type="success" @click="restartWireless" :loading="restarting" size="large">
            <el-icon><Refresh /></el-icon>
            {{ $t('Restart Wireless') }}
          </el-button>
        </div>
      </el-card>
    </div>
    
    <!-- 添加接口对话框 -->
    <el-dialog v-model="addInterfaceDialogVisible" :title="$t('Add Wireless Interface')" width="600px">
      <el-form :model="newInterface" label-width="120px">
        <el-form-item :label="$t('SSID')" required>
          <el-input v-model="newInterface.ssid" placeholder="Enter SSID"/>
        </el-form-item>
        
        <el-form-item :label="$t('Mode')">
          <el-select v-model="newInterface.mode">
            <el-option label="Access Point" value="ap"/>
            <el-option label="Station" value="sta"/>
          </el-select>
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
        
        <el-form-item :label="$t('Network')">
          <el-select v-model="newInterface.network">
            <el-option label="LAN" value="lan"/>
            <el-option label="WAN" value="wan"/>
          </el-select>
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
      htModes: [],
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
      activeInterfaceTabs: {} // 每个 radio 的活跃 tab
    }
  },
  created() {
    this.loadData()
  },
  methods: {
    async loadData() {
      this.loading = true
      try {
        await Promise.all([
          this.loadWirelessStatus(),
          this.loadWirelessConfig(),
          this.loadEncryptionModes(),
          this.loadHtModes()
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
            enabled: !radio.disabled,
            txpower: parseInt(radio.txpower) || 20
          }
          this.radioConfigs[radioName] = { ...config }
          this.originalRadioConfigs[radioName] = { ...config }
        }
        
        this.interfaceConfigs = {}
        this.originalInterfaceConfigs = {}
        for (const [ifaceName, iface] of Object.entries(interfaces || {})) {
          const config = {
            ...iface,
            enabled: !iface.disabled
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
    
    async loadHtModes() {
      try {
        const { modes } = await this.$oui.call('wireless', 'get_htmodes')
        this.htModes = modes || []
      } catch (error) {
        console.error('Failed to load HT modes:', error)
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
    
    getInterfaceTabLabel(iface, ifaceName) {
      const ssid = iface.ssid || 'Unnamed'
      const mode = iface.mode || 'ap'
      return `${ssid} (${mode})`
    },
    
    getChannelOptions(band) {
      if (band === '2g') {
        return [
          { label: 'Channel 1 (2412 MHz)', value: '1' },
          { label: 'Channel 2 (2417 MHz)', value: '2' },
          { label: 'Channel 3 (2422 MHz)', value: '3' },
          { label: 'Channel 4 (2427 MHz)', value: '4' },
          { label: 'Channel 5 (2432 MHz)', value: '5' },
          { label: 'Channel 6 (2437 MHz)', value: '6' },
          { label: 'Channel 7 (2442 MHz)', value: '7' },
          { label: 'Channel 8 (2447 MHz)', value: '8' },
          { label: 'Channel 9 (2452 MHz)', value: '9' },
          { label: 'Channel 10 (2457 MHz)', value: '10' },
          { label: 'Channel 11 (2462 MHz)', value: '11' },
          { label: 'Channel 12 (2467 MHz)', value: '12' },
          { label: 'Channel 13 (2472 MHz)', value: '13' }
        ]
      } else if (band === '5g') {
        return [
          { label: 'Channel 36 (5180 MHz)', value: '36' },
          { label: 'Channel 40 (5200 MHz)', value: '40' },
          { label: 'Channel 44 (5220 MHz)', value: '44' },
          { label: 'Channel 48 (5240 MHz)', value: '48' },
          { label: 'Channel 149 (5745 MHz)', value: '149' },
          { label: 'Channel 153 (5765 MHz)', value: '153' },
          { label: 'Channel 157 (5785 MHz)', value: '157' },
          { label: 'Channel 161 (5805 MHz)', value: '161' }
        ]
      }
      return []
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
          htmode: radio.htmode,
          txpower: radio.txpower.toString(),
          country: radio.country
        })
        
        // 保存相关接口配置
        for (const [ifaceName, iface] of Object.entries(this.getRadioInterfaces(radioName))) {
          if (this.changedInterfaces.has(ifaceName)) {
            await this.$oui.call('wireless', 'set_interface_config', {
              interface: ifaceName,
              disabled: !iface.enabled,
              ssid: iface.ssid,
              mode: iface.mode,
              encryption: iface.encryption,
              key: iface.key,
              hidden: iface.hidden,
              network: iface.network
            })
          }
        }
        
        // 重新加载配置（应用更改但不重启服务）
        await this.$oui.call('wireless', 'reload_config')
        
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
          network: this.newInterface.network
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
    }
  }
}
</script>

<style scoped>
.wireless-container {
  padding: 20px;
  min-height: 100vh;
  background: linear-gradient(135deg, #f5f7fa 0%, #c3cfe2 100%);
}

.loading-container {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  height: 400px;
  color: #606266;
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
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
  border: 1px solid rgba(255, 255, 255, 0.2);
  background: rgba(255, 255, 255, 0.95);
  backdrop-filter: blur(10px);
  transition: all 0.3s ease;
}

.radio-main-card:hover {
  transform: translateY(-4px);
  box-shadow: 0 12px 40px rgba(0, 0, 0, 0.15);
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
  color: #303133;
}

.status-tag {
  margin-left: 8px;
}

.radio-actions {
  display: flex;
  align-items: center;
  gap: 12px;
}

.radio-status {
  margin-bottom: 24px;
  padding: 16px;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  border-radius: 12px;
  color: white;
}

.status-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
  gap: 16px;
}

.status-item {
  text-align: center;
}

.status-label {
  display: block;
  font-size: 12px;
  opacity: 0.8;
  margin-bottom: 4px;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.status-value {
  display: block;
  font-size: 16px;
  font-weight: 600;
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
  background: #fafafa;
  border-radius: 8px;
  padding: 16px;
}

.interface-status {
  margin-bottom: 16px;
}

.interface-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 12px;
  background: white;
  border-radius: 8px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
}

.interface-name {
  font-weight: 600;
  color: #303133;
}

.interface-controls {
  display: flex;
  align-items: center;
  gap: 12px;
}

.interface-form {
  background: white;
  padding: 16px;
  border-radius: 8px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.05);
}

.no-interfaces {
  text-align: center;
  padding: 40px;
  background: white;
  border-radius: 8px;
  border: 2px dashed #e4e7ed;
}

.save-actions {
  margin-top: 24px;
  padding: 16px;
  background: #fff9e6;
  border-radius: 8px;
  border: 1px solid #ffd04b;
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
  margin-top: 24px;
}

.action-card {
  border-radius: 12px;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  border: none;
  color: white;
}

.action-content {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 8px 0;
}

.action-info {
  display: flex;
  align-items: center;
  gap: 12px;
  color: white;
  font-size: 16px;
  font-weight: 500;
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
}

:deep(.el-form-item) {
  margin-bottom: 18px;
}

:deep(.el-form-item__label) {
  font-weight: 500;
  color: #303133;
}

:deep(.el-tabs__item) {
  font-weight: 500;
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

:deep(.el-tag) {
  border-radius: 6px;
  font-weight: 500;
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
}
</style>

<i18n src="./locale.json"/>
