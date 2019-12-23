-- https://wiki.cloudmodding.com/oot/Save_Format#Event_Flags
-- The trigger address has to be the actual start of the word
-- i.e. if a 4-byte word is written to address 0x0002, triggering off
-- writes to 0x0005 will do nothing.
-- I think this is mostly relevant in the writes that are patched in;
-- i.e. the writes in the base game tend to be 1 byte at a time.
CHECKS_MEM_BLOCKS = {
    chest = {addr = 0x1CA1D8, size = 4},
    collec = {addr = 0x1CA1E4, size = 4},
    misc_event_1 = {addr = 0x11B4A4, size = 4},
    misc_event_2 = {addr = 0x11B4A8, size = 4},
    misc_event_3 = {addr = 0x11B4AC, size = 4},
    -- songs1 = {addr = 0x11B4AE, size = 1},
    -- songs2 = {addr = 0x11B4AF, size = 1},
    misc_event_4 = {addr = 0x11B4B0, size = 4},
    misc_event_5 = {addr = 0x11B4B4, size = 4},
    songs3 = {addr = 0x11B4B8, size = 1},
    misc_event_6 = {addr = 0x11B4B9, size = 1},
    saria_bridge = {addr = 0x11B4BA, size = 4},
    skulltula_token_turnin_checks = {addr = 0x11B4BE, size = 1},
    frog_checks = {addr = 0x11B4BF, size = 1},
    -- not sure if it's lua's fault or Bizhawk's, but this implementation
    -- of lua interpreter doesn't deal well with numbers > 2^32 - 1
    npc_scrub1 = {addr = 0x11B4C0, size = 4},
    npc_scrub2 = {addr = 0x11B4C4, size = 4},
    link_the_goron = {addr = 0x11B4E8, size = 4},
    thaw_king_zora = {addr = 0x11B4EC, size = 4},
    nut_stick_richard_horsebackarchery = {addr = 0x11B4F8, size = 4},
}
scene_and_global_flags = {}

for name, mem in pairs(CHECKS_MEM_BLOCKS) do
    scene_and_global_flags[name] = 0
    event.onmemorywrite(read_mem_and_handle_next_frame(mem["addr"], mem["size"], name), 0x80000000 + mem["addr"])
end

INVENTORY_MEM_BLOCKS = {
    fire_arrow = {addr = 0x11A648, size = 1},
    dins_fire = {addr = 0x11A649, size = 1},
    ocarina = {addr = 0x11A64B, size = 1},
    bombchu = {addr = 0x11A64C, size = 1},
    hookshot = {addr = 0x11A64D, size = 1},
    farores_wind = {addr = 0x11A64F, size = 1},
    boomerang = {addr = 0x11A650, size = 1},
    lens = {addr = 0x11A651, size = 1},
    beans = {addr = 0x11A652, size = 1},
    hammer = {addr = 0x11A653, size = 1},
    light_arrow = {addr = 0x11A654, size = 1},
    nayrus_love = {addr = 0x11A655, size = 1},
    bottle1 = {addr = 0x11A656, size = 1},
    bottle2 = {addr = 0x11A657, size = 1},
    bottle3 = {addr = 0x11A658, size = 1},
    bottle4 = {addr = 0x11A659, size = 1},
    child_trade = {addr = 0x11A65A, size = 1},
    adult_trade = {addr = 0x11A65B, size = 1},
    boots_tunic_shield_sword = {addr = 0x11A66C, size = 2},
    -- the first byte of this 4-byte sequence is unused; the remaining three
    -- are updated at the same time, and twice in a row when a check is gotten
    -- the sequence is treated as a single word
    stick_nut_scale_wallet_bullet_quiver_bomb_str = {addr = 0x11A670, size = 4},
    quest_items = {addr = 0x11A674, size = 4},
}
inventory_state = {}

for name, mem in pairs(INVENTORY_MEM_BLOCKS) do
    inventory_state[name] = 0
    event.onmemorywrite(read_mem_and_handle_next_frame(mem["addr"], mem["size"], name), 0x80000000 + mem["addr"])
end

SCENE_ADDR = 0x1C8544

function resync()
    resync_checks_state()
    resync_inventory_state()
end

function resync_checks_state()
    resync_running_state_with_mem(scene_and_global_flags, CHECKS_MEM_BLOCKS)
end

function resync_checks_state()
    resync_running_state_with_mem(inventory_state, INVENTORY_MEM_BLOCKS)
