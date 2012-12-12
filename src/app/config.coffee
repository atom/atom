fs = require 'fs'
_ = require 'underscore'

module.exports =
class Config
  constructor: ->
    @configDirPath = fs.absolute("~/.atom")
    @configJsonPath = fs.join(@configDirPath, "config.json")
    @userInitScriptPath = fs.join(@configDirPath, "atom.coffee")

  load: ->
    if fs.exists(@configJsonPath)
      userConfig = JSON.parse(fs.read(@configJsonPath))
      _.extend(this, userConfig)
    @requireUserInitScript()

  requireUserInitScript: ->
    try
      require @userInitScriptPath if fs.exists(@userInitScriptPath)
    catch error
      console.error "Failed to load `#{@userInitScriptPath}`", error.stack, error
