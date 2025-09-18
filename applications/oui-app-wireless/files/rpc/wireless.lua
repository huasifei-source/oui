local M = {}

local uci = require 'eco.uci'
local ubus = require 'eco.ubus'

-- 获取无线状态和列表
function M.get_wireless_status()
    local result = ubus.call('network.wireless', 'status', {})
    if not result then
        return { error = 'Failed to get wireless status' }
    end
    
    return { status = result }
end

-- 获取具体无线接口信息
function M.get_wireless_info(params)
    if not params.device then
        return { error = 'Device parameter is required' }
    end
    
    local result = ubus.call('iwinfo', 'info', { device = params.device })
    if not result then
        return { error = 'Failed to get wireless info' }
    end
    
    return { info = result }
end

-- 获取无线配置
function M.get_wireless_config()
    local c = uci.cursor()
    local radios = {}
    local interfaces = {}
    
    -- 获取所有radio配置
    c:foreach('wireless', 'wifi-device', function(section)
        radios[section['.name']] = {
            name = section['.name'],
            disabled = section.disabled == '1',
            channel = section.channel or 'auto',
            htmode = section.htmode or 'HT20',
            band = section.band or '',
            txpower = section.txpower or '',
            country = section.country or ''
        }
    end)
    
    -- 获取所有接口配置
    c:foreach('wireless', 'wifi-iface', function(section)
        interfaces[section['.name']] = {
            name = section['.name'],
            device = section.device or '',
            mode = section.mode or 'ap',
            ssid = section.ssid or '',
            encryption = section.encryption or 'none',
            key = section.key or '',
            hidden = section.hidden == '1',
            disabled = section.disabled == '1',
            network = section.network or {}
        }
    end)
    
    return { 
        radios = radios, 
        interfaces = interfaces 
    }
end

-- 设置radio配置
function M.set_radio_config(params)
    local c = uci.cursor()
    
    if not params.radio then
        return { error = 'Radio parameter is required' }
    end
    
    local radio = params.radio
    
    -- 设置radio配置
    if params.disabled ~= nil then
        if params.disabled then
            c:set('wireless', radio, 'disabled', '1')
        else
            c:delete('wireless', radio, 'disabled')
        end
    end
    
    if params.channel then
        c:set('wireless', radio, 'channel', params.channel)
    end
    
    if params.htmode then
        c:set('wireless', radio, 'htmode', params.htmode)
    end
    
    if params.txpower then
        c:set('wireless', radio, 'txpower', params.txpower)
    end
    
    if params.country then
        c:set('wireless', radio, 'country', params.country)
    end
    
    c:commit('wireless')
    
    return { success = true }
end

-- 设置接口配置
function M.set_interface_config(params)
    local c = uci.cursor()
    
    if not params.interface then
        return { error = 'Interface parameter is required' }
    end
    
    local iface = params.interface
    
    -- 设置接口配置
    if params.ssid then
        c:set('wireless', iface, 'ssid', params.ssid)
    end
    
    if params.encryption then
        c:set('wireless', iface, 'encryption', params.encryption)
    end
    
    if params.key then
        if params.encryption ~= 'none' and params.encryption ~= '' then
            c:set('wireless', iface, 'key', params.key)
        else
            c:delete('wireless', iface, 'key')
        end
    end
    
    if params.hidden ~= nil then
        if params.hidden then
            c:set('wireless', iface, 'hidden', '1')
        else
            c:delete('wireless', iface, 'hidden')
        end
    end
    
    if params.disabled ~= nil then
        if params.disabled then
            c:set('wireless', iface, 'disabled', '1')
        else
            c:delete('wireless', iface, 'disabled')
        end
    end
    
    if params.mode then
        c:set('wireless', iface, 'mode', params.mode)
    end
    
    if params.network then
        c:set('wireless', iface, 'network', params.network)
    end
    
    c:commit('wireless')
    
    return { success = true }
end

-- 添加新的无线接口
function M.add_wireless_interface(params)
    local c = uci.cursor()
    
    if not params.device then
        return { error = 'Device parameter is required' }
    end
    
    local section = c:add('wireless', 'wifi-iface')
    
    c:set('wireless', section, 'device', params.device)
    c:set('wireless', section, 'mode', params.mode or 'ap')
    c:set('wireless', section, 'ssid', params.ssid or 'OpenWrt')
    c:set('wireless', section, 'encryption', params.encryption or 'none')
    
    if params.key and params.encryption ~= 'none' then
        c:set('wireless', section, 'key', params.key)
    end
    
    if params.network then
        c:set('wireless', section, 'network', params.network)
    end
    
    if params.hidden then
        c:set('wireless', section, 'hidden', '1')
    end
    
    c:commit('wireless')
    
    return { success = true, section = section }
end

-- 删除无线接口
function M.delete_wireless_interface(params)
    local c = uci.cursor()
    
    if not params.interface then
        return { error = 'Interface parameter is required' }
    end
    
    c:delete('wireless', params.interface)
    c:commit('wireless')
    
    return { success = true }
end

-- 重启无线服务
function M.restart_wireless()
    ubus.call('network.wireless', 'down', {})
    ubus.call('network.wireless', 'up', {})
    return { success = true }
end

-- 重新加载配置而不重启服务
function M.reload_config()
    -- 重新加载UCI配置到内存
    local result = ubus.call('uci', 'reload_config', {})
    if not result then
        return { error = 'Failed to reload UCI config' }
    end
    
    -- 重新应用无线配置
    ubus.call('network.wireless', 'reload', {})
    
    return { success = true }
end

-- 获取支持的加密方式
function M.get_encryption_modes()
    return {
        modes = {
            { value = 'none', label = 'No Encryption' },
            { value = 'psk', label = 'WPA-PSK' },
            { value = 'psk2', label = 'WPA2-PSK' },
            { value = 'psk-mixed', label = 'WPA/WPA2-PSK Mixed' },
            { value = 'sae', label = 'WPA3-SAE' },
            { value = 'sae-mixed', label = 'WPA2/WPA3-SAE Mixed' }
        }
    }
end

-- 获取支持的频宽模式
-- 该方法已废弃，频宽模式现在在前端动态生成
function M.get_htmodes()
    -- 保留接口以兼容性，但不再使用
    return { modes = {} }
end

-- 获取无线扫描结果
function M.scan_wireless(params)
    if not params.device then
        return { error = 'Device parameter is required' }
    end
    
    local result = ubus.call('iwinfo', 'scanlist', { device = params.device })
    if not result then
        return { error = 'Failed to scan wireless networks' }
    end
    
    return { scanlist = result.results or {} }
end

return M
