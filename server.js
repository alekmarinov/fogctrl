var restify  = require("restify")
var EventEmitter = require('events').EventEmitter  
var messageBus = new EventEmitter()  
messageBus.setMaxListeners(100)  

var server = restify.createServer(
{
	name: 'FogCtrl'
})

server.use(restify.bodyParser())
server.use(restify.gzipResponse())
server.use(restify.queryParser())

// snippet taken from http://catapulty.tumblr.com/post/8303749793/heroku-and-node-js-how-to-get-the-client-ip-address
function getClientIp(req) {
  var ipAddress
  // The request may be forwarded from local web server.
  var forwardedIpsStr = req.header('x-forwarded-for')
  if (forwardedIpsStr) {
    // 'x-forwarded-for' header may return multiple IP addresses in
    // the format: "client IP, proxy 1 IP, proxy 2 IP" so take the
    // the first one
    var forwardedIps = forwardedIpsStr.split(',')
    ipAddress = forwardedIps[0];
  }
  if (!ipAddress) {
    // If request was not forwarded
    ipAddress = req.connection.remoteAddress
  }
  return ipAddress
}

function getDateTime() {
    var date = new Date();
    var hour = date.getHours();
    hour = (hour < 10 ? "0" : "") + hour;
    var min  = date.getMinutes();
    min = (min < 10 ? "0" : "") + min;
    var sec  = date.getSeconds();
    sec = (sec < 10 ? "0" : "") + sec;
    var year = date.getFullYear();
    var month = date.getMonth() + 1;
    month = (month < 10 ? "0" : "") + month;
    var day  = date.getDate();
    day = (day < 10 ? "0" : "") + day;
    return year + "-" + month + "-" + day + " " + hour + ":" + min + ":" + sec;
}

var config = {
	status: "off",
	offtime: "10",
	ontime: "10",
	lastip: "0.0.0.0",
	lastaccess: "????-??-?? ??:??:??",
};

server.post('/config', function(req, res, next)
{
	config = JSON.parse(req.body);
	console.log("POST", config);
	config.status = config.status || "off";
	config.offtime = config.offtime || "10";
	config.ontime = config.ontime || "10";
	res.send(config);

	messageBus.emit('message', config);
	return next();
})

server.get('/config', function(req, res, next)
{
	console.log("GET", config);
	res.send(config);
	return next();
})

var intervalId
server.get('/longpoll', function(req, res, next)
{
	config.lastip = getClientIp(req);
	config.lastaccess = getDateTime();
	console.log("/longpoll", config)
    messageBus.once('message', function(data){
        res.json(data)
    });

	if (intervalId) clearInterval(intervalId);
    intervalId = setInterval(function() {
		messageBus.emit('message', config);
    }, 10000);
})

server.get("/shutdown", function(req, res, next) 
{
	if (getClientIp(req) == "127.0.0.1")
	{
		console.log("Shutting down...")
		process.exit(0)
		return true
	}
	else
	{
		res.send(404);
		return next();
	}
})

server.get(".*", restify.serveStatic({
  directory: (process.env.NGP_HOME || '.') + "/static",
  default: "index.html"
}))

server.listen(80, function()
{
	console.log('%s listening at %s', server.name, server.url)
})
