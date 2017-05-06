local _M = {}
local neturl = require("neturl")
require("fun") ()
local json = require("dkjson")
_M.new = function(self)
	local t = {}
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
	print(u.host)
	print(u.scheme)
	print(u.port or u.services[u.scheme])
	io.flush()
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
				print("read data size: " .. string.len(chunk))
				print(chunk)
				ret_res = chunk
			else
				print("nothing to read, close connection")
				uv.close(client)
			end
		end)
		print("connected to " .. u.host .. " now sending HTTP request")
		req = "GET " .. u.path .. " HTTP/1.1\r\n" .. 
			"Host: " .. u.host .. "\r\n" ..
			"User-Agent: ezhttp\r\n" .. 
			"Keep-Alive: 100\r\n" ..
			"Connection: keep-alive\r\n" ..
			"\r\n";
        print("sending " .. req)
		uv.write(client, req)
	end)
	uv.run('default')
	uv.loop_close()
	return ret_err, ret_res
end

_M.post = function(url, payload)
	print("post")
end

_M.getAsync = function(self)
	print("getAsync")
end

_M.postAsync = function(self)
	print("postAsync")
end

_M.waitAll = function(self)
	print("waitAll")
end

_M.waitOne = function(self)
	print("waitOne")
end

return _M