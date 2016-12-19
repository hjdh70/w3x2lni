local w3xparser = require 'w3xparser'

local table_concat = table.concat
local ipairs = ipairs
local string_char = string.char
local pairs = pairs
local type = type
local table_sort = table.sort
local table_insert = table.insert
local math_floor = math.floor
local wtonumber = w3xparser.tonumber
local math_type = math.type

local slk
local w2l
local metadata
local keydata
local keys
local lines
local cx
local cy

local extra_key = {
    ['units\\abilitydata.slk']      = 'alias',
    ['units\\abilitybuffdata.slk']  = 'alias',
    ['units\\destructabledata.slk'] = 'DestructableID',
    ['units\\itemdata.slk']         = 'itemID',
    ['units\\upgradedata.slk']      = 'upgradeid',
    ['units\\unitabilities.slk']    = 'unitAbilID',
    ['units\\unitbalance.slk']      = 'unitBalanceID',
    ['units\\unitdata.slk']         = 'unitID',
    ['units\\unitui.slk']           = 'unitUIID',
    ['units\\unitweapons.slk']      = 'unitWeapID',
    ['doodads\\doodads.slk']        = 'doodID',
}

local function add_end()
    lines[#lines+1] = 'E'
end

local function add(x, y, k)
    local strs = {}
    strs[#strs+1] = 'C'
    if x ~= cx then
        cx = x
        strs[#strs+1] = 'X' .. x
    end
    if y ~= cy then
        cy = y
        strs[#strs+1] = 'Y' .. y
    end
    if type(k) == 'string' then
        k = '"' .. k .. '"'
    elseif math_type(k) == 'float' then
        k = ('%.4f'):format(k):gsub('[0]+$', ''):gsub('%.$', '.0')
    end
    strs[#strs+1] = 'K' .. k
    lines[#lines+1] = table_concat(strs, ';')
end

local function add_values(names, skeys)
    for y, name in ipairs(names) do
        local obj = slk[name]
        for x, key in ipairs(skeys) do
            local value = obj[key]
            if value then
                add(x, y+1, value)
            end
        end
    end
end

local function add_title(names)
    for x, name in ipairs(names) do
        add(x, 1, name)
    end
end

local function add_head(names, skeys)
    lines[#lines+1] = 'ID;PWXL;N;E'
    lines[#lines+1] = ('B;X%d;Y%d;D0'):format(#skeys, #names+1)
end

local function get_key(id)
	local meta  = metadata[id]
	if not meta then
		return
	end
	local key  = meta.field
	local num   = meta.data
	if num and num ~= 0 then
		key = key .. string_char(('A'):byte() + num - 1)
	end
	if meta._has_index then
		key = key .. ':' .. (meta.index + 1)
	end
	return key
end

local function get_keys(slk_name)
    local skeys = {}
    for _, id in pairs(keys) do
        local key = get_key(id)
        if not (slk_name == 'units\\unitui.slk' and (key == 'campaign' or key == 'dropItems'  or key == 'inEditor' or key == 'special' or key == 'hostilePal' or key == 'useClickHelper')) 
            and not (slk_name == 'units\\itemdata.slk' and key == 'selSize')
            and not (slk_name == 'units\\upgradedata.slk' and key == 'race')
            and not (slk_name == 'units\\destructabledata.slk' and (key == 'EditorSuffix' or key == 'canPlaceRandScale' or key == 'category' or key == 'onCliffs' or key == 'onWater' or key == 'tilesets' or key == 'UserList' or key == 'buildTime' or key == 'goldRep' or key == 'lumberRep' or key == 'repairTime' or key == 'canPlaceDead' or key == 'selSize' or key == 'useClickHelper'))
            and not (slk_name == 'units\\abilitybuffdata.slk' and (key == 'isEffect' or key == 'race'))
            and not (slk_name == 'units\\abilitydata.slk' and (key == 'hero' or key == 'item' or key == 'race'))
        then
            local meta = metadata[id]
            if meta['repeat'] and meta['repeat'] > 0 then
                for i = 1, 4 do
                    skeys[#skeys+1] = key .. i
                end
            else
                skeys[#skeys+1] = key
            end
        end
    end
    if slk_name == 'units\\abilitydata.slk' then
        for i = 1, 4 do
            skeys[#skeys+1] = 'DataA' .. i
            skeys[#skeys+1] = 'DataB' .. i
            skeys[#skeys+1] = 'DataC' .. i
            skeys[#skeys+1] = 'DataD' .. i
            skeys[#skeys+1] = 'DataE' .. i
            skeys[#skeys+1] = 'DataF' .. i
            skeys[#skeys+1] = 'DataG' .. i
            skeys[#skeys+1] = 'DataH' .. i
            skeys[#skeys+1] = 'DataI' .. i
            skeys[#skeys+1] = 'UnitID' .. i
        end
    end
    table_sort(skeys)
    table_insert(skeys, 1, extra_key[slk_name])
    if slk_name == 'units\\abilitydata.slk' then
        table_insert(skeys, 2, 'code')
    end
    if slk_name == 'units\\unitui.slk' then
        table_insert(skeys, 2, 'name')
    end
    return skeys
end

local function get_names()
    local names = {}
    for name in pairs(slk) do
        names[#names+1] = name
    end
    table_sort(names, function(a, b)
        return slk[a]['_id'] < slk[b]['_id']
    end)
    return names
end

local function convert_slk(slk_name)
    if not next(slk) then
        return
    end
    local names = get_names()
    local skeys = get_keys(slk_name)
    add_head(names, skeys)
    add_title(skeys)
    add_values(names, skeys)
    add_end()
end

local function key2id(name, code, key)
    name = name:lower()
    code = code:lower()
    key = key:lower()
    local id = code and keydata[code] and keydata[code][key] or keydata[name] and keydata[name][key] or keydata['common'][key]
    if id then
        return id
    end
    return nil
end

local function to_type(tp, value)
    if tp == 0 then
        if not value or value == 0 then
            return nil
        end
        return math_floor(wtonumber(value))
    elseif tp == 1 or tp == 2 then
        if not value or value == 0 then
            return nil
        end
        return wtonumber(value) + 0.0
    elseif tp == 3 then
        if not value then
            return nil
        end
        if value == '' then
            return nil
        end
        value = tostring(value)
        if not value:match '[^ %-%_]' then
            return nil
        end
        if value:match '^%.[mM][dD][lLxX]$' then
            return nil
        end
        return value
    end
end

local function load_data(name, code, obj, key, id, slk_data)
    if not obj[key] then
        return
    end
    local tp = w2l:get_id_type(metadata[id].type)
    local skey = get_key(key2id(name, code, key))
    if type(obj[key]) == 'table' then
        for i = 1, 4 do
            slk_data[skey..i] = to_type(tp, obj[key][i])
            obj[key][i] = nil
        end
    else
        slk_data[skey] = to_type(tp, obj[key])
        obj[key] = nil
    end
end

local function load_obj(name, obj, slk_name)
    local code = obj._lower_code
    local slk_data = {}
    slk_data[extra_key[slk_name]] = obj['_id']
    slk_data['code'] = obj.code
    slk_data['name'] = obj._name
    slk_data['_id'] = obj._id
    for key, id in pairs(keys) do
        load_data(name, code, obj, key, id, slk_data)
    end
    if keydata[code] then
        for key, id in pairs(keydata[code]) do
            load_data(name, code, obj, key, id, slk_data)
        end
    end
    return slk_data
end

local function load_chunk(chunk, slk_name)
    for name, obj in pairs(chunk) do
        slk[name] = load_obj(name, obj, slk_name)
    end
end

return function(w2l_, type, slk_name, chunk)
    slk = {}
    w2l = w2l_
    cx = nil
    cy = nil
    lines = {}
    metadata = w2l:read_metadata(type)
    keydata = w2l:keyconvert(type)
    keys = keydata[slk_name]

    load_chunk(chunk, slk_name)
    convert_slk(slk_name)
    return table_concat(lines, '\r\n')
end
