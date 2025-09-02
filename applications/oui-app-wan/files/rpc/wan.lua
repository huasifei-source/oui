local M = {}

local uci = require 'eco.uci'
local ubus = require 'eco.ubus'
local file = require 'eco.file'

-- 安全的文件读取函数
local function safe_read_file(path)
    if not file.access(path) then
        return nil
    end
    
    local f = io.open(path, 'r')
    if not f then
        return nil
    end
    
    local content = f:read('*a')
    f:close()
    
    return content and content:gsub('%s+$', '') or nil
end

-- 获取WAN接口名称
function M.get_wan_ifname()
    -- 首先尝试从UCI获取
    local c = uci.cursor()
    local ifname = c:get('network', 'wan', 'ifname')
    if ifname and ifname ~= '' then
        return ifname
    end
    
    -- 尝试从board.json获取
    local board_paths = {'/etc/board.json', '/etc/bcfg/board.json'}
    
    for _, board_file in ipairs(board_paths) do
        local content = safe_read_file(board_file)
        if content then
            local ok, cjson = pcall(require, 'cjson')
            if ok then
                local ok2, board_data = pcall(cjson.decode, content)
                if ok2 and board_data and board_data.network and board_data.network.wan then
                    if board_data.network.wan.ifname then
                        return board_data.network.wan.ifname
                    end
                    if board_data.network.wan.ports and #board_data.network.wan.ports > 0 then
                        return board_data.network.wan.ports[1]
                    end
                end
            end
        end
    end
    
    -- 默认返回eth0
    return 'eth1'
end

-- 获取WAN接口状态
function M.get_wan_status()
    local c = uci.cursor()
    if not c then
        return { error = 'Failed to access UCI' }
    end
    
    local wan_ifname = M.get_wan_ifname()
    
    -- 安全获取UCI配置
    local proto = c:get('network', 'wan', 'proto') or 'dhcp'
    local ipaddr = c:get('network', 'wan', 'ipaddr') or ''
    local netmask = c:get('network', 'wan', 'netmask') or ''
    local gateway = c:get('network', 'wan', 'gateway') or ''
    local dns = c:get('network', 'wan', 'dns') or ''
    local username = c:get('network', 'wan', 'username') or ''
    
    -- 获取IPv6配置
    local ipv6 = c:get('network', 'wan6', 'proto') and true or false
    local ipv6_proto = c:get('network', 'wan6', 'proto') or 'dhcpv6'
    local ipv6_addr = c:get('network', 'wan6', 'ip6addr') or ''
    local ipv6_prefix = c:get('network', 'wan6', 'ip6prefix') or '64'
    local ipv6_gateway = c:get('network', 'wan6', 'ip6gw') or ''
    local ipv6_dns = c:get('network', 'wan6', 'dns') or ''
    
    -- 安全获取接口状态
    local network_status = {}
    local device_status = {}
    
    local ok1, result1 = pcall(ubus.call, 'network.interface.wan', 'status', {})
    if ok1 and result1 then
        network_status = result1
    end
    
    local ok2, result2 = pcall(ubus.call, 'network.device', 'status', { name = wan_ifname })
    if ok2 and result2 then
        device_status = result2
    end
    
    -- 安全获取流量统计
    local stats = { rx_bytes = 0, tx_bytes = 0, rx_packets = 0, tx_packets = 0 }
    local stats_base = '/sys/class/net/' .. wan_ifname .. '/statistics/'
    
    local rx_bytes = safe_read_file(stats_base .. 'rx_bytes')
    local tx_bytes = safe_read_file(stats_base .. 'tx_bytes')
    local rx_packets = safe_read_file(stats_base .. 'rx_packets')
    local tx_packets = safe_read_file(stats_base .. 'tx_packets')
    
    if rx_bytes then stats.rx_bytes = tonumber(rx_bytes) or 0 end
    if tx_bytes then stats.tx_bytes = tonumber(tx_bytes) or 0 end
    if rx_packets then stats.rx_packets = tonumber(rx_packets) or 0 end
    if tx_packets then stats.tx_packets = tonumber(tx_packets) or 0 end
    
    return {
        config = {
            proto = proto,
            ipaddr = ipaddr,
            netmask = netmask,
            gateway = gateway,
            dns = dns,
            username = username,
            ipv6 = ipv6,
            ipv6_proto = ipv6_proto,
            ipv6_addr = ipv6_addr,
            ipv6_prefix = ipv6_prefix,
            ipv6_gateway = ipv6_gateway,
            ipv6_dns = ipv6_dns
        },
        status = {
            up = network_status.up or false,
            available = network_status.available or false,
            pending = network_status.pending or false,
            autostart = network_status.autostart or false,
            ipv4_address = network_status['ipv4-address'] or {},
            route = network_status.route or {},
            dns_server = network_status['dns-server'] or {},
            uptime = network_status.uptime or 0,
            device = {
                present = device_status.present or false,
                up = device_status.up or false,
                carrier = device_status.carrier or false,
                speed = device_status.speed or 0,
                duplex = device_status.duplex or false
            }
        },
        stats = stats,
        ifname = wan_ifname
    }
