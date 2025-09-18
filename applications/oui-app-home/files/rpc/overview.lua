local M = {}

local ubus = require 'eco.ubus'

-- helper: read file lines into a table
local function read_lines(path)
    local f = io.open(path, 'r')
    if not f then return nil end
    local lines = {}
    for line in f:lines() do
        lines[#lines + 1] = line
    end
    f:close()
    return lines
end

-- 获取CPU使用率
local function get_cpu_usage()
    local cpu_info = {}
    local stat_file = io.open('/proc/stat', 'r')
    if stat_file then
        local line = stat_file:read('*line')
        stat_file:close()
        
        local fields = {}
        for field in line:gmatch('%S+') do
            table.insert(fields, field)
        end
        
        if #fields >= 8 then
            local user = tonumber(fields[2]) or 0
            local nice = tonumber(fields[3]) or 0
            local system = tonumber(fields[4]) or 0
            local idle = tonumber(fields[5]) or 0
            local iowait = tonumber(fields[6]) or 0
            local irq = tonumber(fields[7]) or 0
            local softirq = tonumber(fields[8]) or 0
            
            local total = user + nice + system + idle + iowait + irq + softirq
            local active = total - idle - iowait
            
            cpu_info = {
                user = user,
                nice = nice,
                system = system,
                idle = idle,
                iowait = iowait,
                irq = irq,
                softirq = softirq,
                total = total,
                active = active,
                usage_percent = total > 0 and math.floor((active / total) * 100) or 0
            }
        end
    end
    return cpu_info
end

-- 获取系统信息
function M.get_system_info()
    local result = {}
    
    -- 获取系统信息
    local system_info = ubus.call('system', 'info', {})
    local board_info = ubus.call('system', 'board', {})
    if system_info then
        result.system = {
            hostname = board_info.hostname or 'Unknown',
            model = board_info.model or 'Unknown',
            board_name = board_info.board_name or 'Unknown',
            kernel = board_info.kernel or 'Unknown',
            uptime = system_info.uptime or 0,
            load = system_info.load or {},
            memory = system_info.memory or {}
        }
        
        -- 计算内存使用率
        if result.system.memory.total and result.system.memory.free then
            local total = result.system.memory.total
            local free = result.system.memory.free
            local available = result.system.memory.available or free
            local used = total - available
            result.system.memory.used = used
            result.system.memory.usage_percent = total > 0 and math.floor((used / total) * 100) or 0
        end
    end
    
    -- 获取board信息
    local board_info = ubus.call('system', 'board', {})
    if board_info then
        result.board = {
            hostname = board_info.hostname or 'Unknown',
            model = board_info.model or 'Unknown',
            board_name = board_info.board_name or 'Unknown',
            release = board_info.release or {}
        }
    end
    
    -- 获取CPU信息
    result.cpu = get_cpu_usage()
    
    return result
end

-- 获取网络接口信息
function M.get_network_info()
    local result = {}
    
    -- 获取网络接口状态
    local interfaces = ubus.call('network.interface', 'dump', {})
    if interfaces and interfaces.interface then
        result.interfaces = {}
        result.wan_interfaces = {}
        result.lan_interfaces = {}
        result.default_gateway = nil
        
        for _, iface in ipairs(interfaces.interface) do
            local interface_info = {
                name = iface.interface,
                up = iface.up or false,
                proto = iface.proto or 'unknown',
                device = iface.device or iface.l3_device or '',
                ipv4_addresses = iface['ipv4-address'] or {},
                ipv6_addresses = iface['ipv6-address'] or {},
                route = iface.route or {},
                uptime = iface.uptime or 0,
                dns_servers = iface['dns-server'] or {}
            }
            
            -- 查找默认网关
            if iface.route then
                for _, route in ipairs(iface.route) do
                    if route.target == '0.0.0.0' and route.mask == 0 then
                        result.default_gateway = {
                            interface = iface.interface,
                            gateway = route.nexthop,
                            metric = route.metric or 0
                        }
                    end
                end
            end
            
            result.interfaces[iface.interface] = interface_info
            
            -- 分类WAN和LAN接口
            if iface.interface == 'wan' or iface.interface == 'repeater' or string.match(iface.interface, '^wan') then
                table.insert(result.wan_interfaces, interface_info)
            elseif iface.interface ~= 'loopback' then
                table.insert(result.lan_interfaces, interface_info)
            end
        end
    end
    
    return result
end

-- 获取无线网络信息
function M.get_wireless_info()
    local result = {}
    
    -- 获取无线状态
    local wireless_status = ubus.call('network.wireless', 'status', {})
    if wireless_status then
        result.radios = {}
        result.interfaces = {}
        
        for radio_name, radio_data in pairs(wireless_status) do
            local radio_info = {
                name = radio_name,
                up = radio_data.up or false,
                band = radio_data.config and radio_data.config.band or '',
                channel = radio_data.config and radio_data.config.channel or '',
                htmode = radio_data.config and radio_data.config.htmode or '',
                interfaces = {}
            }
            
            if radio_data.interfaces then
                for _, iface in ipairs(radio_data.interfaces) do
                    local iface_info = {
                        section = iface.section,
                        ifname = iface.ifname,
                        ssid = iface.config and iface.config.ssid or '',
                        mode = iface.config and iface.config.mode or '',
                        encryption = iface.config and iface.config.encryption or 'none'
                    }
                    table.insert(radio_info.interfaces, iface_info)
                    result.interfaces[iface.ifname] = iface_info
                end
            end
            
            result.radios[radio_name] = radio_info
        end
    end
    
    return result
end

-- 获取已连接的设备信息
function M.get_connected_devices()
    -- 仅返回原始来源：ARP、DHCP 租约（解析为 JSON）、iwinfo 关联列表
    local result = {
        arp = {},
        dhcp_leases = {},
        wireless_assoc = {}
    }

    -- 读取 ARP 表，解析为 JSON 数组
    local arp_lines = read_lines('/proc/net/arp')
    if arp_lines then
        for idx, line in ipairs(arp_lines) do
            -- 跳过首行表头
            if idx > 1 then
                -- 更宽松的匹配，允许任意非空白字段（包括'*'）
                local ip, hw_type, flags, hw_addr, mask, device = line:match('^(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s*$')
                if ip and hw_addr and hw_addr ~= '00:00:00:00:00:00' then
                    table.insert(result.arp, {
                        ip = ip,
                        mac = hw_addr,
                        device = device,
                        flags = flags,
                        hw_type = hw_type,
                        mask = mask
                    })
                end
            end
        end
    end

    -- 读取 DHCP 租约，解析为 JSON 数组
    local lease_lines = read_lines('/tmp/dhcp.leases')
    if lease_lines then
        for _, line in ipairs(lease_lines) do
            local timestamp, mac, ip, hostname, client_id = line:match('(%d+)%s+([%w:]+)%s+([%d%.]+)%s+([^%s]*)%s*(.*)')
            if mac and ip then
                table.insert(result.dhcp_leases, {
                    timestamp = tonumber(timestamp) or 0,
                    mac = mac,
                    ip = ip,
                    hostname = (hostname and hostname ~= '*' and hostname or ''),
                    client_id = client_id or ''
                })
            end
        end
    end

    -- 收集 iwinfo 关联表，按接口名分组
    local wireless_info = M.get_wireless_info()
    if wireless_info.interfaces then
        for ifname, iface in pairs(wireless_info.interfaces) do
            if iface.mode == 'ap' then
                local assoc_result = ubus.call('iwinfo', 'assoclist', { device = ifname })
                result.wireless_assoc[ifname] = (assoc_result and assoc_result.results) or {}
            end
        end
    end

    return result
end

-- 获取完整的overview信息
function M.get_overview()
    local result = {}
    
    -- 获取系统信息
    result.system = M.get_system_info()
    
    -- 获取网络信息
    result.network = M.get_network_info()
    
    -- 获取无线信息
    result.wireless = M.get_wireless_info()
    
    -- 获取连接设备
    result.devices = M.get_connected_devices()
    
    return result
end

return M
