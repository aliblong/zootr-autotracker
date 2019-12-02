-- function register_self_deleting_capture_fn()
    -- local fn_name = "testfn"
    -- function delete_self()
        -- print(mainmemory.read_u32_be(0x1CA1D8))
        -- event.unregisterbyname(fn_name)
    -- end
    -- event.onframeend(delete_self, fn_name)
-- end

-- event.onmemorywrite(register_self_deleting_capture_fn, 0x801CA1D8)
scene_changing = false
SCENE_CHANGE_END_ADDR = 0x1DA298

function register_handler(addr, size, name)
    return function()
        function handle_event_once()
            -- local val
            -- if size == 1 then val = mainmemory.read_u8(addr)
            -- elseif size == 2 then val = mainmemory.read_u16_be(addr)
            -- else val = mainmemory.read_u32_be(addr)
            -- end
            handle_event(name, SIZE_TO_READ_FN[size](addr))
            event.unregisterbyname(name)
        end
        event.onframeend(handle_event_once, name)
    end
end

function handle_event(name, val)
    if mainmemory.read_u32_be(0x11A5EC) == 0 then --or mainmemory.read_u32_be(0x11B91C) == 0 then
        return
    end
    if boot_sequence > 0 then
        return
    end
    if name == "chest" or name == "collec" then
        update_flags(name, val)
    else
        if not scene_changing then --and not in_cutscene
            scene_number = get_scene_number()
            -- 0x802c is val for title cutscene briefly
            if scene_number ~= 0x802c and scene_number ~= 0x8017 and scene_number ~= 0x8018 then
                prev_val = update_inventory(name, val)
                print(string.format("%s\t%s\t%x -> %x\t%s\t%x\t%x", os.date("%Y-%m-%d %H:%M:%S", os.time()), name, prev_val, val, last_ck_ty, last_ck_val, get_scene_number()))
            end
        end
    end
end

function update_inventory(name, val)
    prev_val = inventory[name]
    inventory[name] = val
    return prev_val
end

function update_flags(name, val)
    prev_val = scene_flags[name]
    ck_val = val - prev_val
    last_ck_ty = name
    last_ck_val = ck_val
    scene_flags[name] = val
end

function get_scene_number()
    -- TODO: map addr to name
    return mainmemory.read_u16_be(0x1C8544)
end

SIZE_TO_READ_FN = {
    [1] = mainmemory.read_u8,
    [2] = mainmemory.read_u16_be,
    [4] = mainmemory.read_u32_be
}

INVENTORY_ADDRS = {
    boomerang = 0x11A650,
    hammer = 0x11A653,
    boots_tunic_shield_sword = 0x11A66C,
    -- the first byte of this 4-byte sequence is unused; the remaining three
    -- are updated at the same time, and twice in a row when a check is gotten
    -- the sequence is treated as a single word
    stick_nut_scale_wallet_bullet_quiver_bomb_str = 0x11A670
}

last_ck_ty = ""
last_ck_val = 0

scene_flags = {
    chest = 0,
    collec = 0
}

inventory = {
    boomerang = 0,
    hammer = 0,
    boots_tunic_shield_sword = 0,
    stick_nut_scale_wallet_bullet_quiver_bomb_str = 0
}


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


event.onmemorywrite(register_handler(0x1CA1D8, 4, "chest"), 0x801CA1D8)
event.onmemorywrite(register_handler(0x1CA1E4, 4, "collec"), 0x801CA1E4)
-- the +1 here means the trigger doesn't depend on the first byte, which holds no useful information
event.onmemorywrite(register_handler(INVENTORY_ADDRS["stick_nut_scale_wallet_bullet_quiver_bomb_str"], 4, "stick_nut_scale_wallet_bullet_quiver_bomb_str"), INVENTORY_ADDRS["stick_nut_scale_wallet_bullet_quiver_bomb_str"] + 0x80000000)
event.onmemorywrite(register_handler(INVENTORY_ADDRS["hammer"], 1, "hammer"), INVENTORY_ADDRS["hammer"] + 0x80000000)
event.onmemorywrite(register_handler(INVENTORY_ADDRS["boomerang"], 1, "boomerang"), INVENTORY_ADDRS["boomerang"] + 0x80000000)
event.onmemorywrite(register_handler(INVENTORY_ADDRS["boots_tunic_shield_sword"], 2, "boots_tunic_shield_sword"), INVENTORY_ADDRS["boots_tunic_shield_sword"] + 0x80000000)
event.onmemorywrite(reboot_detect, 0x8017CA48)
event.onmemorywrite(file_select, 0x8011A5EC)
event.onmemorywrite(handle_scene_setup_index, 0x8011B930)
-- event.onmemorywrite(function() scene_changing = true end, 0x801C8544)
-- event.onmemorywrite(function() scene_changing = false end, 0x801DA298)
-- dive: +0x02 per upgrade
-- wallet: +0x10 per upgrade
-- bullet: +0x40 per upgrade
