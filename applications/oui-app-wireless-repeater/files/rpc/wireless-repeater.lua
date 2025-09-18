local M = {}

local uci = require 'eco.uci'
local ubus = require 'eco.ubus'

-- 获取无线设备列表
function M.get_wireless_devices()
    local result = ubus.call('network.wireless', 'status', {})
    if not result then
        return { error = 'Failed to get wireless status' }
    end
    
    local devices = {}
    for device_name, device_info in pairs(result) do
        if device_info.config then
            devices[device_name] = {
                name = device_name,
                band = device_info.config.band or 'unknown',
                up = device_info.up or false,
                disabled = device_info.disabled or false
            }
        end
    end
    
    return { devices = devices }
end

-- 扫描无线网络
function M.scan_wireless_networks(params)
    if not params.device then
        return { error = 'Device parameter is required' }
    end
    
    -- 使用 iwinfo scan 扫描
    local result = ubus.call('iwinfo', 'scan', { device = params.device })
    if not result or not result.results then
        return { error = 'Failed to scan wireless networks' }
    end
    
    -- 处理扫描结果，提取有用信息
    local networks = {}
    for _, network in ipairs(result.results) do
        local encryption_info = "Open"
        if network.encryption and network.encryption.enabled then
            if network.encryption.wpa then
                local wpa_versions = {}
                for _, version in ipairs(network.encryption.wpa) do
                    table.insert(wpa_versions, "WPA" .. version)
                end
                encryption_info = table.concat(wpa_versions, "/")
                
                if network.encryption.authentication then
                    for _, auth in ipairs(network.encryption.authentication) do
                        if auth == "psk" then
                            encryption_info = encryption_info .. "-PSK"
                        end
                    end
                end
            end
        end
        
        table.insert(networks, {
            ssid = network.ssid or "",
            bssid = network.bssid or "",
            channel = network.channel or 0,
            signal = network.signal or -100,
            quality = network.quality or 0,
            quality_max = network.quality_max or 100,
            encryption = encryption_info,
            encryption_raw = network.encryption,
            band = network.band or 2
        })
    end
    
    -- 按信号强度排序
    table.sort(networks, function(a, b)
        return a.signal > b.signal
    end)
    
    return { networks = networks }
end

-- 获取当前中继配置
function M.get_repeater_config()
    local c = uci.cursor()
    local config = {
        enabled = false,
        ssid = "",
        bssid = "",
        encryption = "",
        key = "",
        device = "",
        status = "disconnected"
    }
    
    -- 查找现有的中继接口配置
    c:foreach('wireless', 'wifi-iface', function(section)
        if section.mode == 'sta' and section.network == 'repeater' then
            config.enabled = section.disabled ~= '1'
            config.ssid = section.ssid or ""
            config.bssid = section.bssid or ""
            config.encryption = section.encryption or ""
            config.key = section.key or ""
            config.device = section.device or ""
            return false -- 只取第一个匹配的
        end
    end)
    
    -- 检查网络接口配置
    local network_config = c:get_all('network', 'repeater')
    if network_config then
        config.network_proto = network_config.proto or 'dhcp'
    end
    
    -- 获取连接状态
    local wireless_status = ubus.call('network.wireless', 'status', {})
    if wireless_status and config.device and wireless_status[config.device] then
        local device_status = wireless_status[config.device]
        if device_status.interfaces then
            for _, iface in ipairs(device_status.interfaces) do
                if iface.config and iface.config.mode == 'sta' and iface.config.network and 
                   type(iface.config.network) == 'table' and iface.config.network[1] == 'repeater' then
                    -- 检查接口状态
                    local iface_status = ubus.call('network.interface', 'status', { interface = 'repeater' })
                    if iface_status then
                        config.status = iface_status.up and "connected" or "disconnected"
                        if iface_status.up and iface_status['ipv4-address'] then
                            config.ip_address = iface_status['ipv4-address'][1] and iface_status['ipv4-address'][1].address
                        end
                    end
                    break
                end
            end
        end
    end
    
    return { config = config }
end

