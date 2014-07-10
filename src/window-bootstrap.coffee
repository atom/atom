# Like sands through the hourglass, so are the days of our lives.
ipc = require 'ipc'
largeFilePath = "/Users/corey/Desktop/tmp/large.txt"
smallFilePath = "/Users/corey/Desktop/tmp/small.txt"


start = ->
	console.log "Started"
	TextBuffer = require 'text-buffer'
	buffer = new TextBuffer(filePath: smallFilePath)
	buffer.load().then ->
		console.log "Buffer with #{buffer.lines.length} lines loaded"
  
showDevTools = ->
  ipc.send('call-window-method', 'openDevTools')
  ipc.send('call-window-method', 'executeJavaScriptInDevTools', 'InspectorFrontendAPI.showConsole()')

setImmediate ->
  ipc.send('call-window-method', 'show')
	start()