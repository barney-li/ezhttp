local _M = {}

_M.priorityMap = {
	debug = 0,
	info = 1,
	warn = 2,
	error = 3,
	fatal = 4
}

_M.new = function(self,level)
	local t = {}
	t.priority = self.priorityMap[level]
	setmetatable(t, {__index = _M})
	return t
end

_M.say = function(self, msg, level)
	if self.priorityMap[level] >= self.priority then print("[" .. level .. "] " .. msg) end
	io.flush()
end

for k, _ in pairs(_M.priorityMap) do
	_M[k] = function(self, msg)
		self:say(msg, k)
	end
end

return _M