end

-- 设置WAN接口配置
function M.set_wan_config(params)
    if not params or type(params) ~= 'table' then
        return { error = 'Invalid parameters' }
    end
    
    if not params.proto then
        return { error = 'Protocol is required' }
    end
    
    local valid_protos = { dhcp = true, static = true, pppoe = true }
    if not valid_protos[params.proto] then
        return { error = 'Invalid protocol' }
    end
    
    local c = uci.cursor()
    if not c then
        return { error = 'Failed to access UCI' }
    end
    
    -- 设置协议
    c:set('network', 'wan', 'proto', params.proto)
    
    if params.proto == 'static' then
        -- 验证静态IP参数
        if params.ipaddr and not params.ipaddr:match('^%d+%.%d+%.%d+%.%d+$') then
            return { error = 'Invalid IP address format' }
        end
        if params.gateway and not params.gateway:match('^%d+%.%d+%.%d+%.%d+$') then
            return { error = 'Invalid gateway format' }
        end
        
        -- 静态IP配置
        if params.ipaddr then c:set('network', 'wan', 'ipaddr', params.ipaddr) end
        if params.netmask then c:set('network', 'wan', 'netmask', params.netmask) end
        if params.gateway then c:set('network', 'wan', 'gateway', params.gateway) end
        if params.dns then c:set('network', 'wan', 'dns', params.dns) end
        
        -- 清除其他协议配置
        c:delete('network', 'wan', 'username')
        c:delete('network', 'wan', 'password')
        
    elseif params.proto == 'dhcp' then
        -- DHCP配置，清除静态IP配置
        c:delete('network', 'wan', 'ipaddr')
        c:delete('network', 'wan', 'netmask')
        c:delete('network', 'wan', 'gateway')
        c:delete('network', 'wan', 'dns')
        c:delete('network', 'wan', 'username')
        c:delete('network', 'wan', 'password')
        
    elseif params.proto == 'pppoe' then
        -- 验证PPPoE参数
        if not params.username or params.username == '' then
            return { error = 'Username is required for PPPoE' }
        end
        if not params.password or params.password == '' then
            return { error = 'Password is required for PPPoE' }
        end
        
        -- PPPoE配置
        c:set('network', 'wan', 'username', params.username)
        c:set('network', 'wan', 'password', params.password)
        
        -- 清除静态IP配置
        c:delete('network', 'wan', 'ipaddr')
        c:delete('network', 'wan', 'netmask')
        c:delete('network', 'wan', 'gateway')
        c:delete('network', 'wan', 'dns')
    end
    
    -- IPv6配置处理
    if params.ipv6 ~= nil then
        if params.ipv6 then
            -- 启用IPv6
            local ipv6_proto = params.ipv6_proto or 'dhcpv6'
            local valid_ipv6_protos = { dhcpv6 = true, static = true, ['6in4'] = true, ['6to4'] = true }
            
            if valid_ipv6_protos[ipv6_proto] then
                -- 确保wan6接口存在
                c:set('network', 'wan6', 'interface')
                c:set('network', 'wan6', 'proto', ipv6_proto)
                c:set('network', 'wan6', 'ifname', '@wan')
                
                if ipv6_proto == 'static' then
                    -- 静态IPv6配置
                    if params.ipv6_addr then 
                        c:set('network', 'wan6', 'ip6addr', params.ipv6_addr .. '/' .. (params.ipv6_prefix or '64'))
                    end
                    if params.ipv6_gateway then 
                        c:set('network', 'wan6', 'ip6gw', params.ipv6_gateway) 
                    end
                    if params.ipv6_dns then 
                        c:set('network', 'wan6', 'dns', params.ipv6_dns) 
                    end
                else
                    -- 清除静态IPv6配置
                    c:delete('network', 'wan6', 'ip6addr')
                    c:delete('network', 'wan6', 'ip6gw')
                    c:delete('network', 'wan6', 'dns')
                end
            end
        else
            -- 禁用IPv6：删除wan6接口
            c:delete('network', 'wan6')
        end
    end
    
    local ok = c:commit('network')
    if not ok then
        return { error = 'Failed to save configuration' }
    end
    
    -- 安全重启网络接口
    pcall(ubus.call, 'network.interface.wan', 'down', {})
    pcall(ubus.call, 'network.interface.wan', 'up', {})
    
    -- 如果启用了IPv6，也重启wan6接口
    if params.ipv6 then
        pcall(ubus.call, 'network.interface.wan6', 'down', {})
        pcall(ubus.call, 'network.interface.wan6', 'up', {})
    end
    
    return { success = true }
