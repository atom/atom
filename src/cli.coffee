apm = require './apm-cli'

process.title = 'apm'

apm.run process.argv.slice(2), (error) ->
  process.exitCode = if error? then 1 else 0
