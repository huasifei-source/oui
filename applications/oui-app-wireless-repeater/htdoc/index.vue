<template>
  <div class="repeater-container">
    <el-card class="repeater-card" shadow="hover">
      <template #header>
        <div class="card-header">
          <div class="title">
            <el-icon><Connection /></el-icon>
            <span>{{ $t('Wireless Repeater') }}</span>
          </div>
          <div class="actions">
            <el-button type="primary" @click="onReload">{{ $t('Reload') }}</el-button>
          </div>
        </div>
      </template>

      <div class="grid">
        <!-- 左侧：设备选择 + 扫描列表 -->
        <div class="left-column">
          <el-card class="panel" shadow="never">
            <template #header>
              <div class="panel-header">{{ $t('Select Device') }}</div>
            </template>
            <div>
              <el-select v-model="state.device" placeholder="radio0" style="width: 100%">
                <el-option v-for="dev in state.devices" :key="dev.name" :label="formatDeviceLabel(dev)" :value="dev.name" />
              </el-select>
              <div class="inline-actions">
                <el-button :loading="state.scanning" @click="onScan" type="primary" size="small">
                  {{ $t('Scan Nearby Wi-Fi') }}
                </el-button>
              </div>
            </div>
          </el-card>

          <el-card class="panel list-panel" shadow="never">
            <template #header>
              <div class="panel-header">{{ $t('Scan Results') }}</div>
            </template>
            <el-table :data="state.scanResults" size="small" height="360" @row-click="onSelectNetwork" class="scan-table">
              <el-table-column prop="ssid" :label="$t('SSID')" min-width="160" />
              <el-table-column prop="signal" :label="$t('Signal')" width="90">
                <template #default="{ row }">
                  <el-tag :type="signalType(row.signal)" effect="dark">{{ row.signal }} dBm</el-tag>
                </template>
              </el-table-column>
              <el-table-column prop="channel" :label="$t('Channel')" width="90" />
              <el-table-column prop="encryption" :label="$t('Encryption')" min-width="140" />
            </el-table>
          </el-card>
        </div>

        <!-- 右侧：配置表单 + 连接状态 -->
        <div class="right-column">
          <el-card class="panel" shadow="never">
            <template #header>
              <div class="panel-header">{{ $t('Configure Repeater') }}</div>
            </template>
            <el-form :model="form" label-width="120px">
              <el-form-item :label="$t('SSID')">
                <el-input v-model="form.ssid" placeholder="e.g. ImmortalWrt" />
              </el-form-item>
              <el-form-item :label="$t('BSSID')">
                <el-input v-model="form.bssid" placeholder="optional" />
              </el-form-item>
              <el-form-item :label="$t('Encryption')">
                <el-select v-model="form.encryption" style="width: 100%">
                  <el-option label="Open" value="none" />
                  <el-option label="WPA2-PSK" value="psk2" />
                  <el-option label="WPA-PSK" value="psk" />
                  <el-option label="WEP" value="wep" />
                </el-select>
              </el-form-item>
              <el-form-item v-if="needsPassword(form.encryption)" :label="$t('Password')">
                <el-input v-model="form.key" type="password" show-password placeholder="••••••••" />
              </el-form-item>
              <el-form-item :label="$t('Bind firewall')">
                <el-tag type="info">wan</el-tag>
              </el-form-item>
              <el-form-item :label="$t('Interface Name')">
                <el-input v-model="form.network" disabled />
              </el-form-item>
            </el-form>
            <div class="form-actions">
              <el-button @click="onReset">{{ $t('Reset') }}</el-button>
              <el-button type="primary" :loading="state.saving" @click="onSave">{{ $t('Save & Apply') }}</el-button>
            </div>
          </el-card>

          <el-card class="panel" shadow="never">
            <template #header>
              <div class="panel-header">{{ $t('Connection Status') }}</div>
            </template>
            <div class="status-grid">
              <div class="status-item">
                <div class="label">{{ $t('State') }}</div>
                <div class="value">
                  <el-tag :type="state.connection.connected ? 'success' : 'danger'">
                    {{ state.connection.connected ? $t('Connected') : $t('Disconnected') }}
                  </el-tag>
                </div>
              </div>
              <div class="status-item">
                <div class="label">{{ $t('IP Address') }}</div>
                <div class="value">{{ state.connection.ip_address || '-' }}</div>
              </div>
              <div class="status-item">
                <div class="label">{{ $t('Gateway') }}</div>
                <div class="value">{{ state.connection.gateway || '-' }}</div>
              </div>
              <div class="status-item">
                <div class="label">{{ $t('DNS') }}</div>
                <div class="value">{{ (state.connection.dns_servers||[]).join(', ') || '-' }}</div>
              </div>
            </div>
          </el-card>
        </div>
      </div>
    </el-card>
  </div>
</template>

<script>
import { Connection } from '@element-plus/icons-vue'

