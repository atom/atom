path = require "path"
fs = require "fs-plus"

module.exports =
class StorageFolder
  constructor: (containingPath) ->
    @path = path.join(containingPath, "storage")

  store: (name, object) ->
    fs.writeFileSync(@pathForKey(name), JSON.stringify(object), 'utf8')

  load: (name) ->
    try
      stateString = fs.readFileSync(@pathForKey(name), 'utf8')
    catch error
      if error.code is 'ENOENT'
        return undefined
      else
        throw error

    try
      JSON.parse(stateString)
    catch error
      console.warn "Error reading state file: #{statePath}", error.stack, error

  pathForKey: (name) -> path.join(@getPath(), name)
  getPath: -> @path
