<template>
  <div class="wan-container">
  <el-space direction="vertical" fill style="width: 100%;">
    <!-- WAN状态概览 -->
    <el-card :header="$t('WAN Status')" fill>
      <el-row :gutter="20">
        <el-col :span="12">
          <el-descriptions :column="1" border>
            <el-descriptions-item :label="$t('Interface')">{{ wanStatus.ifname }}</el-descriptions-item>
            <el-descriptions-item :label="$t('Connection Status')">
              <el-tag :type="wanStatus.status.up ? 'success' : 'danger'">
                {{ wanStatus.status.up ? $t('Connected') : $t('Disconnected') }}
              </el-tag>
            </el-descriptions-item>
            <el-descriptions-item :label="$t('Link State')">
              <div>
                <el-tag :type="wanStatus.status.device.carrier ? 'success' : 'warning'">
                  {{ wanStatus.status.device.carrier ? $t('Link Up') : $t('Link Down') }}
                </el-tag>
                <div v-if="wanStatus.status.device.carrier && wanStatus.status.device.speed" style="margin-top: 6px;">
                  <el-tag size="small" type="info" style="margin-right: 4px;">
                    {{ formatLinkSpeed(wanStatus.status.device.speed) }}
                  </el-tag>
                  <el-tag size="small" :type="wanStatus.status.device.duplex ? 'success' : 'warning'">
                    {{ wanStatus.status.device.duplex ? $t('Full Duplex') : $t('Half Duplex') }}
                  </el-tag>
                </div>
              </div>
            </el-descriptions-item>
            <el-descriptions-item :label="$t('Protocol')">{{ wanStatus.config.proto.toUpperCase() }}</el-descriptions-item>
            <el-descriptions-item :label="$t('IP Address')" v-if="wanStatus.status.ipv4_address.length > 0">
              {{ wanStatus.status.ipv4_address[0].address }}/{{ wanStatus.status.ipv4_address[0].mask }}
            </el-descriptions-item>
            <el-descriptions-item :label="$t('IPv6 Address')" v-if="wanStatus.status.ipv6_address && wanStatus.status.ipv6_address.length > 0">
              <div v-for="(addr, index) in wanStatus.status.ipv6_address.slice(0, 3)" :key="addr.address" style="margin-bottom: 4px;">
                <div style="font-family: monospace;">{{ addr.address }}/{{ addr.mask }}</div>
                <div v-if="addr.scope" style="font-size: 12px;">
                  <el-tag size="small" :type="getScopeTagType(addr.scope)">{{ formatScope(addr.scope) }}</el-tag>
                </div>
              </div>
              <div v-if="wanStatus.status.ipv6_address.length > 3" style="font-size: 12px; color: #909399;">
                {{ $t('And {count} more addresses', { count: wanStatus.status.ipv6_address.length - 3 }) }}
              </div>
            </el-descriptions-item>
            <el-descriptions-item :label="$t('Gateway')" v-if="getGateway()">
              {{ getGateway() }}
            </el-descriptions-item>
            <el-descriptions-item :label="$t('IPv6 Gateway')" v-if="getIpv6Gateway()">
              {{ getIpv6Gateway() }}
            </el-descriptions-item>
            <el-descriptions-item :label="$t('DNS Servers')" v-if="wanStatus.status.dns_server.length > 0">
              {{ wanStatus.status.dns_server.join(', ') }}
            </el-descriptions-item>
            <el-descriptions-item :label="$t('Uptime')" v-if="wanStatus.status.uptime > 0">
              {{ formatUptime(wanStatus.status.uptime) }}
            </el-descriptions-item>
          </el-descriptions>
        </el-col>
        <el-col :span="12">
          <!-- 网速和流量统计 -->
          <el-card :header="$t('Traffic Statistics')" shadow="never">
            <div class="traffic-stats">
              <div class="speed-item">
                <div class="speed-label">{{ $t('Download Speed') }}</div>
                <div class="speed-value">{{ formatSpeed(currentSpeed.download) }}</div>
              </div>
              <div class="speed-item">
                <div class="speed-label">{{ $t('Upload Speed') }}</div>
                <div class="speed-value">{{ formatSpeed(currentSpeed.upload) }}</div>
              </div>
              <div class="traffic-item">
                <div class="traffic-label">{{ $t('Total Downloaded') }}</div>
                <div class="traffic-value">{{ formatBytes(wanStatus.stats.rx_bytes) }}</div>
              </div>
              <div class="traffic-item">
                <div class="traffic-label">{{ $t('Total Uploaded') }}</div>
                <div class="traffic-value">{{ formatBytes(wanStatus.stats.tx_bytes) }}</div>
              </div>
            </div>
          </el-card>
          <!-- 连接控制 -->
          <div style="margin-top: 16px; text-align: center;">
            <el-button v-if="!wanStatus.status.up" type="primary" @click="connectWan" :loading="connecting">
              {{ $t('Connect') }}
            </el-button>
            <el-button v-else type="danger" @click="disconnectWan" :loading="connecting">
              {{ $t('Disconnect') }}
            </el-button>
          </div>
        </el-col>
      </el-row>
    </el-card>

    <!-- WAN配置 -->
    <el-card :header="$t('WAN Configuration')">
      <el-form ref="wanForm" :model="wanConfig" :rules="wanRules" label-width="160px" size="large">
        <el-form-item :label="$t('Protocol')" prop="proto">
          <el-select v-model="wanConfig.proto" @change="onProtocolChange" style="width: 200px">
            <el-option label="DHCP" value="dhcp"/>
            <el-option label="Static IP" value="static"/>
            <el-option label="PPPoE" value="pppoe"/>
          </el-select>
        </el-form-item>

        <!-- 静态IP配置 -->
        <template v-if="wanConfig.proto === 'static'">
          <el-form-item :label="$t('IP Address')" prop="ipaddr">
            <el-input v-model="wanConfig.ipaddr" @input="markFormTouched" style="width: 200px" placeholder="192.168.1.100"/>
          </el-form-item>
          <el-form-item :label="$t('Subnet Mask')" prop="netmask">
            <el-select v-model="wanConfig.netmask" @change="markFormTouched" style="width: 200px">
              <el-option label="255.255.255.0 (/24)" value="255.255.255.0"/>
              <el-option label="255.255.0.0 (/16)" value="255.255.0.0"/>
              <el-option label="255.0.0.0 (/8)" value="255.0.0.0"/>
            </el-select>
          </el-form-item>
          <el-form-item :label="$t('Gateway')" prop="gateway">
            <el-input v-model="wanConfig.gateway" @input="markFormTouched" style="width: 200px" placeholder="192.168.1.1"/>
          </el-form-item>
          <el-form-item :label="$t('DNS Servers')">
            <div>
              <el-input v-model="wanConfig.dns" @input="markFormTouched" style="width: 200px; margin-bottom: 8px" placeholder="8.8.8.8,8.8.4.4"/>
              <div class="form-help">{{ $t('Separate multiple DNS servers with commas') }}</div>
              <el-dropdown @command="setDnsServers" style="margin-top: 8px">
                <el-button size="small">
                  {{ $t('Quick Select DNS') }}<el-icon class="el-icon--right"><arrow-down /></el-icon>
                </el-button>
                <template #dropdown>
                  <el-dropdown-menu>
                    <el-dropdown-item v-for="dns in dnsServers" :key="dns.name" :command="dns">
                      {{ dns.name }}
                    </el-dropdown-item>
                  </el-dropdown-menu>
                </template>
              </el-dropdown>
            </div>
          </el-form-item>
        </template>

        <!-- PPPoE配置 -->
        <template v-if="wanConfig.proto === 'pppoe'">
          <el-form-item :label="$t('Username')" prop="username">
            <el-input v-model="wanConfig.username" @input="markFormTouched" style="width: 200px"/>
          </el-form-item>
          <el-form-item :label="$t('Password')" prop="password">
            <el-input v-model="wanConfig.password" @input="markFormTouched" type="password" style="width: 200px" show-password/>
          </el-form-item>
        </template>

        <!-- DHCP配置说明 -->
        <template v-if="wanConfig.proto === 'dhcp'">
          <el-alert :title="$t('DHCP Mode')" type="info" :closable="false">
            {{ $t('DHCP mode will automatically obtain IP address, gateway and DNS from your ISP') }}
          </el-alert>
        </template>

        <!-- IPv6配置 -->
        <el-divider content-position="left">{{ $t('IPv6 Configuration') }}</el-divider>
        
        <el-form-item :label="$t('Enable IPv6')" prop="ipv6">
          <el-switch v-model="wanConfig.ipv6" @change="markFormTouched"/>
          <div class="form-help">{{ $t('Enable IPv6 support for WAN interface') }}</div>
        </el-form-item>

        <template v-if="wanConfig.ipv6">
          <el-form-item :label="$t('IPv6 Protocol')" prop="ipv6_proto">
            <el-select v-model="wanConfig.ipv6_proto" @change="onIpv6ProtocolChange" style="width: 200px">
              <el-option label="DHCPv6" value="dhcpv6"/>
              <el-option label="Static IPv6" value="static"/>
            </el-select>
          </el-form-item>

          <!-- 静态IPv6配置 -->
          <template v-if="wanConfig.ipv6_proto === 'static'">
            <el-form-item :label="$t('IPv6 Address')" prop="ipv6_addr">
              <el-input v-model="wanConfig.ipv6_addr" @input="markFormTouched" style="width: 300px" placeholder="2001:db8::1"/>
            </el-form-item>
            <el-form-item :label="$t('IPv6 Prefix Length')" prop="ipv6_prefix">
              <el-select v-model="wanConfig.ipv6_prefix" @change="markFormTouched" style="width: 200px">
                <el-option label="/64" value="64"/>
                <el-option label="/56" value="56"/>
                <el-option label="/48" value="48"/>
                <el-option label="/32" value="32"/>
              </el-select>
            </el-form-item>
            <el-form-item :label="$t('IPv6 Gateway')" prop="ipv6_gateway">
              <el-input v-model="wanConfig.ipv6_gateway" @input="markFormTouched" style="width: 300px" placeholder="2001:db8::ffff"/>
            </el-form-item>
            <el-form-item :label="$t('IPv6 DNS Servers')">
              <el-input v-model="wanConfig.ipv6_dns" @input="markFormTouched" style="width: 400px" placeholder="2001:4860:4860::8888,2001:4860:4860::8844"/>
              <div class="form-help">{{ $t('Separate multiple IPv6 DNS servers with commas') }}</div>
              <el-dropdown @command="setIpv6DnsServers" style="margin-top: 8px">
                <el-button size="small">
                  {{ $t('Quick Select IPv6 DNS') }}<el-icon class="el-icon--right"><arrow-down /></el-icon>
                </el-button>
                <template #dropdown>
                  <el-dropdown-menu>
                    <el-dropdown-item :command="{ primary: '2001:4860:4860::8888', secondary: '2001:4860:4860::8844' }">
                      Google IPv6 DNS
                    </el-dropdown-item>
                    <el-dropdown-item :command="{ primary: '2606:4700:4700::1111', secondary: '2606:4700:4700::1001' }">
                      Cloudflare IPv6 DNS
                    </el-dropdown-item>
                    <el-dropdown-item :command="{ primary: '2001:da8:ff:305:20c:29ff:fe5f:1e49', secondary: '240c::6666' }">
                      114 IPv6 DNS
                    </el-dropdown-item>
                  </el-dropdown-menu>
                </template>
              </el-dropdown>
            </el-form-item>
          </template>

          <!-- DHCPv6配置说明 -->
          <template v-if="wanConfig.ipv6_proto === 'dhcpv6'">
            <el-alert :title="$t('DHCPv6 Mode')" type="info" :closable="false">
              {{ $t('DHCPv6 mode will automatically obtain IPv6 address and configuration from your ISP') }}
            </el-alert>
          </template>
        </template>

        <el-form-item>
          <el-button type="primary" @click="saveWanConfig" :loading="saving">
            {{ $t('Save & Apply') }}
          </el-button>
          <el-button @click="resetForm">
            {{ $t('Reset') }}
          </el-button>
        </el-form-item>
      </el-form>
    </el-card>
  </el-space>
  </div>
