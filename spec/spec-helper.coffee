auth = require '../lib/auth'

global.silenceOutput = (callThrough = false) ->
  spyOn(console, 'log')
  spyOn(console, 'error')
  spyOn(process.stdout, 'write')
  spyOn(process.stderr, 'write')

  if callThrough
    spy.andCallThrough() for spy in [
      console.log,
      console.error,
      process.stdout.write,
      process.stderr.write
    ]

global.spyOnToken = ->
  spyOn(auth, 'getToken').andCallFake (callback) -> callback(null, 'token')
