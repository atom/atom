assert = require 'assert'
ChildProcess = require 'child-process'

ChildProcess.exec "echo hello", (error, stdout, stderr) ->
  assert.equal "hello", stdout.trim()
  assert.equal null, error  
  
ChildProcess.exec "derp hello", (error, stdout, stderr) ->
  assert.equal "/bin/bash: derp: command not found", stderr.trim()
  assert.ok error
  assert.equal 127, error.code

ChildProcess.exec "coffee -e 'console.log 1+1'", (error, stdout, stderr) ->
  assert.equal "2", stdout.trim()