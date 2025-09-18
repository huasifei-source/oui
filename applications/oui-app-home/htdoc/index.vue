<template>
	<div class="overview-container">
		<div v-if="loading" class="loading">
			<el-icon class="is-loading"><Loading /></el-icon>
			<span>{{ $t('Loading...') }}</span>
		</div>
		<!-- 顶部：系统概览 -->
		<div class="top-grid">
			<el-card shadow="hover" class="system-card">
				<template #header>
					<div class="card-header">
						<div class="title">
							<el-icon class="title-icon"><Monitor /></el-icon>
							<span>{{ $t('System Overview') }}</span>
											<el-tag size="small" type="success" class="status-tag">{{ state.system.hostname }}</el-tag>
						</div>
					</div>
				</template>

				<div class="system-content">
					<div class="gauge-row">
						<dashboard
							:label="$t('CPU Usage')"
											:percentage="state.system.cpu.usage"
							color="#60a5fa"
						>
							<div class="tip">
												<div>{{ $t('Cores') }}: {{ state.system.cpu.cores || '-' }}</div>
												<div>{{ $t('Load') }}: {{ (state.system.load || []).join(', ') }}</div>
							</div>
						</dashboard>

						<dashboard
							:label="$t('Memory Usage')"
											:percentage="state.system.memory.usage"
							color="#34d399"
						>
							<div class="tip">
												<div>{{ $t('Total') }}: {{ formatBytes(state.system.memory.total) }}</div>
												<div>{{ $t('Used') }}: {{ formatBytes(state.system.memory.used) }}</div>
												<div>{{ $t('Free') }}: {{ formatBytes(state.system.memory.free) }}</div>
							</div>
						</dashboard>
					</div>

					<el-divider />

					<div class="kv-grid">
						<div class="kv-item">
							<div class="kv-label">{{ $t('Hostname') }}</div>
											<div class="kv-value">{{ state.system.hostname }}</div>
						</div>
						<div class="kv-item">
							<div class="kv-label">{{ $t('Model') }}</div>
											<div class="kv-value">{{ state.system.model }}</div>
						</div>
						<div class="kv-item">
											<div class="kv-label">{{ $t('Kernel') }}</div>
											<div class="kv-value">{{ state.system.kernel }}</div>
						</div>
						<div class="kv-item">
							<div class="kv-label">{{ $t('Uptime') }}</div>
											<div class="kv-value">{{ formatUptime(state.system.uptime) }}</div>
						</div>
					</div>
				</div>
			</el-card>

			<!-- 网络概览 -->
			<el-card shadow="hover" class="network-card">
				<template #header>
					<div class="card-header">
						<div class="title">
							<el-icon class="title-icon"><Connection /></el-icon>
							<span>{{ $t('Network Overview') }}</span>
						</div>
						<div class="sub">
											<el-tag v-if="state.network.defaultGateway" type="info" effect="plain" size="small">
												{{ $t('Default Gateway') }}: {{ state.network.defaultGateway.gateway }}
												({{ state.network.defaultGateway.interface }})
							</el-tag>
						</div>
					</div>
				</template>

				<div class="network-content">
					<div class="iface-section">
						<div class="section-title">
							<el-icon><Guide /></el-icon>
							<span>WAN / Repeater</span>
						</div>
						<div class="iface-grid">
											<div v-for="iface in wanIfaces" :key="iface.name" class="iface-card" :class="{ up: iface.up }">
								<div class="iface-head">
									<span class="iface-name">{{ iface.name }}</span>
									<el-tag :type="iface.up ? 'success' : 'danger'" size="small">{{ iface.up ? $t('Up') : $t('Down') }}</el-tag>
								</div>
								<div class="iface-body">
									<div class="row"><span>{{ $t('Protocol') }}</span><b>{{ iface.proto }}</b></div>
													<div class="row" v-if="iface.ipv4[0]"><span>IPv4</span><b>{{ iface.ipv4[0].address }}/{{ iface.ipv4[0].mask }}</b></div>
									<div class="row" v-if="iface.gateway"><span>{{ $t('Gateway') }}</span><b>{{ iface.gateway }}</b></div>
									<div class="row" v-if="iface.dns && iface.dns.length"><span>DNS</span><b>{{ iface.dns.join(', ') }}</b></div>
								</div>
							</div>
						</div>
					</div>

					<el-divider/>

					<div class="iface-section">
						<div class="section-title">
							<el-icon><Collection /></el-icon>
							<span>{{ $t('Other Interfaces') }}</span>
						</div>
						<div class="iface-grid">
											<div v-for="iface in otherIfaces" :key="iface.name" class="iface-card" :class="{ up: iface.up }">
								<div class="iface-head">
									<span class="iface-name">{{ iface.name }}</span>
									<el-tag :type="iface.up ? 'success' : 'danger'" size="small">{{ iface.up ? $t('Up') : $t('Down') }}</el-tag>
								</div>
								<div class="iface-body">
									<div class="row"><span>{{ $t('Protocol') }}</span><b>{{ iface.proto }}</b></div>
													<div class="row" v-if="iface.ipv4[0]"><span>IPv4</span><b>{{ iface.ipv4[0].address }}/{{ iface.ipv4[0].mask }}</b></div>
													<div class="row" v-if="iface.ipv6 && iface.ipv6[0]"><span>IPv6</span><b>{{ iface.ipv6[0].address }}/{{ iface.ipv6[0].mask }}</b></div>
								</div>
							</div>
						</div>
					</div>
				</div>
			</el-card>
		</div>

		<!-- 已连接设备 -->
		<el-card shadow="hover" class="devices-card">
			<template #header>
				<div class="card-header">
					<div class="title">
						<el-icon class="title-icon"><User /></el-icon>
						<span>{{ $t('Connected Devices') }}</span>
					</div>
				</div>
			</template>

					<el-table :data="state.devices" border size="small" class="device-table">
				<el-table-column :label="$t('Hostname / IP')" min-width="200">
  <template #default="{ row }">
    <span v-if="row.hostname && row.hostname.trim()">
      {{ row.ip }} ({{ row.hostname }})
    </span>
    <span v-else>
      {{ row.ip }}
    </span>
  </template>
