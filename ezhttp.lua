local _M = {}
local neturl = require("neturl")
local json = require("dkjson")

function _M:new(session)
	self.logger = require("log"):new("debug", session)
	self.queue = {}
	self.waitOneFlag = false
	self.session = session
	local t = {}
	t.uv = require("luv")
	setmetatable(t,self)
	self.__index = self
	return t
end

function _M:solve(host)
	local uv = require("luv")
	local client = uv.new_tcp()
	local ret_err, ret_res
	uv.getaddrinfo(host, nil, nil, function(err, res)
		ret_err = err
		ret_res = res[1]["addr"]
	end)
	uv.run('default')
	uv.loop_close()
	self.logger:debug("solved addr: " .. json.encode(ret_res))
	return ret_err, ret_res
end

function _M:get(url)
	local u = neturl.parse(url)
	self.logger:debug(u.host)
	self.logger:debug(u.scheme)
	self.logger:debug(u.port or u.services[u.scheme])
	local uv = require("luv")
	local client = uv.new_tcp()
	local ret_err, ret_res
	local err, addr = _M:solve(u.host)
	if err then
		return err, nil
	end
	self.logger:debug(addr)
	uv.tcp_connect(client, addr, u.port or u.services[u.scheme], function(err) 
		assert(not err, err)
		ret_err = err
		uv.read_start(client, function(err, chunk)
			if chunk then
				self.logger:debug("read data size: " .. string.len(chunk))
				self.logger:debug(chunk)
				ret_res = chunk
			else
				self.logger:debug("nothing to read, close connection")
				uv.close(client)
			end
		end )
		self.logger:debug("connected to " .. u.host .. " now sending HTTP request")
		req = "GET " .. u.path .. " HTTP/1.1\r\n" .. 
			"Host: " .. u.host .. "\r\n" ..
			"User-Agent: ezhttp\r\n" .. 
			"Keep-Alive: 100\r\n" ..
			"Connection: keep-alive\r\n" ..
			"\r\n";
        self.logger:debug("sending " .. req)
		uv.write(client, req)
	end )
	uv.run('default')
	uv.loop_close()
	return ret_err, ret_res
end

_M.post = function(url, payload)
	
end

function _M:getAsync(url)
	table.insert(self.queue, {__status="pending", __stage="new", url = url, data="", err = nil})
	local myQuePos = #(self.queue)
	self.logger:debug("insert queue: " .. myQuePos)
	local u = neturl.parse(url)
	self.logger:debug(u.host)
	self.logger:debug(u.scheme)
	self.logger:debug(u.port or u.services[u.scheme])

	self.uv.getaddrinfo(u.host, nil, nil, function(err, res)
		self.logger:debug("queue len in solve cb: " .. #(self.queue))
		if not err then
			local addr = res[1]["addr"]
			local client = self.uv.new_tcp()
			self.uv.tcp_connect(client, addr, u.port or u.services[u.scheme], function(err)
				self.logger:debug("queue len in connect cb: " .. #(self.queue))
				if not err then
					self.uv.read_start(client, function(err, chunk)
						self.logger:debug("queue len in read cb: " .. #(self.queue))
						self.logger:debug("myQuePos: " .. myQuePos)
						if self.queue[myQuePos] == nil then
							self.logger:error("-------------empty queue-----------")
						end
						if err then
							self.logger:error(err)
							self.queue[myQuePos] = {__status = "done", __stage = "on_read_start", data = nil, err = err}
						else
							if chunk then
								self.logger:debug("read data length: " .. string.len(chunk))
								self.queue[myQuePos].__stage = "on_read_start"
								self.queue[myQuePos].data = self.queue[myQuePos].data .. chunk
							else
								self.queue[myQuePos].__status = "done"
								self.uv.close(client)
								self:__break()
							end
						end
					end -- read_start callback
					)
					self.logger:debug("connected to " .. u.host .. " now sending HTTP request")
					req = "GET " .. u.path .. " HTTP/1.1\r\n" .. 
						"Host: " .. u.host .. "\r\n" ..
						"User-Agent: ezhttp\r\n" .. 
						"Keep-Alive: 100\r\n" ..
						"Connection: keep-alive\r\n" ..
						"\r\n";
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

function _M:postAsync()
	self.logger:debug("postAsync")
end

function _M:waitAll()
	self.uv.run('default')
	--self.uv.stop()
	local queue = self.queue
	self.logger:debug("clear queue")
	self.queue = {}
	return queue
end

function _M:waitOne()
	self.waitOneFlag = true
	self.uv.run('default')
	local queue = self.queue
	self.logger:debug("clear queue")
	self.queue = {}
	return queue
end

function _M:waitAsync(self)
	self.uv.run('once')
end

function _M:__break()
	if self.waitOneFlag then
		self.logger:debug("break")
		self.uv.stop()
	end
end

return _M