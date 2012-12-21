fs = require 'fs'
_ = require 'underscore'
EventEmitter = require 'event-emitter'

configDirPath = fs.absolute("~/.atom")
configJsonPath = fs.join(configDirPath, "config.json")
userInitScriptPath = fs.join(configDirPath, "atom.coffee")
bundledPackagesDirPath = fs.join(resourcePath, "src/packages")
userPackagesDirPath = fs.join(configDirPath, "packages")

require.paths.unshift userPackagesDirPath

module.exports =
class Config
  configDirPath: configDirPath
  settings: null

  load: ->
    @settings = {}
    @loadUserConfig()
    @assignDefaults()
    @loadPackages(@getAvailableTextMateBundles())
    @loadPackages(@getAvailableAtomPackages())
    @requireUserInitScript()

  loadUserConfig: ->
    if fs.exists(configJsonPath)
      userConfig = JSON.parse(fs.read(configJsonPath))
      _.extend(@settings, userConfig)

  assignDefaults: ->
    @settings ?= {}
    @setDefaults "core", require('root-view').configDefaults
    @setDefaults "editor", require('editor').configDefaults

  getAvailablePackages: ->
    atomPackages = fs.list(bundledPackagesDirPath)
    userPackages = fs.list(userPackagesDirPath)
    allPackageNames = atomPackages.concat(userPackages).map (path) -> fs.base(path)
    _.unique(allPackageNames)

  getAvailableTextMateBundles: ->
    @getAvailablePackages().filter (packageName) => @isTextMateBundle(packageName)

  getAvailableAtomPackages: ->
    @getAvailablePackages().filter (packageName) => not @isTextMateBundle(packageName)

  loadPackages: (packageNames) ->
    disabledPackages = config.get("core.disabledPackages") ? []
    for packageName in packageNames
      continue if _.contains disabledPackages, packageName
      atom.loadPackage(packageName)

  get: (keyPath) ->
    keys = @keysForKeyPath(keyPath)
    value = @settings
    for key in keys
      break unless value = value[key]
    value

  set: (keyPath, value) ->
    keys = @keysForKeyPath(keyPath)
    hash = @settings
    while keys.length > 1
      key = keys.shift()
      hash[key] ?= {}
      hash = hash[key]
    hash[keys.shift()] = value

    @update()
    value

  setDefaults: (keyPath, defaults) ->
    keys = @keysForKeyPath(keyPath)
    hash = @settings
    for key in keys
      hash[key] ?= {}
      hash = hash[key]

    _.defaults hash, defaults
    @update()

  keysForKeyPath: (keyPath) ->
    if typeof keyPath is 'string'
      keyPath.split(".")
    else
      new Array(keyPath...)

  observe: (keyPath, callback) ->
    value = @get(keyPath)
    previousValue = _.clone(value)
    updateCallback = =>
      value = @get(keyPath)
      unless _.isEqual(value, previousValue)
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
    fs.write(configJsonPath, JSON.stringify(@settings, undefined, 2) + "\n")

  requireUserInitScript: ->
    try
      require userInitScriptPath if fs.exists(userInitScriptPath)
    catch error
      console.error "Failed to load `#{userInitScriptPath}`", error.stack, error

  isTextMateBundle: (packageName) ->
    /(\.|_)tmbundle$/.test(packageName)

_.extend Config.prototype, EventEmitter