</el-table-column>
				<el-table-column prop="mac" label="MAC" min-width="170"/>
				<el-table-column :label="$t('Connection')" min-width="120">
					<template #default="{ row }">
						<el-tag :type="row.type === 'wireless' ? 'warning' : 'info'" size="small">
							{{ row.type === 'wireless' ? 'Wi‑Fi' : 'Ethernet' }}
						</el-tag>
					</template>
				</el-table-column>
				<el-table-column prop="iface" :label="$t('Interface')" min-width="120"/>
				<el-table-column :label="$t('Signal')" min-width="120">
					<template #default="{ row }">
						<span v-if="row.type === 'wireless'">{{ row.signal }} dBm</span>
						<span v-else>—</span>
					</template>
				</el-table-column>
			</el-table>
		</el-card>
	</div>
</template>

<script>
		import { Monitor, Connection, Guide, Collection, User, Loading } from '@element-plus/icons-vue'
import dashboard from './dashboard.vue'

export default {
			components: { Monitor, Connection, Guide, Collection, User, Loading, dashboard },
	data() {
		return {
					loading: true,
					state: {
						system: { hostname: '-', model: '-', kernel: '-', uptime: 0, load: [], cpu: { usage: 0, cores: null }, memory: { total: 0, used: 0, free: 0, usage: 0 } },
						network: { defaultGateway: null, interfaces: [] },
						devices: []
					}
		}
	},
			created() {
				this.fetchOverview()
			},
	computed: {
		wanIfaces() {
					return this.state.network.interfaces.filter(i => i.name === 'wan' || i.name === 'repeater' || i.name.startsWith('wan'))
		},
		otherIfaces() {
					return this.state.network.interfaces.filter(i => i.name !== 'wan' && i.name !== 'repeater' && !i.name.startsWith('wan') && i.name !== 'loopback')
		}
	},
	methods: {
				async fetchOverview() {
					this.loading = true
					try {
						const res = await this.$oui.call('overview', 'get_overview').catch(() => ({}))
						const mapped = this.mapOverview(res && typeof res === 'object' ? res : {})
						Object.assign(this.state, mapped)
					} catch (e) {
						console.error('Failed to load overview:', e)
						this.$message && this.$message.error(this.$t('Failed to load overview data'))
					}
					this.loading = false
				},
				mapOverview(res) {
					const sysNode = res.system || {}
					const sys = sysNode.system || {}
					const board = sysNode.board || {}
					const cpu = sysNode.cpu || {}
					const mem = (sys && sys.memory) || {}

					const defaultGw = res.network && res.network.default_gateway
						? { interface: res.network.default_gateway.interface, gateway: res.network.default_gateway.gateway }
						: null

					const interfacesMap = (res.network && res.network.interfaces) || {}
					const interfaces = Object.values(interfacesMap).map((iface) => ({
						name: iface.name || iface.interface || '-',
						up: !!iface.up,
						proto: iface.proto || 'unknown',
						ipv4: iface.ipv4_addresses || [],
						ipv6: iface.ipv6_addresses || [],
						gateway: defaultGw && defaultGw.interface === (iface.name || iface.interface) ? defaultGw.gateway : undefined,
						dns: iface.dns_servers || []
					}))

							const devices = this.mergeDevices(res.devices || {})

					const used = typeof mem.used === 'number' ? mem.used : Math.max(0, (mem.total || 0) - (mem.available || mem.free || 0))
					const usagePct = mem.usage_percent != null ? mem.usage_percent : ((mem.total || 0) > 0 ? Math.round((used / mem.total) * 100) : 0)

					return {
						system: {
							hostname: sys.hostname || this.$oui?.state?.hostname || '-',
							model: sys.model || board.model || '-',
							kernel: sys.kernel || '-',
							uptime: sys.uptime || 0,
							load: Array.isArray(sys.load) ? sys.load : [],
							cpu: { usage: cpu.usage_percent != null ? cpu.usage_percent : 0, cores: cpu.cores },
							memory: { total: mem.total || 0, used, free: mem.free || 0, usage: usagePct }
						},
						network: { defaultGateway: defaultGw, interfaces },
						devices
					}
				},
    // Merge devices with rules:
    // 1) Compare MAC in uppercase
    // 2) Include all ARP devices whose interface is br-lan (or prefixed)
    // 3) Enrich using wireless (iwinfo assoclist) and dhcp-lease info when available
		mergeDevices(devNode) {
  const up = (s) => (s || '').toUpperCase();
  const byMac = new Map();

  // backend now returns { arp: [], dhcp_leases: [], wireless_assoc: { ifname: [] } }
  const arp = Array.isArray(devNode.arp) ? devNode.arp : [];
  const dhcp = Array.isArray(devNode.dhcp_leases) ? devNode.dhcp_leases : [];
  const assocMap = devNode.wireless_assoc || {};

  // Seed wireless from assoclist
  for (const [ifname, list] of Object.entries(assocMap)) {
    const arr = Array.isArray(list) ? list : [];
    for (const st of arr) {
      const macU = up(st.mac);
      if (!macU) continue;
      byMac.set(macU, {
        mac: macU,
        hostname: '',
        ip: '',
        type: 'wireless',
        iface: ifname,
        signal: st.signal,
      });
    }
  }

  // Merge ARP: include only br-lan devices
  for (const a of arp) {
    const macU = up(a.mac);
    if (!macU) continue;
    const iface = a.device || '';
    const isBrLan = iface === 'br-lan' || iface.startsWith('br-lan');
    if (!isBrLan) continue;

    const existing = byMac.get(macU);
    if (!existing) {
      byMac.set(macU, {
        mac: macU,
        hostname: '',
        ip: a.ip || '',
        type: 'wired',
        iface,
      });
    } else {
      if (!existing.ip && a.ip) existing.ip = a.ip;
      if (!existing.iface && iface) existing.iface = iface;
    }
  }

  // Merge DHCP to fill hostname/ip only if device already exists
  for (const d of dhcp) {
    const macU = up(d.mac);
    if (!macU) continue;
    const existing = byMac.get(macU);
    if (existing) {
      if (!existing.ip && d.ip) existing.ip = d.ip;
      if (!existing.hostname && d.hostname) existing.hostname = d.hostname;
    }
  }

  // Convert to array and keep MAC uppercase
  return Array.from(byMac.values());
},
		formatBytes(v) {
			if (!v && v !== 0) return '-'
			const units = ['B', 'KB', 'MB', 'GB', 'TB']
			let n = v
			let i = 0
			while (n >= 1024 && i < units.length - 1) { n /= 1024; i++ }
			return `${n.toFixed(n >= 10 || i === 0 ? 0 : 1)} ${units[i]}`
		},
		formatUptime(sec) {
			const d = Math.floor(sec / 86400)
			const h = Math.floor((sec % 86400) / 3600)
			const m = Math.floor((sec % 3600) / 60)
			return [d ? `${d}d` : '', h ? `${h}h` : '', `${m}m`].filter(Boolean).join(' ')
		}
	}
}
</script>

