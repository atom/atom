fs = require 'fs'
_ = nodeRequire 'underscore'
EventEmitter = require 'event-emitter'
CSON = require 'cson'

configDirPath = fs.absolute("~/.atom")
bundledPackagesDirPath = fs.join(resourcePath, "src/packages")
bundledThemesDirPath = fs.join(resourcePath, "themes")
vendoredPackagesDirPath = fs.join(resourcePath, "vendor/packages")
vendoredThemesDirPath = fs.join(resourcePath, "vendor/themes")
userThemesDirPath = fs.join(configDirPath, "themes")
userPackagesDirPath = fs.join(configDirPath, "packages")

require.paths.unshift userPackagesDirPath

module.exports =
class Config
  configDirPath: configDirPath
  themeDirPaths: [userThemesDirPath, bundledThemesDirPath, vendoredThemesDirPath]
  packageDirPaths: [userPackagesDirPath, vendoredPackagesDirPath, bundledPackagesDirPath]
  userPackagesDirPath: userPackagesDirPath
  defaultSettings: null
  settings: null

  constructor: ->
    @defaultSettings =
      core: _.clone(require('root-view').configDefaults)
      editor: _.clone(require('editor').configDefaults)
    @settings = {}
    @configFilePath = fs.resolve(configDirPath, 'config', ['json', 'cson'])
    @configFilePath ?= fs.join(configDirPath, 'config.cson')

  initializeConfigDirectory: ->
    return if fs.exists(@configDirPath)

    fs.makeDirectory(@configDirPath)

    templateConfigDirPath = fs.resolve(window.resourcePath, 'dot-atom')

    onConfigDirFile = (path) =>
      templatePath = fs.join(templateConfigDirPath, path)
      configPath = fs.join(@configDirPath, path)
      fs.write(configPath, fs.read(templatePath))
    fs.traverseTree(templateConfigDirPath, onConfigDirFile, (path) -> true)

    configThemeDirPath = fs.join(@configDirPath, 'themes')
    onThemeDirFile = (path) ->
      templatePath = fs.join(bundledThemesDirPath, path)
      configPath = fs.join(configThemeDirPath, path)
      fs.write(configPath, fs.read(templatePath))
    fs.traverseTree(bundledThemesDirPath, onThemeDirFile, (path) -> true)

  load: ->
    @initializeConfigDirectory()
    @loadUserConfig()

  loadUserConfig: ->
    if fs.exists(@configFilePath)
      userConfig = CSON.readObject(@configFilePath)
      _.extend(@settings, userConfig)

  get: (keyPath) ->
    _.valueForKeyPath(@settings, keyPath) ?
      _.valueForKeyPath(@defaultSettings, keyPath)

  set: (keyPath, value) ->
    _.setValueForKeyPath(@settings, keyPath, value)
    @update()
    value

  setDefaults: (keyPath, defaults) ->
    keys = keyPath.split('.')
    hash = @defaultSettings
    for key in keys
      hash[key] ?= {}
      hash = hash[key]

    _.extend hash, defaults
    @update()

  observe: (keyPath, callback) ->
    value = @get(keyPath)
    previousValue = _.clone(value)
    updateCallback = =>
      value = @get(keyPath)
      unless _.isEqual(value, previousValue)
        previousValue = _.clone(value)
        callback(value)

    subscription = { cancel: => @off 'updated', updateCallback  }
    @on 'updated', updateCallback
    callback(value)
    subscription

  update: ->
    @save()
    @trigger 'updated'

  save: ->
    CSON.writeObject(@configFilePath, @settings)

_.extend Config.prototype, EventEmitter
