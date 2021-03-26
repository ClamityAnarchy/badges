-- badges/init.lua

badges = {}

local registered   = {}
local default

---
--- API
---

-- [local function] Get colour
local function get_colour(colour)
	if type(colour) == "table" and minetest.rgba then
		return minetest.rgba(colour.r, colour.g, colour.b, colour.a)
	elseif type(colour) == "string" then
		return colour
	else
		return "#ffffff"
	end
end

-- [function] Register badge
function badges.register(name, def)
	assert(name ~= "clear", "Invalid name \"clear\" for badge")

	registered[name] = def

	if def.default then
		default = name
	end
end

-- [function] Unregister badge
function badges.unregister(name)
	registered[name] = nil
end

-- [function] List badges in plain text
function badges.list_plaintext()
	local list = ""
	for badge, i in pairs(registered) do
		if list == "" then
			list = badge
		else
			list = list..", "..badge
		end
	end
	return list
end

-- [function] Get player badge
function badges.get_badge(player)
	if type(player) == "string" then
		player = minetest.get_player_by_name(player)
	end

	local badge = player:get_attribute("badges:badge")
	if badge and registered[badge] then
		return badge
	end
end

-- [function] Get badge definition
function badges.get_def(badge)
	if not badge then
		return
	end

	return registered[badge]
end

-- [function] Update player privileges
function badges.update_privs(player, trigger)
	if type(player) == "string" then
		player = minetest.get_player_by_name(player)
	end

	if not player then
		return
	end

	local name = player:get_player_name()
	local badge = badges.get_badge(player)
	if badge then
		-- [local function] Warn
		local function warn(msg)
			if msg and trigger and minetest.get_player_by_name(trigger) then
				minetest.chat_send_player(trigger, minetest.colorize("red", "Warning: ")..msg)
			end
		end

		local def   = registered[badge]
		if not def.privs then
			return
		end

		if def.strict_privs == true then
			minetest.set_player_privs(name, def.privs)
			warn(name.."'s privileges have been reset to that of their badge (strict privileges)")
			return true
		end

		local privs = minetest.get_player_privs(name)

		if def.grant_missing == true then
			local changed = false
			for name, priv in pairs(def.privs) do
				if not privs[name] and priv == true then
					privs[name] = priv
					changed = true
				end
			end

			if changed then
				warn("Missing badge privileges have been granted to "..name)
			end
		end

		if def.revoke_extra == true then
			local changed = false
			for name, priv in pairs(privs) do
				if not def.privs[name] then
					privs[name] = nil
					changed = true
				end
			end

			if changed then
				warn("Extra non-badge privileges have been revoked from "..name)
			end
		end

		local admin = player:get_player_name() == minetest.settings:get("name")
		-- If owner, grant `badge` privilege
		if admin then
			local name = player:get_player_name()
			local privs = minetest.get_player_privs(name)
			privs["badge"] = true
			minetest.set_player_privs(name, privs)
		end

		minetest.set_player_privs(name, privs)
		return true
	end
end

-- [function] Set player badge
function badges.set_badge(player, badge)
	if type(player) == "string" then
		player = minetest.get_player_by_name(player)
	end

	if registered[badge] then
		-- Set attribute
		player:set_attribute("badges:badge", badge)
		-- Update privileges
		badges.update_privs(player)

		return true
	end
end

-- [function] Remove badge from player
function badges.remove_badge(player)
	if type(player) == "string" then
		player = minetest.get_player_by_name(player)
	end

	local badge = badges.get_badge(player)
	if badge then
		local name = player:get_player_name()

		-- Clear attribute
		player:set_attribute("badges:badge", nil)
		-- Update privileges
		local basic_privs =
			minetest.string_to_privs(minetest.settings:get("basic_privs") or "interact,shout")
		minetest.set_player_privs(name, basic_privs)
	end
end

