path = require "path"
fs = require "fs-plus"

module.exports =
class StorageFolder
  constructor: (containingPath) ->
    @path = path.join(containingPath, "storage")

  store: (name, object) ->
    fs.writeFileSync(@pathForKey(name), JSON.stringify(object), 'utf8')

  load: (name) ->
    statePath = @pathForKey(name)
    try
      stateString = fs.readFileSync(statePath, 'utf8')
    catch error
      unless error.code is 'ENOENT'
        console.warn "Error reading state file: #{statePath}", error.stack, error
      return undefined

    try
      JSON.parse(stateString)
    catch error
      console.warn "Error parsing state file: #{statePath}", error.stack, error

  pathForKey: (name) -> path.join(@getPath(), name)
  getPath: -> @path
