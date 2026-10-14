--- @sync entry

return {
	entry = function()
		local h = cx.active.current.hovered
		if not h then
			return
		end

		if h.cha.is_dir then
			ya.emit("enter", {})
		else
			ya.emit("shell", { "xdg-open %h", orphan = true })
		end
	end,
}
