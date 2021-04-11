minetest.register_globalstep(function()
	for _, player in pairs(minetest.get_connected_players()) do
		local meta = player:get_meta()
		if meta:get_string("badges:bossbar") == "true" then
			local color = meta:get_string("badges:bossbar_color")
			if color == "" then
				color = "white"
			end
			mcl_bossbars.update_boss(player, player:get_player_name(), color)
		end
	end
end)

minetest.register_chatcommand("custombossbar", {
	description = "Configure or toggle your custom bossbar",
	params = "on | off | color <color>",
	func = function(name, param)
		local player = minetest.get_player_by_name(name)
		if not player then
			return false, C(mcl_colors.RED) .."You need to be online to use this command"
		end
		if not badges.get_badge(player) then
			return false, C(mcl_colors.RED) .. "This command is only available to people with badges"
		end
		local meta = player:get_meta()
		local C = minetest.get_color_escape_sequence
		if param == "on" then
			meta:set_string("badges:bossbar", "true")
			return true, C(mcl_colors.GRAY) .. "Your custom bossbar was " .. C(mcl_colors.GREEN) .. "enabled" .. C(mcl_colors.GRAY) .. "."
		elseif param == "off" then
			meta:set_string("badges:bossbar", "")
			return true, C(mcl_colors.GRAY) .. "Your custom bossbar was " .. C(mcl_colors.YELLOW) .. "disabled" .. C(mcl_colors.GRAY) .. "."
		elseif param:find("color ") == 1 then
			local colorstr = param:sub(7, #param):lower()
			local color = mcl_util.get_color(colorstr)
			if color then
				if table.indexof(mcl_bossbars.colors, colorstr) == -1 then
					return false, C(mcl_colors.RED) .. "Bossbars don't support this color: " .. colorstr .. ". Available colors: " .. table.concat(mcl_bossbars.colors, ", ") .. "."
				else
					meta:set_string("badges:bossbar_color", colorstr)
					return true, C(mcl_colors.GRAY) .. "The color of your custom bossbar was set to " .. C(color) .. colorstr .. C(mcl_colors.GRAY) .. "."
				end
			else
				return false, C(mcl_colors.RED) .. "Invalid color: " .. colorstr .. ". Available colors: " .. table.concat(mcl_bossbars.colors, ", ") .. "."
			end
		else
			return false, C(mcl_colors.RED) .. "Invalid usage (See /help custombossbar)."
		end
	end,
})
