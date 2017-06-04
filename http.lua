local _M = {}
local neturl = require("neturl")

function _M:new()
	self.logger = require("log"):new("debug")
	self.queue = {}
	self.waitOneFlag = false
	print(debug.getinfo(2,'S').source)
	self.uv = require("luv")
	self.useProxy = false
	local t = {}
	setmetatable(t,self)
	self.__index = self
	return t
end

function _M:setProxy(addr, port)
	self.proxy = {addr=addr, port=port}
end

function _M:solve(host)
	local uv = require("luv")
	local client = uv.new_tcp()
	local ret_err, ret_res
	uv.getaddrinfo(host, nil, nil, function(err, res)
		ret_err = err
		ret_res = res[1]["addr"]
		client:close()
	end)
	uv.run('default')
	return ret_err, ret_res
end

function _M:get(url)
	local u = neturl.parse(url)
	local uv = require("luv")
	local client = uv.new_tcp()
	local ret_err, ret_res
	local err, solvedAddr = _M:solve(u.host)
	if err then
		return err, nil
	end
	local connAddr = solvedAddr
	local connPort = u.port
	if self.useProxy then
		connAddr = self.proxy.addr
		connPort = self.proxy.port
	end
	uv.tcp_connect(client, connAddr, connPort or u.services[u.scheme], function(err) 
		assert(not err, err)
		ret_err = err
		uv.read_start(client, function(err, chunk)
			if chunk then
				ret_res = (ret_res or '') .. chunk
			else
				self.logger:debug("read data size: " .. string.len(ret_res))
				client:close() -- either close client here or close loop after uv.run, but can't do both
			end
		end )
		self.logger:debug("connected to " .. u.host .. " now sending HTTP request")
		req = "GET " .. u.path .. " HTTP/1.1\r\n" .. 
			"Host: " .. u.host .. "\r\n" ..
			"User-Agent: ezhttp\r\n" .. 
			"Connection: close\r\n" ..
			"\r\n";
        self.logger:debug("sending " .. req)
		uv.write(client, req)
	end )
	uv.run('default')
	return ret_err, ret_res
end

_M.post = function(url, payload)
	
end

function _M:getAsync(url)
	self:reqAsync("GET", url)
end

function _M:postAsync(url, payload)
	self:reqAsync("POST", url, payload)
end

function _M:reqAsync(method, url, payload)
	table.insert(self.queue, {__status="pending", __stage="new", __client=nil, url = url, data="", err = nil})
	local myQuePos = #(self.queue)
	local u = neturl.parse(url)
	self.uv.getaddrinfo( self.useProxy and self.proxy.addr or u.host, nil, nil, function(err, res)

		if not err then
			local addr = res[1]["addr"]
			local client = self.uv.new_tcp()
			self.queue[myQuePos].__client = client
			self.uv.tcp_connect(client, addr, self.useProxy and self.proxy.port or (u.port or u.services[u.scheme]), function(err)

				if not err then
					self.uv.read_start(client, function(err, chunk)
						if err then
							self.logger:error(err)
							self.queue[myQuePos] = {__status = "done", __stage = "on_read_start", data = nil, err = err}
						else
							if chunk then
								self.queue[myQuePos].__stage = "on_read_start"
								self.queue[myQuePos].data = self.queue[myQuePos].data .. chunk
								self.logger:debug("read data length of " .. myQuePos .. ": " .. string.len(self.queue[myQuePos].data))
							else
								self.logger:debug("reached EOF and read data length of " .. myQuePos .. ": " .. string.len(self.queue[myQuePos].data))
								self.queue[myQuePos].__status = "done"
								self:__break()
							end
						end
					end -- read_start callback
					)
					self.logger:debug("connected to " .. (self.useProxy and self.proxy.addr or u.host) .. ":" .. (self.useProxy and self.proxy.port or (u.port or u.services[u.scheme])))
					req = method .. " " .. u.path .. " HTTP/1.1\r\n" .. 
						"Host: " .. u.host .. "\r\n" ..
						"User-Agent: ezhttp\r\n" .. 
						"Connection: close\r\n" .. 
						"Accept-Encoding: deflate\r\n"
					if payload ~= nil then
						req = req .. "Content-Length: " .. string.len(payload) .. "\r\n\r\n"
						req = req .. payload
					end
					req = req .. "\r\n"
					self.logger:debug("sending " .. req)
					self.uv.write(client, req) 
				else
					self.logger:error(err)
					self.queue[myQuePos] = {__status = "done", __stage = "on_tcp_connect", data = nil, err = err}
				end
			end -- tcp_connect callback
			) 
		else
			self.logger:error(err)
			self.queue[myQuePos] = {__status = "done", __stage = "on_getaddrinfo", data = nil, err = err}
		end
	end -- getaddrinfo callback
	)
end

function _M:waitAll()
	local runRes = self.uv.run('default')
	local queue = self.queue
	self.queue = {}
	return queue
end

function _M:waitOne()
	self.waitOneFlag = true
	return self:waitAll()
end

function _M:__break()
	if self.waitOneFlag then
		for i,v in ipairs(self.queue) do
			v.__client:close()
		end
		self.waitOneFlag = false
	end
end

return _M