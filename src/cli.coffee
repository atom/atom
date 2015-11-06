apm = require './apm-cli'

process.title = 'apm'
apm.run process.argv.slice(2), (error) ->
  code = if error? then 1 else 0
  if process.platform is 'win32'
    exit = require('exit')
    exit(code)
  else
    process.exit(code)
