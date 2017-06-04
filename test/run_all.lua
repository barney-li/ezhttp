local http = require("http"):new()
local json = require("3rd.dkjson.dkjson")
http.useProxy = true
http:setProxy("192.168.0.103", 8888)
print(json.encode({1,http.useProxy, http.proxy}))
print("start async get")
http:postAsync("http://192.168.0.100/", 'hello world')
res = http:waitAll()
for i,v in ipairs(res) do
	print("--------------------")
	print("res of request" .. i)
	print("url: " .. v.url)
	print("err: " .. (v.err or "nil"))
	print("data: " .. (v.data or ""))
end
