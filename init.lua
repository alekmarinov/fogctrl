-------------------------------------------------------------------------------
print('esp8266 fog controller')
-------------------------------------------------------------------------------

WIFIUSER="Juje"
WIFIPASS="08978211188"
-- WIFIUSER="Todor"
-- WIFIPASS="7654321098e"
-- WIFIUSER="aviqus"
-- WIFIPASS="tarantula4"

CTRL = 3
LIGHT = 4

wifi.setmode(wifi.STATIONAP)
wifi.sta.disconnect()
print("WiFi connect to "..WIFIUSER..":"..WIFIPASS)
wifi.sta.config(WIFIUSER, WIFIPASS)

host = 'fog.intelibo.com'
port = 80

ON = true
OFF = false

gpio.mode(CTRL, gpio.OUTPUT)
gpio.mode(LIGHT, gpio.OUTPUT)
conn = net.createConnection(net.TCP, 0) 

function decode(str)
  local res = {}
  string.gsub(str, "\"(.-)\"%s*:%s*\"(.-)\"", function (name, value)
    res[name] = value
  end)
  return res
end

function switch(isOn)
  gpio.write(CTRL, isOn and gpio.HIGH or gpio.LOW)
  gpio.write(LIGHT, isOn and gpio.LOW or gpio.HIGH)
end

function get(uri)
   conn:send("GET "..uri
    .." HTTP/1.1\r\n" 
    .."Host: "..host..":"..port.."\r\n" 
   .."Connection: keep-alive\r\n"
    .."Accept: */*\r\n" 
    .."User-Agent: Mozilla/4.0 (compatible; esp8266 Lua; Windows NT 5.1)\r\n" 
    .."\r\n")
end

function longpoll()
  get("/longpoll")
end

function config()
  get("/config")
end

function compareconf(conf1, conf2)
  if conf1 and conf2 then
    return conf1.status == conf2.status and conf1.ontime == conf2.ontime and conf1.offtime == conf2.offtime
  end
end

function conf2str(conf)
  return string.format("%s, ontime=%s, offtime=%s, lastip=%s, lastaccess=%s",
    conf.status or "", conf.ontime or "", conf.offtime or "", conf.lastip or "", conf.lastaccess or "")
end

local lastconf
function reconfigure(conf)
  if lastconf and compareconf(conf, lastconf) then
    return
  end
  lastconf = conf
  print("reconfigure to "..conf2str(conf))

  local offtimer

  function ontimer()
      switch(ON)
      tmr.alarm(1, 1000*tonumber(conf.ontime), 0, offtimer)
  end

  function offtimer()
      switch(OFF)
      tmr.alarm(1, 1000*tonumber(conf.offtime), 0, ontimer)
  end


  tmr.stop(1)

  if conf.status == "on" then
    ontimer()
  else
    switch(OFF)
  end
end

conn:on("receive", function(conn, payload)
    -- skip header
    payload = payload:gsub(".-\r\n\r\n", "")
    print('Receive: '..payload)

    -- reconfigure the controller
    reconfigure(decode(payload))

    tmr.alarm(0, 100, 0, longpoll)
end)

conn:on("connection", function(conn) 
  print('\nConnected')
  config()
end)

conn:on("disconnection", function(conn) 
  print('\nDisconnected')
  conn:connect(port, host)
end)

switch(OFF)
print("Connecting to "..host..":"..port)
conn:connect(port, host)
