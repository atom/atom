{Chrome, Dir} = require 'osx'

_.map Dir.list(Chrome.appRoot() + "/plugins"), (plugin) ->
  try
    require plugin
  catch e
    name = _.last plugin.split '/'
    console.error "Problem loading plugin #{name}: #{e.message}"