</template>

<script>
import { ArrowDown } from '@element-plus/icons-vue'

export default {
  components: {
    ArrowDown
  },
  data() {
    return {
      wanStatus: {
        config: { proto: 'dhcp' },
        status: {
          up: false,
          device: { carrier: false },
          ipv4_address: [],
          route: [],
          dns_server: [],
          uptime: 0
        },
        stats: { rx_bytes: 0, tx_bytes: 0 },
        ifname: 'eth0'
      },
      wanConfig: {
        proto: 'dhcp',
        ipaddr: '',
        netmask: '255.255.255.0',
        gateway: '',
        dns: '',
        username: '',
        password: '',
        ipv6: false,
        ipv6_proto: 'dhcpv6',
        ipv6_addr: '',
        ipv6_prefix: '64',
        ipv6_gateway: '',
        ipv6_dns: ''
      },
      wanRules: {
        ipaddr: [
          { required: true, message: this.$t('Please enter IP address'), trigger: 'blur' },
          { pattern: /^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$/, message: this.$t('Invalid IP address format'), trigger: 'blur' }
        ],
        netmask: [
          { required: true, message: this.$t('Please select subnet mask'), trigger: 'change' }
        ],
        gateway: [
          { required: true, message: this.$t('Please enter gateway'), trigger: 'blur' },
          { pattern: /^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$/, message: this.$t('Invalid IP address format'), trigger: 'blur' }
        ],
        username: [
          { required: true, message: this.$t('Please enter username'), trigger: 'blur' }
        ],
        password: [
          { required: true, message: this.$t('Please enter password'), trigger: 'blur' }
        ],
        ipv6_addr: [
          { required: true, message: this.$t('Please enter IPv6 address'), trigger: 'blur' },
          { pattern: /^([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}$|^::1$|^::$/, message: this.$t('Invalid IPv6 address format'), trigger: 'blur' }
        ],
        ipv6_gateway: [
          { required: true, message: this.$t('Please enter IPv6 gateway'), trigger: 'blur' },
          { pattern: /^([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}$|^::1$|^::$/, message: this.$t('Invalid IPv6 address format'), trigger: 'blur' }
        ]
      },
      saving: false,
      connecting: false,
      currentSpeed: {
        download: 0,
        upload: 0
      },
      lastStats: null,
      dnsServers: [],
      formTouched: false
    }
  },
  methods: {
    async getWanStatus() {
      try {
        const { config, status, stats, ifname } = await this.$oui.call('wan', 'get_wan_status')
        this.wanStatus = { config, status, stats, ifname }

        // 只有在用户没有修改配置时才更新表单
        if (!this.formTouched) {
          this.wanConfig = { ...config }
        }

        // 计算网速
        this.calculateSpeed(stats)
      } catch (error) {
        console.error('Failed to get WAN status:', error)
      }
    },

    async getDnsServers() {
      try {
        const { servers } = await this.$oui.call('wan', 'get_dns_servers')
        this.dnsServers = servers
      } catch (error) {
        console.error('Failed to get DNS servers:', error)
      }
    },

    calculateSpeed(currentStats) {
      if (this.lastStats) {
        const timeDiff = (Date.now() - this.lastStats.timestamp) / 1000
        const rxDiff = currentStats.rx_bytes - this.lastStats.rx_bytes
        const txDiff = currentStats.tx_bytes - this.lastStats.tx_bytes

        this.currentSpeed.download = Math.max(0, rxDiff / timeDiff)
        this.currentSpeed.upload = Math.max(0, txDiff / timeDiff)
      }

      this.lastStats = {
        rx_bytes: currentStats.rx_bytes,
        tx_bytes: currentStats.tx_bytes,
        timestamp: Date.now()
      }
    },

    async saveWanConfig() {
      try {
        await this.$refs.wanForm.validate()
        this.saving = true

        await this.$oui.call('wan', 'set_wan_config', this.wanConfig)
        await this.$oui.call('wan', 'set_wan_config', this.wanConfig)
        this.$oui.reloadConfig("network")
        this.$message.success(this.$t('Configuration saved successfully'))
        
        // 配置保存后清除编辑状态
        this.formTouched = false

        // 延迟刷新状态
        setTimeout(() => {
          this.getWanStatus()
        }, 2000)
      } catch (error) {
        console.error('Failed to save WAN config:', error)
        this.$message.error(this.$t('Failed to save configuration'))
      } finally {
        this.saving = false
      }
    },

    async connectWan() {
      try {
        this.connecting = true
        await this.$oui.call('wan', 'wan_connect', { action: 'connect' })
        this.$message.success(this.$t('Connecting...'))

        setTimeout(() => {
          this.getWanStatus()
        }, 3000)
      } catch (error) {
        console.error('Failed to connect WAN:', error)
        this.$message.error(this.$t('Failed to connect'))
      } finally {
        this.connecting = false
      }
    },

    async disconnectWan() {
      try {
        await this.$confirm(this.$t('Are you sure to disconnect WAN?'), this.$t('Confirm'), {
          type: 'warning'
        })

        this.connecting = true
        await this.$oui.call('wan', 'wan_connect', { action: 'disconnect' })
        this.$message.success(this.$t('WAN Disconnected'))

        setTimeout(() => {
          this.getWanStatus()
        }, 1000)
      } catch (error) {
        if (error !== 'cancel') {
          console.error('Failed to disconnect WAN:', error)
          this.$message.error(this.$t('Failed to disconnect'))
        }
      } finally {
        this.connecting = false
      }
    },

    onProtocolChange() {
      // 标记表单已被修改
      this.formTouched = true
      
      // 清空相关字段
      if (this.wanConfig.proto !== 'static') {
        this.wanConfig.ipaddr = ''
        this.wanConfig.netmask = '255.255.255.0'
        this.wanConfig.gateway = ''
        this.wanConfig.dns = ''
      }
      if (this.wanConfig.proto !== 'pppoe') {
        this.wanConfig.username = ''
        this.wanConfig.password = ''
      }
    },

    setDnsServers(dns) {
      this.wanConfig.dns = `${dns.primary},${dns.secondary}`
      this.markFormTouched()
    },
    
    onIpv6ProtocolChange() {
      // 标记表单已被修改
      this.markFormTouched()
      
      // 清空IPv6静态配置字段
      if (this.wanConfig.ipv6_proto !== 'static') {
        this.wanConfig.ipv6_addr = ''
        this.wanConfig.ipv6_prefix = '64'
        this.wanConfig.ipv6_gateway = ''
        this.wanConfig.ipv6_dns = ''
      }
    },
    
    setIpv6DnsServers(dns) {
      this.wanConfig.ipv6_dns = `${dns.primary},${dns.secondary}`
      this.markFormTouched()
    },
    
    markFormTouched() {
      this.formTouched = true
    },

    resetForm() {
      this.wanConfig = { ...this.wanStatus.config }
      this.formTouched = false
      this.$refs.wanForm.clearValidate()
    },

    getGateway() {
      const routes = this.wanStatus.status.route || []
      const defaultRoute = routes.find(r => r.target === '0.0.0.0' && r.mask === 0)
      return defaultRoute ? defaultRoute.nexthop : ''
    },

    formatSpeed(bytesPerSecond) {
      if (bytesPerSecond === 0) return '0 B/s'

      const units = ['B/s', 'KB/s', 'MB/s', 'GB/s']
      let size = bytesPerSecond
      let unitIndex = 0

      while (size >= 1024 && unitIndex < units.length - 1) {
        size /= 1024
        unitIndex++
      }

      return `${size.toFixed(1)} ${units[unitIndex]}`
    },

    formatBytes(bytes) {
      if (bytes === 0) return '0 B'

      const units = ['B', 'KB', 'MB', 'GB', 'TB']
      let size = bytes
      let unitIndex = 0

      while (size >= 1024 && unitIndex < units.length - 1) {
        size /= 1024
        unitIndex++
      }

      return `${size.toFixed(1)} ${units[unitIndex]}`
    },

    formatUptime(seconds) {
      const days = Math.floor(seconds / 86400)
      const hours = Math.floor((seconds % 86400) / 3600)
      const minutes = Math.floor((seconds % 3600) / 60)

      if (days > 0) {
        return `${days}d ${hours}h ${minutes}m`
      } else if (hours > 0) {
        return `${hours}h ${minutes}m`
      } else {
        return `${minutes}m`
      }
    },
    
    formatLinkSpeed(speed) {
      if (!speed) return ''
      
      if (speed >= 1000) {
        return `${speed / 1000}Gbps`
      } else {
        return `${speed}Mbps`
      }
    },
    
    getIpv6Gateway() {
      const routes = this.wanStatus.status.route || []
      const ipv6DefaultRoute = routes.find(r => r.target === '::' && r.mask === 0)
      return ipv6DefaultRoute ? ipv6DefaultRoute.nexthop : ''
    },
    
    formatScope(scope) {
      const scopeMap = {
        'global': this.$t('Global'),
        'link': this.$t('Link Local'),
        'site': this.$t('Site Local'),
        'host': this.$t('Host Local'),
        'universe': this.$t('Global'),
        'nowhere': this.$t('Invalid')
      }
      return scopeMap[scope] || scope.toUpperCase()
    },
    
    getScopeTagType(scope) {
      const typeMap = {
        'global': 'success',
        'link': 'info',
        'site': 'warning',
        'host': 'info',
        'universe': 'success',
        'nowhere': 'danger'
      }
      return typeMap[scope] || 'info'
    }
  },
  created() {
    this.getDnsServers()
    this.$timer.create('getWanStatus', this.getWanStatus, { time: 3000, immediate: true, repeat: true })
  }
}
</script>

<style scoped>
.wan-container {
  /* Theme variables aligned with Wireless app */
  --bg-gradient-light: linear-gradient(135deg, #f5f7fa 0%, #c3cfe2 100%);
  --bg-gradient-dark: linear-gradient(135deg, #0f172a 0%, #111827 100%);
  --header-bg-light: linear-gradient(135deg, #dbeafe 0%, #93c5fd 100%);
  --header-bg-dark: linear-gradient(135deg, #1f2937 0%, #111827 100%);
  --header-text-light: #4d4d4d;
  --header-text-dark: #f9fafb;
  --header-border-light: #93c5fd;
  --header-border-dark: #1f2937;
  --panel-bg-light: #fafafa;
  --panel-bg-dark: #1f1f1f;
  --status-bg-light: linear-gradient(135deg, #f8fafc 0%, #e2e8f0 100%);
  --status-bg-dark: linear-gradient(135deg, #1e293b 0%, #0f172a 100%);
  --status-text-light: #334155;
  --status-text-dark: #cbd5e1;
  --status-border-light: #cbd5e1;
  --status-border-dark: #475569;
  --text-secondary-light: #606266;
  --text-secondary-dark: #a1a1aa;
  padding: 20px;
  min-height: 100vh;
  background: var(--bg-gradient-light);
}

.dark .wan-container {
  background: var(--bg-gradient-dark);
}

/* Themed Element Plus card headers within this page */
:deep(.el-card__header) {
  background: var(--header-bg-light);
  color: var(--header-text-light);
  border-bottom: 1px solid var(--header-border-light);
}

.dark :deep(.el-card__header) {
  background: var(--header-bg-dark);
  color: var(--header-text-dark);
  border-bottom: 1px solid var(--header-border-dark);
}

.traffic-stats {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 16px;
}

.speed-item, .traffic-item {
  text-align: center;
  padding: 12px;
  background: var(--status-bg-light);
  border-radius: 6px;
  border: 1px solid var(--status-border-light);
  color: var(--status-text-light);
}

.speed-label, .traffic-label {
  font-size: 12px;
  color: var(--text-secondary-light);
  margin-bottom: 4px;
}

.speed-value {
  font-size: 18px;
  font-weight: bold;
  color: #409eff;
}

.traffic-value {
  font-size: 14px;
  font-weight: bold;
  color: #67c23a;
}

.form-help {
  font-size: 12px;
  color: var(--text-secondary-light);
  margin-top: 4px;
}

.dark .speed-item, .dark .traffic-item {
  background: var(--status-bg-dark);
  border: 1px solid var(--status-border-dark);
  color: var(--status-text-dark);
}

.dark .speed-label, .dark .traffic-label, .dark .form-help {
  color: var(--text-secondary-dark);
}
</style>

<i18n src="./locale.json"/>
