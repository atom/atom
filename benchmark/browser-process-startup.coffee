#!/usr/bin/env coffee

{spawn, exec} = require 'child_process'
os = require 'os'
path = require 'path'
_ = require 'underscore-plus'
temp = require 'temp'

directoryToOpen = temp.mkdirSync('browser-process-startup-')
socketPath = path.join(os.tmpdir(), 'atom.sock')
numberOfRuns = 10

launchAtom = (callback) ->
  cmd = 'atom'
  args = ['--safe', '--new-window', '--foreground', directoryToOpen]
  atomProcess = spawn(cmd, args)

  output = ''
  startupTimes = []

  dataListener = (data) ->
    output += data
    if match = /App load time: (\d+)/.exec(output)
      atomProcess.stderr.removeListener 'data', dataListener
      atomProcess.kill()
      exec 'pkill -9 Atom', ->
        try
          fs.unlinkSync(socketPath)

        callback(parseInt(match[1]))

  atomProcess.stderr.on 'data', dataListener

startupTimes = []
collector = (startupTime) ->
  startupTimes.push(startupTime)
  if startupTimes.length < numberOfRuns
    launchAtom(collector)
  else
    maxTime = _.max(startupTimes)
    minTime = _.min(startupTimes)
    totalTime = startupTimes.reduce (previousValue=0, currentValue) -> previousValue + currentValue
    console.log "Startup Runs: #{startupTimes.length}"
    console.log "Max time: #{maxTime}ms"
    console.log "Min time: #{minTime}ms"
    console.log "Average time: #{Math.round(totalTime/startupTimes.length)}ms"

launchAtom(collector)
