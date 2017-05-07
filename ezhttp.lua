local _M = {}
local neturl = require("neturl")
local json = require("dkjson")
local log = require("log"):new("debug")
require("fun") ()

_M.new = function(self)
	local t = {}
	t.uv = require("luv")
	setmetatable(t.__index,_M)
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
	return ret_err, ret_res
end

_M.get = function(url)
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
	table.insert(self.queue, {__status="pending", __stage="new"})
	local myQuePos = #(self.queue)
	local u = neturl.parse(url)
	log:debug(u.host)
	log:debug(u.scheme)
	log:debug(u.port or u.services[u.scheme])

	self.uv.getaddrinfo(u.host, nil, nil, function(err, addr)
		if not err then
			local client = self.uv.new_tcp()
			uv.tcp_connect(client, addr, u.port or u.services[u.scheme], function(err) 
				if not err then
					uv.read_start(client, function(err, chunk) 
						if err then
							log.error(err)
							self.queue[myQuePos] = {__status = "done", __stage = "on_read_start", data = nil, err = err}
						else
							if chunk then
								self.queue[myQuePos].stage = "on_read_start"
								self.queue[myQuePos].data = self.queue[myQuePos].data .. data
							else
								self.queue[myQuePos].__status = "done"
								self.uv.close(client)
					end ) -- read_start callback
				else
					log.error(err)
					self.queue[myQuePos] = {__status = "done", __stage = "on_tcp_connect", data = nil, err = err}
			end ) -- tcp_connect callback
		else
			log.error(err)
			self.queue[myQuePos] = {__status = "done", __stage = "on_getaddrinfo", data = nil, err = err}
	end ) -- getaddrinfo callback
end

_M.postAsync = function(self)
	log:debug("postAsync")
end

_M.waitAll = function(self)
	uv.run('default')
	uv.loop_close()
	return self.queue
end

_M.waitOne = function(self)
	log:debug("waitOne")
end

return _M