<style scoped>
		.loading { display:flex; gap:8px; align-items:center; color:#606266; margin: 8px 0 16px; }
.overview-container {
	--bg-gradient-light: linear-gradient(135deg, #f5f7fa 0%, #e6eeff 100%);
	--bg-gradient-dark: linear-gradient(135deg, #1a1a1a 0%, #2d2d2d 100%);
	--card-bg-light: rgba(255, 255, 255, 0.95);
	--card-bg-dark: rgba(42, 42, 42, 0.95);
	--card-border-light: rgba(0, 0, 0, 0.06);
	--card-border-dark: rgba(255, 255, 255, 0.12);
	--text-primary-light: #303133;
	--text-primary-dark: #e4e4e7;
	--text-secondary-light: #606266;
	--text-secondary-dark: #a1a1aa;
	--shadow-light: rgba(0,0,0,0.08);
	--shadow-dark: rgba(0,0,0,0.3);
	--header-bg-light: linear-gradient(135deg, #dbeafe 0%, #93c5fd 100%);
	--header-bg-dark: linear-gradient(135deg, #1f2937 0%, #111827 100%);
	--header-text-light: #1f2937;
	--header-text-dark: #f9fafb;
	--header-border-light: #93c5fd;
	--header-border-dark: #374151;

	padding: 20px;
	min-height: 100vh;
	background: var(--bg-gradient-light);
}

.dark .overview-container { background: var(--bg-gradient-dark); }

.top-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 24px; margin-bottom: 24px; }

.card-header { display:flex; justify-content: space-between; align-items:center; margin:-8px 0; }
.title { display:flex; align-items:center; gap:10px; color: var(--header-text-light); }
.dark .title { color: var(--header-text-dark); }
.title-icon { color:#409EFF; }
.status-tag { margin-left: 8px; }

.system-card, .network-card, .devices-card { border-radius: 16px; border:1px solid var(--card-border-light); background: var(--card-bg-light); box-shadow: 0 8px 24px var(--shadow-light); }
.dark .system-card, .dark .network-card, .dark .devices-card { border:1px solid var(--card-border-dark); background: var(--card-bg-dark); box-shadow: 0 8px 24px var(--shadow-dark); }

.system-content { display:flex; flex-direction: column; gap: 12px; }
.gauge-row { display:flex; gap: 36px; align-items:center; justify-content:flex-start; }

.kv-grid { display:grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 12px; }
.kv-item { background: rgba(255,255,255,0.6); border-radius: 10px; padding: 12px; border:1px solid rgba(0,0,0,0.04); }
.dark .kv-item { background: rgba(0,0,0,0.2); border-color: rgba(255,255,255,0.08); }
.kv-label { font-size: 12px; opacity:0.7; margin-bottom: 4px; text-transform: uppercase; }
.kv-value { font-weight: 600; color: var(--text-primary-light); }
.dark .kv-value { color: var(--text-primary-dark); }

.network-content { display:flex; flex-direction: column; gap: 12px; }
.iface-section { display:flex; flex-direction: column; gap: 10px; }
.section-title { display:flex; align-items:center; gap:8px; font-weight:600; color:#1e293b; }
.dark .section-title { color:#cbd5e1; }
.iface-grid { display:grid; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); gap: 12px; }
.iface-card { border:1px solid #e5e7eb; border-radius: 12px; padding: 12px; background: #ffffffd9; transition: all .2s ease; }
.iface-card.up { border-color:#34d399; box-shadow: 0 4px 16px rgba(52,211,153,0.15); }
.dark .iface-card { background:#2a2a2a; border-color:#4b5563; }
.iface-head { display:flex; justify-content: space-between; align-items:center; margin-bottom:8px; }
.iface-name { font-weight:600; }
.iface-body .row { display:flex; justify-content: space-between; padding: 4px 0; font-size: 13px; }
.iface-body .row span { color: var(--text-secondary-light); }
.dark .iface-body .row span { color: var(--text-secondary-dark); }

.device-table { width:100%; }

@media (max-width: 1200px) { .top-grid { grid-template-columns: 1fr; } }
</style>
