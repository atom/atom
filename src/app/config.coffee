module.exports =
class Config
  load: ->
    try
      require atom.configFilePath if fs.exists(atom.configFilePath)
    catch error
      console.error "Failed to load `#{atom.configFilePath}`", error.stack, error
