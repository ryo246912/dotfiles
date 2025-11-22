function Linemode:custom()
	local btime = math.floor(self._file.cha.btime or 0)
	if btime == 0 then
		btime = ""
	elseif os.date("%Y", btime) == os.date("%Y") then
		btime = os.date("%m/%d %H:%M", btime)
	else
		btime = os.date("%y/%m/%d %H:%M", btime)
	end

  local mtime = math.floor(self._file.cha.mtime or 0)
	if mtime == 0 then
		mtime = ""
	elseif os.date("%Y", mtime) == os.date("%Y") then
		mtime = os.date("%m/%d %H:%M", mtime)
	else
		mtime = os.date("%y/%m/%d %H:%M", mtime)
	end

	local size = self._file:size()
	return string.format("%s|%s|%s", size and ya.readable_size(size) or "-", btime, mtime)
end
