#!/usr/bin/env coffee

{spawn, exec} = require 'child_process'
fs = require 'fs'
os = require 'os'
path = require 'path'
_ = require 'underscore-plus'
temp = require 'temp'

directoryToOpen = temp.mkdirSync('browser-process-startup-')
socketPath = path.join(os.tmpdir(), "atom-#{process.env.USER}.sock")
numberOfRuns = 10

deleteSocketFile = ->
  try
    fs.unlinkSync(socketPath) if fs.existsSync(socketPath)
  catch error
    console.error(error)

launchAtom = (callback) ->
  deleteSocketFile()

  cmd = 'atom'
  args = ['--safe', '--new-window', '--foreground', directoryToOpen]
  atomProcess = spawn(cmd, args)

  output = ''
  startupTimes = []
  dataListener = (data) ->
    output += data
    if match = /App load time: (\d+)/.exec(output)
      startupTime = parseInt(match[1])
      atomProcess.stderr.removeListener 'data', dataListener
      atomProcess.kill()
      exec 'pkill -9 Atom', (error) ->
        console.error(error) if error?
        callback(startupTime)

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
    console.log "First run time: #{startupTimes[0]}ms"
    console.log "Max time: #{maxTime}ms"
    console.log "Min time: #{minTime}ms"
    console.log "Average time: #{Math.round(totalTime/startupTimes.length)}ms"

launchAtom(collector)
