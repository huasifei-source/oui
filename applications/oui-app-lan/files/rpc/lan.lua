local M = {}

local uci = require 'eco.uci'
local ubus = require 'eco.ubus'

-- 获取LAN接口配置
function M.get_lan_config()
    local c = uci.cursor()
    local config = {}
    
    -- 获取LAN接口配置
    config.ipaddr = c:get('network', 'lan', 'ipaddr') or '192.168.1.1'
    config.netmask = c:get('network', 'lan', 'netmask') or '255.255.255.0'
    config.proto = c:get('network', 'lan', 'proto') or 'static'
    
    -- 获取DHCP配置
    config.dhcp_start = c:get('dhcp', 'lan', 'start') or '100'
    config.dhcp_limit = c:get('dhcp', 'lan', 'limit') or '150'
    config.dhcp_leasetime = c:get('dhcp', 'lan', 'leasetime') or '12h'
    
    -- 获取DHCP服务器开关状态
    local dhcp_ignore = c:get('dhcp', 'lan', 'ignore')
    config.dhcp_enabled = dhcp_ignore ~= '1'
    
    -- 获取DNS配置
    local dns_servers = c:get('dhcp', '@dnsmasq[0]', 'server') or {}
    if type(dns_servers) == 'string' then
        dns_servers = { dns_servers }
    end
    config.dns_servers = dns_servers
    
    return { config = config }
end

-- 设置LAN接口配置
function M.set_lan_config(params)
    local c = uci.cursor()
    
    -- 设置LAN接口
    if params.ipaddr then
        c:set('network', 'lan', 'ipaddr', params.ipaddr)
    end
    if params.netmask then
        c:set('network', 'lan', 'netmask', params.netmask)
    end
    if params.proto then
        c:set('network', 'lan', 'proto', params.proto)
    end
    
    -- 设置DHCP配置
    if params.dhcp_start then
        c:set('dhcp', 'lan', 'start', params.dhcp_start)
    end
    if params.dhcp_limit then
        c:set('dhcp', 'lan', 'limit', params.dhcp_limit)
    end
    if params.dhcp_leasetime then
        c:set('dhcp', 'lan', 'leasetime', params.dhcp_leasetime)
    end
    
    -- 设置DHCP服务器开关
    if params.dhcp_enabled ~= nil then
        if params.dhcp_enabled then
            c:delete('dhcp', 'lan', 'ignore')
        else
            c:set('dhcp', 'lan', 'ignore', '1')
        end
    end
    
    -- 设置DNS服务器
    if params.dns_servers then
        c:delete('dhcp', '@dnsmasq[0]', 'server')
        for _, dns in ipairs(params.dns_servers) do
            if dns and dns ~= '' then
                c:add_list('dhcp', '@dnsmasq[0]', 'server', dns)
            end
        end
    end
    
    c:commit('network')
    c:commit('dhcp')
    
    return { success = true }
end

-- 获取静态DHCP租约
function M.get_static_leases()
    local c = uci.cursor()
    local leases = {}
    
    c:foreach('dhcp', 'host', function(section)
        leases[#leases + 1] = {
            name = section['.name'],
            hostname = section.name or '',
            mac = section.mac or '',
            ip = section.ip or ''
        }
    end)
    
    return { leases = leases }
end

-- 获取动态DHCP租约
function M.get_dhcp_leases()
    local c = uci.cursor()
    local leases = {}
    local leasefile = c:get('dhcp', '@dnsmasq[0]', 'leasefile') or '/tmp/dhcp.leases'

    if not require('eco.file').access(leasefile) then
        return { leases = leases }
    end

    local now = os.time()

    for line in io.lines(leasefile) do
        local ts, mac, addr, name = line:match("(%S+) +(%S+) +(%S+) +(%S+)")
        local expire

        ts = tonumber(ts)

        if ts > now then
            expire = ts - now
        elseif ts > 0 then
            expire = 0
        else
            expire = -1
        end

        leases[#leases + 1] = {
            ipaddr = addr,
            macaddr = mac,
            hostname = name,
            expire = expire
        }
    end

    return { leases = leases }
end

-- 验证IP是否重复（仅检查静态租约冲突）
function M.check_ip_conflict(params)
    local c = uci.cursor()
    local conflict = false
    local conflict_type = ''
    local conflict_name = ''
    
    -- 仅检查静态租约中的IP冲突
    c:foreach('dhcp', 'host', function(section)
        if section.ip == params.ip and section['.name'] ~= params.exclude_section then
            conflict = true
            conflict_type = 'static'
            conflict_name = section.name or section['.name']
            return false
        end
    end)
    
    return { 
        conflict = conflict, 
        type = conflict_type, 
        name = conflict_name 
    }
end

-- 添加静态DHCP租约
function M.add_static_lease(params)
    local c = uci.cursor()
    
    local section = c:add('dhcp', 'host')
    if params.hostname then
        c:set('dhcp', section, 'name', params.hostname)
    end
    if params.mac then
        c:set('dhcp', section, 'mac', params.mac)
    end
    if params.ip then
        c:set('dhcp', section, 'ip', params.ip)
    end
    
    c:commit('dhcp')
    
    return { success = true, section = section }
end

-- 删除静态DHCP租约
function M.delete_static_lease(params)
    local c = uci.cursor()
    
    if params.section then
        c:delete('dhcp', params.section)
        c:commit('dhcp')
    end
    
    return { success = true }
end

-- 更新静态DHCP租约
function M.update_static_lease(params)
    local c = uci.cursor()
    
    if params.section then
        if params.hostname then
            c:set('dhcp', params.section, 'name', params.hostname)
        end
        if params.mac then
            c:set('dhcp', params.section, 'mac', params.mac)
        end
        if params.ip then
            c:set('dhcp', params.section, 'ip', params.ip)
        end
        
        c:commit('dhcp')
    end
    
    return { success = true }
end

-- 重启网络服务
function M.restart_network()
    os.execute('/etc/init.d/network restart')
    os.execute('/etc/init.d/dnsmasq restart')
    return { success = true }
end

return M
