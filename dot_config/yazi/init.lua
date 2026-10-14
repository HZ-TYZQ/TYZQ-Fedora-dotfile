-- Enter a directory when it is left-clicked twice within 0.45 seconds.
-- File opening, right-click actions, and directory shortcuts are intentionally
-- left at Yazi's defaults.
do
    local last_url = nil
    local last_time = 0
    local threshold = 0.45

    function Entity:click(event, up)
        if up or event.is_middle then
            return
        end

        ya.emit("reveal", { self._file.url })

        -- Preserve Yazi's default right-click behavior.
        if event.is_right then
            ya.emit("open", {})
            return
        end

        if not event.is_left then
            return
        end

        local now = ya.time()
        local url = tostring(self._file.url)

        if self._file.cha.is_dir and url == last_url and now - last_time <= threshold then
            last_url = nil
            last_time = 0
            ya.emit("enter", { hovered = true })
            return
        end

        last_url = url
        last_time = now
    end
end

-- Sync yanked files with the system clipboard (Dolphin / Nautilus interop)
require("fedora-clipboard"):setup()