-- [function] Send prefixed message (if enabled)
function badges.chat_send(name, message)
	if minetest.settings:get("badges.prefix_chat") ~= "false" then
		local badge = badges.get_badge(name)
		if badge then
			local def = badges.get_def(badge)
			if def.prefix then
				local colour = get_colour(def.colour)
				local prefix = minetest.colorize(colour, def.prefix)
				discord.chat_send_all(prefix.." <"..name..">: "..message)
				return true
			end
		end
		discord.chat_send_all("<"..name..">: "..message)
		return true
	end
end

---
--- Registrations
---

-- [privilege] badge
minetest.register_privilege("badge", {
	description = "Permission to use /badge chatcommand",
	give_to_singleplayer = false,
})

-- Assign/update badge on join player
minetest.register_on_joinplayer(function(player)
	if badges.get_badge(player) then
		-- Update privileges
		badges.update_privs(player)
	else
		if badges.default then
			badges.set_badge(player, badges.default)
		end
	end
end)

-- Prefix messages if enabled
minetest.register_on_chat_message(function(name, message)
	return badges.chat_send(name, message)
end)

-- [chatcommand] /badge
minetest.register_chatcommand("badge", {
	description = "Set a player's badge",
	params = "<player> <new badge> / \"list\" | username, badgename / list badges",
	privs = {badge = true},
	func = function(name, param)
		local param = param:split(" ")
		if #param == 0 then
			return false, "Invalid usage (see /help badge)"
		end

		if #param == 1 and param[1] == "list" then
			return true, "Available badges: "..badges.list_plaintext()
		elseif #param == 2 then
			if minetest.get_player_by_name(param[1]) then
				if badges.get_def(param[2]) then
					if badges.set_badge(param[1], param[2]) then
						if name ~= param[1] then
							minetest.chat_send_player(param[1], name.." set your badge to "..param[2])
						end

						return true, "Set "..param[1].."'s badge to "..param[2]
					else
						return false, "Unknown error while setting "..param[1].."'s badge to "..param[2]
					end
				elseif param[2] == "clear" then
					badges.remove_badge(param[1])
					return true, "Removed badge from "..param[1]
				else
					return false, "Invalid badge (see /badge list)"
				end
			else
				return false, "Invalid player \""..param[1].."\""
			end
		else
			return false, "Invalid usage (see /help badge)"
		end
	end,
})

-- [chatcommand] /getbadge
minetest.register_chatcommand("getbadge", {
	description = "Get a player's badge. If no player is specified, your own badge is returned.",
	params = "<name> | name of player",
	func = function(name, param)
		if param and param ~= "" then
			if minetest.get_player_by_name(param) then
				local badge = badges.get_badge(param) or "No badge"
				return true, "badge of "..param..": "..badge
			else
				return false, "Invalid player \""..name.."\""
			end
		else
			local badge = badges.get_badge(name) or "No badge"
			return false, "Your badge: "..badge
		end
	end,
})

---
--- Overrides
---

local grant = minetest.registered_chatcommands["grant"].func
-- [override] /grant
minetest.registered_chatcommands["grant"].func = function(name, param)
	local ok, msg = grant(name, param) -- Call original function

	local grantname, grantprivstr = string.match(param, "([^ ]+) (.+)")
	if grantname then
		badges.update_privs(grantname, name) -- Update privileges
	end

	return ok, msg
end

local grantme = minetest.registered_chatcommands["grantme"].func
-- [override] /grantme
minetest.registered_chatcommands["grantme"].func = function(name, param)
	local ok, msg = grantme(name, param) -- Call original function
	badges.update_privs(name, name) -- Update privileges
	return ok, msg
end

local revoke = minetest.registered_chatcommands["revoke"].func
-- [override] /revoke
minetest.registered_chatcommands["revoke"].func = function(name, param)
	local ok, msg = revoke(name, param) -- Call original function

	local revokename, revokeprivstr = string.match(param, "([^ ]+) (.+)")
	if revokename then
		badges.update_privs(revokename, name) -- Update privileges
	end

	return ok, msg
end

---
--- badges
---

-- Load default badges
dofile(minetest.get_modpath("badges").."/badges.lua")

local path = minetest.get_worldpath().."/badges.lua"
-- Attempt to load per-world badges
if io.open(path) then
	dofile(path)
end
