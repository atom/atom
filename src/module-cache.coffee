Module = require 'module'
fs = require 'fs-plus'

originalResolveFilename = Module._resolveFilename

Module._resolveFilename = (relative, parent) ->
  resolved = originalResolveFilename.apply(global, arguments)
  if relative[0] isnt '.' and not fs.isAbsolute(relative) and relative isnt resolved
    console.log "#{relative} -> #{resolved}"
  resolved
