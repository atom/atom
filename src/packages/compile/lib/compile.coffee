fs = require 'fs'
ChildProcess = require 'child-process'

module.exports =
class Compile
  @activate: (rootView, state) ->
    instance = new Compile()
    rootView.command 'compile:run', => instance.run(rootView)

  initialize: ->
    super

  run: ->
    ChildProcess.exec 'ls',
      cwd: rootView.getProject().getRootDirectory(),
      bufferLines: true,
      stdout: @stdoutHandler,
      stderr: @stderrHandler

  stdoutHandler: (data) ->
    console.log data

  stderrHandler: (data) ->
    console.log data
