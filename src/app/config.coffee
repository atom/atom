fs = require 'fs'
_ = require 'underscore'
EventEmitter = require 'event-emitter'

module.exports =
class Config
  configDirPath: fs.absolute("~/.atom")
  configJsonPath: fs.absolute("~/.atom/config.json")
  userInitScriptPath: fs.absolute("~/.atom/atom.coffee")

  load: ->
    if fs.exists(@configJsonPath)
      userConfig = JSON.parse(fs.read(@configJsonPath))
      _.extend(this, userConfig)
    @assignDefaults()
    @requireUserInitScript()

  assignDefaults: ->
    @core ?= {}
    _.defaults(@core, require('root-view').configDefaults)
    @editor ?= {}
    _.defaults(@editor, require('editor').configDefaults)

  update: ->
    @save()
    @trigger 'update'

  save: ->
    keysToWrite = _.clone(this)
    delete keysToWrite.eventHandlersByEventName
    delete keysToWrite.eventHandlersByNamespace
    delete keysToWrite.configDirPath
    delete keysToWrite.configJsonPath
    delete keysToWrite.userInitScriptPath
    fs.write(@configJsonPath, JSON.stringify(keysToWrite, undefined, 2) + "\n")

  requireUserInitScript: ->
    try
      console.log @userInitScriptPath
      require @userInitScriptPath if fs.exists(@userInitScriptPath)
    catch error
      console.error "Failed to load `#{@userInitScriptPath}`", error.stack, error

  valueAtKeyPath: (keyPath) ->
    value = this
    for key in keyPath
      break unless value = value[key]
    value

  observe: (keyPathString, callback) ->
    keyPath = keyPathString.split('.')
    value = @valueAtKeyPath(keyPath)
    updateCallback = =>
      newValue = @valueAtKeyPath(keyPath)
      unless newValue == value
        value = newValue
        callback(value)
    subscription = { destroy: => @off 'update', updateCallback  }
    @on 'update', updateCallback
    callback(value)
    subscription

_.extend Config.prototype, EventEmitter
