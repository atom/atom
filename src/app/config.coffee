fs = require 'fs'
_ = require 'underscore'
EventEmitter = require 'event-emitter'

configDirPath = fs.absolute("~/.atom")
configJsonPath = fs.join(configDirPath, "config.json")
userInitScriptPath = fs.join(configDirPath, "atom.coffee")
bundledExtensionsDirPath = fs.join(resourcePath, "src/extensions")
userExtensionsDirPath = fs.join(configDirPath, "extensions")

require.paths.unshift userExtensionsDirPath

module.exports =
class Config
  configDirPath: configDirPath

  load: ->
    @loadUserConfig()
    @assignDefaults()
    @registerNewExtensions()
    @requireExtensions()
    @requireUserInitScript()

  loadUserConfig: ->
    if fs.exists(configJsonPath)
      userConfig = JSON.parse(fs.read(configJsonPath))
      _.extend(this, userConfig)

  assignDefaults: ->
    @core ?= {}
    _.defaults(@core, require('root-view').configDefaults)
    @editor ?= {}
    _.defaults(@editor, require('editor').configDefaults)

  registerNewExtensions: ->
    shouldUpdate = false
    for extensionName in @getAvailableExtensions()
      @core.extensions.push(extensionName) unless @isExtensionRegistered(extensionName)
      shouldUpdate = true
    @update() if shouldUpdate

  isExtensionRegistered: (extensionName) ->
    return true if _.contains(@core.extensions, extensionName)
    return true if _.contains(@core.extensions, "!#{extensionName}")
    false

  getAvailableExtensions: ->
    availableExtensions =
      fs.list(bundledExtensionsDirPath)
        .concat(fs.list(userExtensionsDirPath)).map (path) -> fs.base(path)
    _.unique(availableExtensions)

  requireExtensions: ->
    for extensionName in config.core.extensions
      requireExtension(extensionName) unless extensionName[0] == '!'


  get: (keyPath) ->
    keyPath = keyPath.split(".") if typeof keyPath is 'string'
    value = this
    for key in keyPath
      break unless value = value[key]
    value

  set: (keyPath, value) ->
    if typeof keyPath is 'string'
      keyPath = keyPath.split(".")
    else
      keyPath = new Array(keyPath...)

    hash = this
    while keyPath.length > 1
      key = keyPath.shift()
      hash[key] ?= {}
      hash = hash[key]
    hash[keyPath.shift()] = value

    @update()
    value

  observe: (keyPath, callback) ->
    value = @get(keyPath)
    previousValue = _.clone(value)
    updateCallback = =>
      value = @get(keyPath)
      unless value == previousValue
        previousValue = _.clone(value)
        callback(value)

    subscription = { cancel: => @off 'update', updateCallback  }
    @on 'update', updateCallback
    callback(value)
    subscription

  update: ->
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
      require userInitScriptPath if fs.exists(userInitScriptPath)
    catch error
      console.error "Failed to load `#{userInitScriptPath}`", error.stack, error

_.extend Config.prototype, EventEmitter