end

function resync_running_state_with_mem(running_state, mem_blocks)
    for name, mem in pairs(mem_blocks) do
        local addr = mem["addr"]
        local size = mem["size"]
        local fixed_size_read_fn = SIZE_TO_READ_FN[size]
        if fixed_size_read_fn ~= nil then
            running_state[name] = fixed_size_read_fn(addr)
        else
            running_state[name] = read_range(size)(addr)
        end
    end
end

function execute_next_frame(fn, name)
    return function()
        function execute_then_unregister()
            fn()
            event.unregisterbyname(name)
        end
        event.onframeend(execute_then_unregister, name)
    end
end

function resync_next_frame()
    return execute_next_frame(resync, "resync")
end

function read_mem_and_handle(addr, size, name)
    return function()
        fixed_size_read_fn = SIZE_TO_READ_FN[size]
        if fixed_size_read_fn ~= nil then
            handle(name, fixed_size_read_fn(addr))
        else
            handle(name, read_range(size)(addr))
        end
    end
end

function read_mem_and_handle_next_frame(addr, size, name)
    return execute_next_frame(read_mem_and_handle(addr, size, name), name)
end

function is_opening_load_sequence()
    -- This first clause is only true right after the system powers on or restarts
    if mainmemory.read_u32_be(0x11A5EC) == 0 then
        return true
    end
    if boot_sequence > 0 then
        return true
    end
    return false
end

function handle(name, val)
    if is_opening_load_sequence() then
        return
    end

    if CHECKS_MEM_BLOCKS[name] ~= nil then
        update_flags(name, val)
    else
        scene_number = get_scene_number()
        if scene_number ~= 0x802c and scene_number ~= 0x8017 and scene_number ~= 0x8018 then
            prev_val = update_inventory(name, val)
            if prev_val ~= val then
                -- When learning the windmill song, the song/item get flag is written _before_
                -- the "learned song of storms" and "song played in windmill" flags.
                -- All other check logic works on the basis of storing the last flag
                -- set between chest flags, freestanding item (collectible) flags,
                -- song learned flags, and event item obtained (NPC and scrubs) flags.
                -- This clause looks to see if the player is in the windmill and playing ocarina
                -- when the check is obtained.
                if scene_number == 0x48 and mainmemory.read_u32_be(0x1D9008) == 0x6FE260 then
                    last_ck_ty = "misc_event_3"
                    last_ck_val = 0x800
                end
                print(string.format("%s\t%s\t%x -> %x\t%s\t%x\t%x", os.date("%Y-%m-%d %H:%M:%S", os.time()), name, prev_val, val, last_ck_ty, last_ck_val, get_scene_number()))
            end
        end
        --end
    end
end

function update_inventory(name, val)
    prev_val = inventory_state[name]
    inventory_state[name] = val
    return prev_val
end

function update_flags(name, val)
    local prev_val = scene_and_global_flags[name]
    local ck_val = val - prev_val
    last_ck_ty = name
    last_ck_val = ck_val
    scene_and_global_flags[name] = val
    print(string.format("Scene: %.02x\tCk type: %s\tCk val: %x", get_scene_number(), name, ck_val))
end

function get_scene_number()
    -- TODO: map addr to name
    return mainmemory.read_u16_be(0x1C8544)
end

function hexify(padding)
    return function(n) return string.format("%0" .. padding .. "x", tonumber(n)) end
end

-- for fuck's sake, when specifying a base (i.e. non-10),
-- tonumber is capped at 2^32 - 1
-- I think this is specific to the Bizhawk lua interpreter
-- oh, and using string.format to represent a number greater than 2^32 - 1
-- in hex just doesn't work
function read_range(size)
    local function read_n_range(addr)
        local bytes = one_index(mainmemory.readbyterange(addr, size))
        local hex_str_bytes = map(hexify(2), bytes)
        local hex_str_rep = table.concat(hex_str_bytes, "")
        -- local length = string.len(hex_str_rep)
        -- vals = {}
        -- i = 1
        -- while length > 8 do
        --     vals[i] = tonumber(string.sub(hex_str_rep, -8, -1), 16)
        --     hex_str_rep = string.sub(hex_str_rep, 1, -9)
        --     i = i + 1
        -- end
        -- vals[i] = tonumber(hex_str_rep, 16)

        -- local vals = tonumber()
        -- return vals
        return tonumber(hex_str_rep, 16)
    end
    return read_n_range
