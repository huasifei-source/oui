<template>
  <el-space direction="vertical" fill>
    <!-- LAN接口配置 -->
    <el-card :header="$t('LAN Interface Configuration')">
        <el-form ref="lanForm" :model="lanConfig" :rules="lanRules" label-width="160px" size="large">
          <el-form-item :label="$t('IP Address')" prop="ipaddr">
            <el-input v-model="lanConfig.ipaddr" style="width: 200px" placeholder="192.168.1.1"/>
          </el-form-item>
          
          <el-form-item :label="$t('Subnet Mask')" prop="netmask">
            <el-select v-model="lanConfig.netmask" style="width: 200px">
              <el-option label="255.255.255.0 (/24)" value="255.255.255.0"/>
              <el-option label="255.255.0.0 (/16)" value="255.255.0.0"/>
              <el-option label="255.0.0.0 (/8)" value="255.0.0.0"/>
            </el-select>
          </el-form-item>
        <el-form-item>
          <el-button type="primary" @click="saveLanConfig" :loading="saving">
            {{ $t('Save & Apply') }}
          </el-button>
        </el-form-item>
      </el-form>
    </el-card>

    <!-- DHCP服务器配置 -->
    <el-card :header="$t('DHCP Server Configuration')">
      <el-form ref="dhcpForm" :model="dhcpConfig" :rules="dhcpRules" label-width="160px" size="large" style="width: 100%; min-width: 100%">
        <el-form-item :label="$t('Enable DHCP Server')" prop="dhcp_enabled">
          <el-switch v-model="dhcpConfig.dhcp_enabled"/>
          <div class="form-help">{{ $t('Enable or disable DHCP server') }}</div>
        </el-form-item>
        
        <template v-if="dhcpConfig.dhcp_enabled">
          <el-form-item :label="$t('Start IP')" prop="dhcp_start">
            <el-input-number v-model.number="dhcpConfig.dhcp_start" :min="2" :max="254" style="width: 200px"/>
            <div class="form-help">{{ $t('Starting IP address for DHCP range') }}</div>
          </el-form-item>
          
          <el-form-item :label="$t('IP Count')" prop="dhcp_limit">
            <el-input-number v-model.number="dhcpConfig.dhcp_limit" :min="1" :max="253" style="width: 200px"/>
            <div class="form-help">{{ $t('Number of IP addresses to allocate') }}</div>
          </el-form-item>
          
          <el-form-item :label="$t('Lease Time')" prop="dhcp_leasetime">
            <el-select v-model="dhcpConfig.dhcp_leasetime" style="width: 200px">
              <el-option label="2 hours" value="2h"/>
              <el-option label="6 hours" value="6h"/>
              <el-option label="12 hours" value="12h"/>
              <el-option label="24 hours" value="24h"/>
              <el-option label="7 days" value="168h"/>
            </el-select>
          </el-form-item>
          
          <el-form-item :label="$t('DNS Servers')">
            <div v-for="(dns, index) in dhcpConfig.dns_servers" :key="index" style="margin-bottom: 8px">
              <el-input v-model="dhcpConfig.dns_servers[index]" style="width: 200px; margin-right: 8px" 
                       :placeholder="index === 0 ? '8.8.8.8' : '8.8.4.4'"/>
              <el-button v-if="index > 1" @click="removeDnsServer(index)" type="danger" size="small">
                {{ $t('Remove') }}
              </el-button>
            </div>
            <el-button @click="addDnsServer" type="primary" size="small" v-if="dhcpConfig.dns_servers.length < 4">
              {{ $t('Add DNS Server') }}
            </el-button>
          </el-form-item>
        </template>
        
        <el-form-item>
          <el-button type="primary" @click="saveDhcpConfig" :loading="saving">
            {{ $t('Save & Apply') }}
          </el-button>
        </el-form-item>
      </el-form>
    </el-card>

    <!-- DHCP租约 -->
    <!-- DHCP租约管理 -->
    <el-card :header="$t('DHCP Lease Management')" v-if="dhcpConfig.dhcp_enabled">
      <div style="margin-bottom: 16px">
        <el-button type="primary" @click="showAddLeaseDialog">
          {{ $t('Add Static Lease') }}
        </el-button>
      </div>
      
      <el-table :data="allLeases" style="width: 100%">
        <el-table-column prop="hostname" :label="$t('Hostname')" width="180"/>
        <el-table-column prop="mac" :label="$t('MAC Address')" width="160">
          <template #default="{ row }">
            <span>{{ (row.mac || row.macaddr || '').toUpperCase() }}</span>
          </template>
        </el-table-column>
        <el-table-column prop="ip" :label="$t('IP Address')" width="140">
          <template #default="{ row }">
            <span>{{ row.ip || row.ipaddr }}</span>
          </template>
        </el-table-column>
        <el-table-column :label="$t('Type')" width="100">
          <template #default="{ row }">
            <el-tag :type="row.type === 'static' ? 'success' : 'info'">
              {{ row.type === 'static' ? $t('Static') : $t('Dynamic') }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column :label="$t('Lease Time')" width="150">
          <template #default="{ row }">
            <span v-if="row.type === 'static'">{{ $t('Permanent') }}</span>
            <span v-else>{{ formatLeaseTime(row.expire) }}</span>
          </template>
        </el-table-column>
        <el-table-column :label="$t('Actions')" width="200">
          <template #default="{ row }">
            <template v-if="row.type === 'static'">
              <el-button size="small" @click="editLease(row)">
                {{ $t('Edit') }}
              </el-button>
              <el-button size="small" type="danger" @click="deleteLease(row)">
                {{ $t('Delete') }}
              </el-button>
            </template>
            <template v-else>
              <el-button size="small" type="primary" @click="addToStatic(row)">
                {{ $t('Make Static') }}
              </el-button>
            </template>
          </template>
        </el-table-column>
      </el-table>
    </el-card>    <!-- 添加/编辑静态租约对话框 -->
    <el-dialog v-model="leaseDialogVisible" :title="isEditingLease ? $t('Edit Static Lease') : $t('Add Static Lease')" width="500px">
      <el-form ref="leaseForm" :model="currentLease" :rules="leaseRules" label-width="120px" style="width: 100%; min-width: 100%">
        <el-form-item :label="$t('Hostname')" prop="hostname">
          <el-input v-model="currentLease.hostname" placeholder="device-name"/>
        </el-form-item>
        
        <el-form-item :label="$t('MAC Address')" prop="mac">
          <el-input v-model="currentLease.mac" placeholder="aa:bb:cc:dd:ee:ff"/>
        </el-form-item>
        
        <el-form-item :label="$t('IP Address')" prop="ip">
          <el-input v-model="currentLease.ip" placeholder="192.168.1.100"/>
        </el-form-item>
      </el-form>
      
      <template #footer>
        <el-button @click="leaseDialogVisible = false">{{ $t('Cancel') }}</el-button>
        <el-button type="primary" @click="saveLease" :loading="saving">
          {{ $t('Save') }}
        </el-button>
      </template>
    </el-dialog>
  </el-space>
</template>

<script>
export default {
  data() {
    return {
      saving: false,
      lanConfig: {
        proto: 'static',
        ipaddr: '192.168.1.1',
        netmask: '255.255.255.0'
      },
      originalIpaddr: '192.168.1.1', // 用于检测IP地址是否变更
      dhcpConfig: {
        dhcp_enabled: true,
        dhcp_start: 100,
        dhcp_limit: 150,
        dhcp_leasetime: '12h',
        dns_servers: ['8.8.8.8', '8.8.4.4']
      },
      dynamicLeases: [],
      staticLeases: [],
      leaseDialogVisible: false,
      isEditingLease: false,
      currentLease: {
        hostname: '',
        mac: '',
        ip: ''
      },
      lanRules: {
        ipaddr: [
          { required: true, message: this.$t('Please enter IP address'), trigger: 'blur' },
          { pattern: /^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/, 
            message: this.$t('Please enter a valid IP address'), trigger: 'blur' }
        ]
      },
      dhcpRules: {
        dhcp_start: [
          { required: true, message: this.$t('Please enter start IP'), trigger: 'blur' }
        ],
        dhcp_limit: [
          { required: true, message: this.$t('Please enter IP count'), trigger: 'blur' }
        ]
      },
      leaseRules: {
        hostname: [
          { required: true, message: this.$t('Please enter hostname'), trigger: 'blur' }
        ],
        mac: [
          { required: true, message: this.$t('Please enter MAC address'), trigger: 'blur' },
          { pattern: /^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$/, 
            message: this.$t('Please enter a valid MAC address'), trigger: 'blur' }
        ],
        ip: [
          { required: true, message: this.$t('Please enter IP address'), trigger: 'blur' },
          { pattern: /^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/, 
            message: this.$t('Please enter a valid IP address'), trigger: 'blur' }
        ]
      }
    }
  },
  computed: {
    allLeases() {
      const staticLeasesWithType = this.staticLeases.map(lease => ({
        ...lease,
        type: 'static'
      }))
      
      const dynamicLeasesWithType = this.dynamicLeases.map(lease => ({
        ...lease,
        type: 'dynamic',
        mac: lease.macaddr,
        ip: lease.ipaddr
      }))
      
      return [...staticLeasesWithType, ...dynamicLeasesWithType]
    }
  },
  created() {
    this.loadLanConfig()
    this.loadStaticLeases()
    this.loadDynamicLeases()
    
    // 定时刷新动态租约
    this.$timer.create('dhcp-leases', this.loadDynamicLeases, { 
      time: 5000, 
      immediate: false, 
      repeat: true 
    })
  },
  beforeUnmount() {
    // 清理定时器
    this.$timer.stop('dhcp-leases')
  },
  methods: {
    async loadLanConfig() {
      try {
        const { config } = await this.$oui.call('lan', 'get_lan_config')
        this.lanConfig = {
          proto: config.proto || 'static',
          ipaddr: config.ipaddr || '192.168.1.1',
          netmask: config.netmask || '255.255.255.0'
        }
        this.originalIpaddr = this.lanConfig.ipaddr // 保存原始IP地址
        this.dhcpConfig = {
          dhcp_enabled: config.dhcp_enabled !== false,
          dhcp_start: parseInt(config.dhcp_start) || 100,
          dhcp_limit: parseInt(config.dhcp_limit) || 150,
          dhcp_leasetime: config.dhcp_leasetime || '12h',
          dns_servers: config.dns_servers || ['8.8.8.8', '8.8.4.4']
        }
      } catch (error) {
        this.$message.error(this.$t('Failed to load configuration'))
      }
    },
    
    async loadStaticLeases() {
      try {
        const { leases } = await this.$oui.call('lan', 'get_static_leases')
        this.staticLeases = leases
      } catch (error) {
        this.$message.error(this.$t('Failed to load static leases'))
      }
    },
    
    async loadDynamicLeases() {
      if (!this.dhcpConfig.dhcp_enabled) {
        this.dynamicLeases = []
        return
      }
      
      try {
        const { leases } = await this.$oui.call('lan', 'get_dhcp_leases')
        this.dynamicLeases = leases
      } catch (error) {
        console.error('Failed to load dynamic leases:', error)
        this.dynamicLeases = []
      }
    },
    
    formatLeaseTime(expire) {
      if (expire === -1) return this.$t('Permanent')
      if (expire === 0) return this.$t('Expired')
      
      const days = Math.floor(expire / 86400)
      const hours = Math.floor((expire % 86400) / 3600)
      const minutes = Math.floor(((expire % 86400) % 3600) / 60)
      const seconds = Math.floor(((expire % 86400) % 3600) % 60)
      
      if (days > 0) return `${days}d ${hours}h ${minutes}m`
      if (hours > 0) return `${hours}h ${minutes}m ${seconds}s`
      return `${minutes}m ${seconds}s`
    },
    
    async saveLanConfig() {
      this.$refs.lanForm.validate(async (valid) => {
        if (!valid) return
        
        const ipChanged = this.originalIpaddr !== this.lanConfig.ipaddr
        
        this.saving = true
        try {
          await this.$oui.call('lan', 'set_lan_config', this.lanConfig)
          await this.$oui.call('lan', 'restart_network')
          this.$message.success(this.$t('Configuration saved successfully'))
          
          // 如果IP地址发生变更，等待15秒后跳转到新IP
          if (ipChanged) {
            let countdown = 15
            const message = this.$message({
              message: this.$t('IP address changed, redirecting to') + ` ${this.lanConfig.ipaddr} ` + this.$t('in') + ` ${countdown} ` + this.$t('seconds'),
              type: 'info',
              duration: 0,
              showClose: false
            })
            
            const timer = setInterval(() => {
              countdown--
              if (countdown > 0) {
                message.message = this.$t('IP address changed, redirecting to') + ` ${this.lanConfig.ipaddr} ` + this.$t('in') + ` ${countdown} ` + this.$t('seconds')
              } else {
                clearInterval(timer)
                message.close()
                // 跳转到新的IP地址
                const newUrl = `${window.location.protocol}//${this.lanConfig.ipaddr}${window.location.pathname}`
                window.location.href = newUrl
              }
            }, 1000)
          }
          
          this.originalIpaddr = this.lanConfig.ipaddr
        } catch (error) {
          this.$message.error(this.$t('Failed to save configuration'))
        }
        this.saving = false
      })
    },
    
    async saveDhcpConfig() {
      this.$refs.dhcpForm.validate(async (valid) => {
        if (!valid) return
        
        this.saving = true
        try {
          await this.$oui.call('lan', 'set_lan_config', this.dhcpConfig)
          await this.$oui.call('lan', 'restart_network')
          this.$message.success(this.$t('Configuration saved successfully'))
          
          // 重新加载动态租约
          if (this.dhcpConfig.dhcp_enabled) {
            setTimeout(() => this.loadDynamicLeases(), 2000)
          } else {
            this.dynamicLeases = []
          }
        } catch (error) {
          this.$message.error(this.$t('Failed to save configuration'))
        }
        this.saving = false
      })
    },
    
    addDnsServer() {
      this.dhcpConfig.dns_servers.push('')
    },
    
    removeDnsServer(index) {
      this.dhcpConfig.dns_servers.splice(index, 1)
    },
    
    showAddLeaseDialog() {
      this.isEditingLease = false
      this.currentLease = {
        hostname: '',
        mac: '',
        ip: ''
      }
      this.leaseDialogVisible = true
    },
    
    editLease(lease) {
      this.isEditingLease = true
      this.currentLease = { ...lease }
      this.leaseDialogVisible = true
    },
    
    async saveLease() {
      this.$refs.leaseForm.validate(async (valid) => {
        if (!valid) return
        
        // 检查IP冲突
        const excludeSection = this.isEditingLease ? this.currentLease.name : undefined
        const { conflict, type, name } = await this.$oui.call('lan', 'check_ip_conflict', {
          ip: this.currentLease.ip,
          exclude_section: excludeSection
        })
        
        if (conflict) {
          this.$message.error(this.$t('IP address conflicts with existing static lease') + `: ${name}`)
          return
        }
        
        this.saving = true
        try {
          if (this.isEditingLease) {
            await this.$oui.call('lan', 'update_static_lease', this.currentLease)
          } else {
            await this.$oui.call('lan', 'add_static_lease', this.currentLease)
          }
          this.leaseDialogVisible = false
          await this.loadStaticLeases()
          this.$message.success(this.$t('Static lease saved successfully'))
        } catch (error) {
          this.$message.error(this.$t('Failed to save static lease'))
        }
        this.saving = false
      })
    },
    
    addToStatic(dynamicLease) {
      this.isEditingLease = false
      this.currentLease = {
        hostname: dynamicLease.hostname || '',
        mac: dynamicLease.mac || dynamicLease.macaddr || '',
        ip: dynamicLease.ip || dynamicLease.ipaddr || ''
      }
      this.leaseDialogVisible = true
    },
    
    async deleteLease(lease) {
      this.$confirm(this.$t('Are you sure you want to delete this static lease?'), this.$t('Confirm'), {
        type: 'warning'
      }).then(async () => {
        try {
          await this.$oui.call('lan', 'delete_static_lease', { section: lease.name })
          await this.loadStaticLeases()
          this.$message.success(this.$t('Static lease deleted successfully'))
        } catch (error) {
          this.$message.error(this.$t('Failed to delete static lease'))
        }
      })
    }
  }
}
</script>

<style scoped>
.form-help {
  font-size: 12px;
  color: #909399;
  margin-top: 4px;
}

/* 确保容器占满整个窗口 */
:deep(.el-space) {
  width: 100% !important;
  height: 100% !important;
}

/* 确保卡片占满宽度 */
:deep(.el-card) {
  width: 100%;
  margin-bottom: 16px;
}

/* 确保表单占满卡片宽度 */
:deep(.el-form) {
  width: 100%;
}
</style>

<i18n src="./locale.json"/>