export default {
  components: { Connection },
  data() {
    return {
      state: {
        devices: [],
        device: '',
        scanResults: [],
        scanning: false,
        saving: false,
        connection: {
          connected: false,
          ip_address: '',
          gateway: '',
          dns_servers: []
        }
      },
      form: {
        ssid: '',
        bssid: '',
        encryption: 'none',
        key: '',
        network: 'repeater'
      }
    }
  },
  created() {
    // 初始化：加载设备列表、当前配置和连接状态
    this.init()
  },
  methods: {
    async init() {
      await this.loadDevices()
      await this.loadExistingConfig()
      await this.loadConnectionStatus()
    },
    async loadDevices() {
      try {
        const { devices } = await this.$oui.call('wireless-repeater', 'get_wireless_devices')
        const list = Object.values(devices || {})
        this.state.devices = list
        if (!this.state.device && list.length > 0) {
          // 选择第一个可用设备，优先 5G/6G
          const preferred = list.find(d => d.band === '5g') || list.find(d => d.band === '6g') || list[0]
          this.state.device = preferred.name
        }
      } catch (e) {
        console.error('loadDevices error:', e)
        this.$message.error(this.$t('Failed to load wireless devices'))
      }
    },
    async loadExistingConfig() {
      try {
        const { config } = await this.$oui.call('wireless-repeater', 'get_repeater_config')
        if (config) {
          // 回填表单
          this.form.ssid = config.ssid || ''
          this.form.bssid = config.bssid || ''
          this.form.encryption = (config.encryption || 'none')
          this.form.key = config.key || ''
          this.form.network = 'repeater'
          if (config.device) this.state.device = config.device
        }
      } catch (e) {
        console.error('loadExistingConfig error:', e)
      }
    },
    async loadConnectionStatus() {
      try {
        const { status } = await this.$oui.call('wireless-repeater', 'get_connection_status')
        this.state.connection = Object.assign({}, this.state.connection, status || {})
      } catch (e) {
        console.error('loadConnectionStatus error:', e)
      }
    },
    formatDeviceLabel(dev) {
      const band = dev.band === '5g' ? '5G' : (dev.band === '6g' ? '6G' : '2.4G')
      return `${dev.name} (${band})`
    },
    signalType(signal) {
      if (signal >= -60) return 'success'
      if (signal >= -75) return 'warning'
      return 'danger'
    },
    needsPassword(enc) {
      return enc && enc !== 'none'
    },
    // 事件（RPC 调用）
    async onReload() {
      try {
        await this.$oui.call('wireless-repeater', 'reload_config')
        await this.loadConnectionStatus()
        this.$message.success(this.$t('Reloaded'))
      } catch (e) {
        this.$message.error(this.$t('Reload failed'))
      }
    },
    async onScan() {
      if (!this.state.device) {
        this.$message.warning(this.$t('Please select a device'))
        return
      }
      this.state.scanning = true
      try {
        const { networks } = await this.$oui.call('wireless-repeater', 'scan_wireless_networks', {
          device: this.state.device
        })
        this.state.scanResults = networks || []
      } catch (e) {
        console.error('scan error:', e)
        this.$message.error(this.$t('Scan failed'))
      }
      this.state.scanning = false
    },
    onSelectNetwork(row) {
      this.form.ssid = row.ssid
      this.form.bssid = row.bssid
      // 简单推断加密
      if (!row.encryption_raw || !row.encryption_raw.enabled) {
        this.form.encryption = 'none'
      } else {
        // 根据iwinfo返回做个粗略映射
        const e = (row.encryption || '').toLowerCase()
        if (e.includes('wpa2') || e.includes('psk2')) this.form.encryption = 'psk2'
        else if (e.includes('wpa') || e.includes('psk')) this.form.encryption = 'psk'
        else if (e.includes('wep')) this.form.encryption = 'wep'
        else this.form.encryption = 'psk2'
      }
    },
    onReset() {
      this.form = { ssid: '', bssid: '', encryption: 'none', key: '', network: 'repeater' }
    },
    async onSave() {
      if (!this.form.ssid) {
        this.$message.error(this.$t('Please enter SSID'))
        return
      }
      if (this.needsPassword(this.form.encryption) && !this.form.key) {
        this.$message.error(this.$t('Please enter password'))
        return
      }
      if (!this.state.device) {
        this.$message.error(this.$t('Please select a device'))
        return
      }
      this.state.saving = true
      try {
        await this.$oui.call('wireless-repeater', 'configure_repeater', {
          device: this.state.device,
          ssid: this.form.ssid,
          bssid: this.form.bssid,
          encryption: this.form.encryption,
          key: this.form.key
        })
        await this.$oui.call('wireless-repeater', 'reload_config')
        await this.loadExistingConfig()
        await this.loadConnectionStatus()
        this.$message.success(this.$t('Configuration saved and applied'))
      } catch (e) {
        console.error('save error:', e)
        this.$message.error(this.$t('Failed to save configuration'))
      }
      this.state.saving = false
    }
  }
}
</script>

<style scoped>
.repeater-container { padding: 20px; }
.repeater-card { border-radius: 12px; }
.card-header { display:flex; justify-content:space-between; align-items:center; }
.title { display:flex; align-items:center; gap:8px; font-weight:600; }
.actions { display:flex; gap:8px; }
.grid { display:grid; grid-template-columns: 1.2fr 1fr; gap:16px; }
.panel { border-radius: 10px; }
.panel-header { font-weight:600; }
.inline-actions { margin-top: 12px; }
.list-panel { margin-top: 16px; }
.scan-table :deep(.el-table__row) { cursor: pointer; }
.form-actions { display:flex; justify-content:flex-end; gap:8px; }
.status-grid { display:grid; grid-template-columns: repeat(2, 1fr); gap:12px; }
.status-item .label { font-size:12px; opacity:0.7; }
.status-item .value { font-weight:600; }
@media (max-width: 1024px) {
  .grid { grid-template-columns: 1fr; }
}
</style>

<i18n src="./locale.json"/>