end

-- readbyterange returns a 0-indexed """array""" (table), which none of lua's builtin functions treat properly,
-- since it expects 1-indexing...
function one_index(array)
    local new_array = {}
    for i,v in pairs(array) do
        new_array[i+1] = v
    end
    return new_array
end

function map(func, array)
    local new_array = {}
    for i,v in ipairs(array) do
        new_array[i] = func(v)
    end
    return new_array
end

SIZE_TO_READ_FN = {
    [1] = mainmemory.read_u8,
    [2] = mainmemory.read_u16_be,
    [4] = mainmemory.read_u32_be
}

last_ck_ty = ""
last_ck_val = 0


boot_sequence = 3

-- this is just a random address I noticed was 0 during n64 scene and file select scene
-- if tracking randomly stops during the game, maybe this address being 0 is why
-- update: shit, it happens *after* the write to inventory
-- 11B91C
-- 11B920
-- 1CA0E0
-- 11A5D0: entrance idx
-- 11A5DC: world time
-- 11A5EC: static string for corruption test

-- 0x17CA48 u16: always val 5678 except at very start of execution
reboot_detect = function()
    if mainmemory.read_u16_be(0x17CA48) == 0 then
        boot_sequence = 1
        print("n64")
    end
end

file_select = function()
    if mainmemory.read_u32_be(0x11A5EC) == 0 and boot_sequence == 2 then
        boot_sequence = boot_sequence + 1
        print("file_select")
    end
end

handle_scene_setup_index = function()
    if mainmemory.read_u32_be(0x11B930) >= 4 and (boot_sequence == 1 or boot_sequence == 3) then
        boot_sequence = (boot_sequence + 1) % 4
        print("load in")
    end
end

event.onmemorywrite(read_mem_and_handle_next_frame(INVENTORY_ADDRS["stick_nut_scale_wallet_bullet_quiver_bomb_str"], 4, "stick_nut_scale_wallet_bullet_quiver_bomb_str"), INVENTORY_ADDRS["stick_nut_scale_wallet_bullet_quiver_bomb_str"] + 0x80000000)
event.onmemorywrite(read_mem_and_handle_next_frame(INVENTORY_ADDRS["hammer"], 1, "hammer"), INVENTORY_ADDRS["hammer"] + 0x80000000)
event.onmemorywrite(read_mem_and_handle_next_frame(INVENTORY_ADDRS["boomerang"], 1, "boomerang"), INVENTORY_ADDRS["boomerang"] + 0x80000000)
event.onmemorywrite(read_mem_and_handle_next_frame(INVENTORY_ADDRS["boots_tunic_shield_sword"], 2, "boots_tunic_shield_sword"), INVENTORY_ADDRS["boots_tunic_shield_sword"] + 0x80000000)
event.onmemorywrite(read_mem_and_handle_next_frame(INVENTORY_ADDRS["quest_items"], 3, "quest_items"), INVENTORY_ADDRS["quest_items"] + 0x80000000)

-- event.onmemorywrite(read_mem_and_handle_next_frame(0x1CA1D8, 4, "chest"), 0x801CA1D8)
-- event.onmemorywrite(read_mem_and_handle_next_frame(0x1CA1E4, 4, "collec"), 0x801CA1E4)
-- event.onmemorywrite(read_mem_and_handle_next_frame(0x11BC2E, 1, "songs1"), 0x8011BC2E)
-- event.onmemorywrite(read_mem_and_handle_next_frame(0x11BC2F, 1, "songs2"), 0x8011BC2F)
-- event.onmemorywrite(read_mem_and_handle_next_frame(0x11BC38, 1, "songs3"), 0x8011BC38)
-- the +1 here means the trigger doesn't depend on the first byte, which holds no useful information

event.onmemorywrite(reboot_detect, 0x8017CA48)
event.onmemorywrite(file_select, 0x8011A5EC)
event.onmemorywrite(handle_scene_setup_index, 0x8011B930)

event.onmemorywrite(resync_next_frame(), SCENE_ADDR + 0x80000000)
-- event.onmemorywrite(function() scene_changing = true end, 0x801C8544)
-- event.onmemorywrite(function() scene_changing = false end, 0x801DA298)
-- dive: +0x02 per upgrade
-- wallet: +0x10 per upgrade
-- bullet: +0x40 per upgrade
