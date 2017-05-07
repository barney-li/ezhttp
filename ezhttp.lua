local _M = {}
local neturl = require("neturl")
local json = require("dkjson")
local log = require("log"):new("debug")

_M.new = function(self)
	local t = {queue = {}, waitOneFlag = false}
	t.uv = require("luv")
	setmetatable(t,self)
	self.__index = self
	return t
end

_M.solve = function(host)
	local uv = require("luv")
	local client = uv.new_tcp()
	local ret_err, ret_res
	uv.getaddrinfo(host, nil, nil, function(err, res)
		ret_err = err
		ret_res = res[1]["addr"]
	end)
	uv.run('default')
	uv.loop_close()
	log:debug("solved addr: " .. json.encode(ret_res))
	return ret_err, ret_res
end

_M.get = function(self, url)
	local u = neturl.parse(url)
	log:debug(u.host)
	log:debug(u.scheme)
	log:debug(u.port or u.services[u.scheme])
	local uv = require("luv")
	local client = uv.new_tcp()
	local ret_err, ret_res
	local err, addr = _M.solve(u.host)
	if err then
		return err, nil
	end
	log:debug(addr)
	uv.tcp_connect(client, addr, u.port or u.services[u.scheme], function(err) 
		assert(not err, err)
		ret_err = err
		uv.read_start(client, function(err, chunk)
			if chunk then
				log:debug("read data size: " .. string.len(chunk))
				log:debug(chunk)
				ret_res = chunk
			else
				log:debug("nothing to read, close connection")
				uv.close(client)
			end
		end )
		log:debug("connected to " .. u.host .. " now sending HTTP request")
		req = "GET " .. u.path .. " HTTP/1.1\r\n" .. 
			"Host: " .. u.host .. "\r\n" ..
			"User-Agent: ezhttp\r\n" .. 
			"Keep-Alive: 100\r\n" ..
			"Connection: keep-alive\r\n" ..
			"\r\n";
        log:debug("sending " .. req)
		uv.write(client, req)
	end )
	uv.run('default')
	uv.loop_close()
	return ret_err, ret_res
end

_M.post = function(url, payload)
	
end

_M.getAsync = function(self, url)
	table.insert(self.queue, {__status="pending", __stage="new", url = url, data="", err = nil})
	local myQuePos = #(self.queue)
	local u = neturl.parse(url)
	log:debug(u.host)
	log:debug(u.scheme)
	log:debug(u.port or u.services[u.scheme])

	self.uv.getaddrinfo(u.host, nil, nil, function(err, res)
		if not err then
			local addr = res[1]["addr"]
			local client = self.uv.new_tcp()
			self.uv.tcp_connect(client, addr, u.port or u.services[u.scheme], function(err) 
				if not err then
					self.uv.read_start(client, function(err, chunk) 
						if err then
							log:error(err)
							self.queue[myQuePos] = {__status = "done", __stage = "on_read_start", data = nil, err = err}
						else
							if chunk then
								log:debug("read data length: " .. string.len(chunk))
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
					log:debug("connected to " .. u.host .. " now sending HTTP request")
					req = "GET " .. u.path .. " HTTP/1.1\r\n" .. 
						"Host: " .. u.host .. "\r\n" ..
						"User-Agent: ezhttp\r\n" .. 
						"Keep-Alive: 100\r\n" ..
						"Connection: keep-alive\r\n" ..
						"\r\n";
					log:debug("sending " .. req)
					self.uv.write(client, req) 
				else
					log:error(err)
					self.queue[myQuePos] = {__status = "done", __stage = "on_tcp_connect", data = nil, err = err}
				end
			end -- tcp_connect callback
			) 
		else
			log:error(err)
			self.queue[myQuePos] = {__status = "done", __stage = "on_getaddrinfo", data = nil, err = err}
		end
	end -- getaddrinfo callback
	) 
end

_M.postAsync = function(self)
	log:debug("postAsync")
end

_M.waitAll = function(self)
	self.uv.run('default')
	self.uv.stop()
	local queue = self.queue
	self.queue = {}
	return queue
end

_M.waitOne = function(self)
	self.waitOneFlag = true
	self.uv.run('default')
	local queue = self.queue
	self.queue = {}
	return queue
end

_M.__break = function(self)
	if self.waitOneFlag then
		log:debug("break")
		self.uv.stop()
	end
end

return _M