end

-- 获取网络速度统计
function M.get_network_speed()
    local wan_ifname = M.get_wan_ifname()
    local stats_base = '/sys/class/net/' .. wan_ifname .. '/statistics/'
    
    local rx_bytes = safe_read_file(stats_base .. 'rx_bytes')
    local tx_bytes = safe_read_file(stats_base .. 'tx_bytes')
    
    if not rx_bytes or not tx_bytes then
        return { error = 'Interface statistics not available' }
    end
    
    local rx_num = tonumber(rx_bytes) or 0
    local tx_num = tonumber(tx_bytes) or 0
    
    return {
        rx_bytes = rx_num,
        tx_bytes = tx_num,
        timestamp = os.time()
    }
end

-- 安全的WAN连接控制
function M.wan_connect(params)
    if not params or not params.action then
        return { error = 'Action parameter is required' }
    end
    
    local valid_actions = { connect = true, disconnect = true }
    if not valid_actions[params.action] then
        return { error = 'Invalid action' }
    end
    
    local ok, result
    if params.action == 'connect' then
        ok, result = pcall(ubus.call, 'network.interface.wan', 'up', {})
    else
        ok, result = pcall(ubus.call, 'network.interface.wan', 'down', {})
    end
    
    if not ok then
        return { error = 'Failed to ' .. params.action .. ' WAN interface' }
    end
    
    return { success = true }
end

-- 获取可用的DNS服务器
function M.get_dns_servers()
    return {
        servers = {
            { name = 'Google DNS', primary = '8.8.8.8', secondary = '8.8.4.4' },
            { name = 'Cloudflare DNS', primary = '1.1.1.1', secondary = '1.0.0.1' },
            { name = '114 DNS', primary = '114.114.114.114', secondary = '114.114.115.115' },
            { name = 'Alibaba DNS', primary = '223.5.5.5', secondary = '223.6.6.6' }
        }
    }
end

return M
