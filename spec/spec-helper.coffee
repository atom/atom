auth = require '../lib/auth'

global.silenceOutput = ->
  spyOn(console, 'log')
  spyOn(console, 'error')
  spyOn(process.stdout, 'write')
  spyOn(process.stderr, 'write')
  spyOn(process, 'exit')

global.spyOnToken = ->
  spyOn(auth, 'getToken').andCallFake (callback) -> callback(null, 'token')
