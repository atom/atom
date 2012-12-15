fs = require 'fs'
_ = require 'underscore'
EventEmitter = require 'event-emitter'

configDirPath = fs.absolute("~/.atom")
configJsonPath = fs.join(configDirPath, "config.json")
userInitScriptPath = fs.join(configDirPath, "atom.coffee")
bundledExtensionsDirPath = fs.join(resourcePath, "src/extensions")
userExtensionsDirPath = fs.join(configDirPath, "extensions")

module.exports =
class Config
  configDirPath: configDirPath

  load: ->
    if fs.exists(configJsonPath)
      userConfig = JSON.parse(fs.read(configJsonPath))
      _.extend(this, userConfig)
    @assignDefaults()
    @registerNewExtensions()
    @requireUserInitScript()

  assignDefaults: ->
    @core ?= {}
    _.defaults(@core, require('root-view').configDefaults)
    @editor ?= {}
    _.defaults(@editor, require('editor').configDefaults)

  registerNewExtensions: ->
    registeredExtensions = _.pluck(@core.extensions, 'name')
    for extensionName in _.unique(@listExtensionNames())
      unless _.contains(registeredExtensions, extensionName)
        console.log "registering", extensionName
        @core.extensions.push(name: extensionName, enabled: true)
        @update()

  listExtensionNames: ->
    fs.list(bundledExtensionsDirPath).concat(fs.list(userExtensionsDirPath)).map (path) ->
      fs.base(path)

  update: (keyPathString, value) ->
    @setValueAtKeyPath(keyPathString.split('.'), value) if keyPathString
    @save()
    @trigger 'update'

  save: ->
    keysToWrite = _.clone(this)
    delete keysToWrite.eventHandlersByEventName
    delete keysToWrite.eventHandlersByNamespace
    delete keysToWrite.configDirPath
    fs.write(configJsonPath, JSON.stringify(keysToWrite, undefined, 2) + "\n")

  requireUserInitScript: ->
    try
      console.log @userInitScriptPath
      require userInitScriptPath if fs.exists(userInitScriptPath)
    catch error
      console.error "Failed to load `#{@userInitScriptPath}`", error.stack, error

  valueAtKeyPath: (keyPath) ->
    value = this
    for key in keyPath
      break unless value = value[key]
    value

  setValueAtKeyPath: (keyPath, value) ->
    keyPath = new Array(keyPath...)
    hash = this
    while keyPath.length > 1
      key = keyPath.shift()
      hash[key] ?= {}
      hash = hash[key]
    hash[keyPath.shift()] = value

  observe: (keyPathString, callback) ->
    keyPath = keyPathString.split('.')
    value = @valueAtKeyPath(keyPath)
    updateCallback = =>
      newValue = @valueAtKeyPath(keyPath)
      unless newValue == value
        value = newValue
        callback(value)
    subscription = { cancel: => @off 'update', updateCallback  }
    @on 'update', updateCallback
    callback(value)
    subscription

_.extend Config.prototype, EventEmitter
