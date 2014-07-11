auth = require '../lib/auth'

global.silenceOutput = ->
  spyOn(console, 'log')
  spyOn(console, 'error')
  spyOn(process.stdout, 'write')
  spyOn(process.stderr, 'write')

global.spyOnToken = ->
  spyOn(auth, 'getToken').andCallFake (callback) -> callback(null, 'token')