-- 配置无线中继
function M.configure_repeater(params)
    if not params.ssid or not params.device then
        return { error = 'SSID and device are required' }
    end
    
    local c = uci.cursor()
    
    -- 删除现有的中继配置
    c:foreach('wireless', 'wifi-iface', function(section)
        if section.mode == 'sta' and section.network == 'repeater' then
            c:delete('wireless', section['.name'])
        end
    end)
    
    -- 创建新的wifi-iface配置
    local section_name = c:add('wireless', 'wifi-iface')
    if not section_name then
        return { error = 'Failed to create wifi-iface section' }
    end
    
    -- 设置基本配置
    c:set('wireless', section_name, 'device', params.device)
    c:set('wireless', section_name, 'mode', 'sta')
    c:set('wireless', section_name, 'network', 'repeater')
    c:set('wireless', section_name, 'ssid', params.ssid)
    
    if params.bssid and params.bssid ~= "" then
        c:set('wireless', section_name, 'bssid', params.bssid)
    end
    
    -- 设置加密配置
    if params.encryption and params.encryption ~= "" and params.encryption ~= "Open" then
        local encryption_type = params.encryption:lower()
        
        -- 处理常见的加密类型
        if encryption_type:find("wpa2") or encryption_type:find("psk2") then
            c:set('wireless', section_name, 'encryption', 'psk2')
        elseif encryption_type:find("wpa") or encryption_type:find("psk") then
            c:set('wireless', section_name, 'encryption', 'psk')
        elseif encryption_type:find("wep") then
            c:set('wireless', section_name, 'encryption', 'wep')
        else
            c:set('wireless', section_name, 'encryption', 'psk2')  -- 默认使用WPA2
        end
        
        if params.key and params.key ~= "" then
            c:set('wireless', section_name, 'key', params.key)
        end
    else
        c:set('wireless', section_name, 'encryption', 'none')
    end
    
    -- 设置为启用状态
    c:set('wireless', section_name, 'disabled', '0')
    
    -- 配置网络接口
    c:set('network', 'repeater', 'interface')
    c:set('network', 'repeater', 'proto', 'dhcp')

    -- 绑定到 wan 防火墙区域
    local function ensure_in_wan(zone)
        if not zone.network then
            c:set('firewall', zone['.name'], 'network', {'wan', 'repeater'})
            return true
        end
        if type(zone.network) == 'string'then
            fw_networks = { zone.network }
        else
            fw_networks = zone.network
        end
        for _, n in ipairs(fw_networks) do
            if n == 'repeater' then
                return true
            end
        end
        table.insert(fw_networks, 'repeater')
            c:set('firewall', zone['.name'], 'network', fw_networks)
        return false
    end

    c:foreach('firewall', 'zone', function(zone)
        if zone.name == 'wan' then
            ensure_in_wan(zone)
        end
    end)
    
    -- 提交配置
    if not c:commit('wireless') then
        return { error = 'Failed to commit wireless configuration' }
    end
    
    if not c:commit('network') then
        return { error = 'Failed to commit network configuration' }
    end
    
    if not c:commit('firewall') then
        return { error = 'Failed to commit firewall configuration' }
    end
    return { success = true }
end

-- 启用/禁用中继
function M.toggle_repeater(params)
    local c = uci.cursor()
    local enabled = params.enabled == true
    
    local found = false
    c:foreach('wireless', 'wifi-iface', function(section)
        if section.mode == 'sta' and section.network == 'repeater' then
            c:set('wireless', section['.name'], 'disabled', enabled and '0' or '1')
            found = true
            return false
        end
    end)
    
    if not found then
        return { error = 'No repeater configuration found' }
    end
    
    if not c:commit('wireless') then
        return { error = 'Failed to commit configuration' }
    end
    
    return { success = true }
end

-- 删除中继配置
function M.delete_repeater()
    local c = uci.cursor()
    
    -- 删除无线接口配置
    c:foreach('wireless', 'wifi-iface', function(section)
        if section.mode == 'sta' and section.network == 'repeater' then
            c:delete('wireless', section['.name'])
        end
    end)
    
    -- 删除网络接口配置
    c:delete('network', 'repeater')
    
    -- 提交配置
    c:commit('wireless')
    c:commit('network')
    
    return { success = true }
end

-- 重载无线和网络配置
function M.reload_config()
    -- 重载无线配置
    local result1 = ubus.call('network.wireless', 'reload', {})
    -- 重载网络配置
    local result2 = ubus.call('network', 'reload', {})
    
    return { 
        success = true,
        wireless_reload = result1 ~= nil,
        network_reload = result2 ~= nil
    }
end

-- 获取连接状态详情
function M.get_connection_status()
    local status = {
        connected = false,
        interface_up = false,
        ip_address = nil,
        gateway = nil,
        dns_servers = {},
        signal_info = {}
    }
    
    -- 检查网络接口状态
    local iface_status = ubus.call('network.interface', 'status', { interface = 'repeater' })
    if iface_status then
        status.interface_up = iface_status.up or false
        
        if iface_status.up and iface_status['ipv4-address'] then
            status.connected = true
            local ipv4 = iface_status['ipv4-address'][1]
            if ipv4 then
                status.ip_address = ipv4.address
            end
        end
        
        if iface_status['route'] then
            for _, route in ipairs(iface_status['route']) do
                if route.target == '0.0.0.0' then
                    status.gateway = route.nexthop
                end
            end
        end
        
        if iface_status['dns-server'] then
            status.dns_servers = iface_status['dns-server']
        end
    end
    
    -- 获取无线信号信息
    local wireless_status = ubus.call('network.wireless', 'status', {})
    if wireless_status then
        for device_name, device_info in pairs(wireless_status) do
            if device_info.interfaces then
                for _, iface in ipairs(device_info.interfaces) do
                    if iface.config and iface.config.mode == 'sta' and 
                       iface.config.network and type(iface.config.network) == 'table' and 
                       iface.config.network[1] == 'repeater' then
                        
                        -- 获取信号强度信息
                        if iface.ifname then
                            local iwinfo_result = ubus.call('iwinfo', 'info', { device = iface.ifname })
                            if iwinfo_result then
                                status.signal_info = {
                                    signal = iwinfo_result.signal or 0,
                                    noise = iwinfo_result.noise or 0,
                                    bitrate = iwinfo_result.bitrate or 0,
                                    quality = iwinfo_result.quality or 0,
                                    quality_max = iwinfo_result.quality_max or 100
                                }
                            end
                        end
                        break
                    end
                end
            end
        end
    end
    
    return { status = status }
end

return M
