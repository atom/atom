fsUtils = require 'fs-utils'
_ = require 'underscore'
EventEmitter = require 'event-emitter'
CSON = require 'cson'

configDirPath = fsUtils.absolute("~/.atom")
bundledPackagesDirPath = fsUtils.join(resourcePath, "src/packages")
bundledThemesDirPath = fsUtils.join(resourcePath, "themes")
vendoredPackagesDirPath = fsUtils.join(resourcePath, "vendor/packages")
vendoredThemesDirPath = fsUtils.join(resourcePath, "vendor/themes")
userThemesDirPath = fsUtils.join(configDirPath, "themes")
userPackagesDirPath = fsUtils.join(configDirPath, "packages")

module.exports =
class Config
  configDirPath: configDirPath
  themeDirPaths: [userThemesDirPath, bundledThemesDirPath, vendoredThemesDirPath]
  packageDirPaths: [userPackagesDirPath, vendoredPackagesDirPath, bundledPackagesDirPath]
  userPackagesDirPath: userPackagesDirPath
  defaultSettings: null
  settings: null
  configFileHasErrors: null

  constructor: ->
    @defaultSettings =
      core: _.clone(require('root-view').configDefaults)
      editor: _.clone(require('editor').configDefaults)
    @settings = {}
    @configFilePath = fsUtils.resolve(configDirPath, 'config', ['json', 'cson'])
    @configFilePath ?= fsUtils.join(configDirPath, 'config.cson')

  initializeConfigDirectory: ->
    return if fsUtils.exists(@configDirPath)

    fsUtils.makeDirectory(@configDirPath)

    templateConfigDirPath = fsUtils.resolve(window.resourcePath, 'dot-atom')
    onConfigDirFile = (path) =>
      relativePath = path.substring(templateConfigDirPath.length + 1)
      configPath = fsUtils.join(@configDirPath, relativePath)
      fsUtils.write(configPath, fsUtils.read(path))
    fsUtils.traverseTreeSync(templateConfigDirPath, onConfigDirFile, (path) -> true)

    configThemeDirPath = fsUtils.join(@configDirPath, 'themes')
    onThemeDirFile = (path) ->
      relativePath = path.substring(bundledThemesDirPath.length + 1)
      configPath = fsUtils.join(configThemeDirPath, relativePath)
      fsUtils.write(configPath, fsUtils.read(path))
    fsUtils.traverseTreeSync(bundledThemesDirPath, onThemeDirFile, (path) -> true)

  load: ->
    @initializeConfigDirectory()
    @loadUserConfig()

  loadUserConfig: ->
    if fsUtils.exists(@configFilePath)
      try
        userConfig = CSON.readObject(@configFilePath)
        _.extend(@settings, userConfig)
      catch e
        @configFileHasErrors = true
        console.error "Failed to load user config '#{@configFilePath}'", e.message
        console.error e.stack

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
    return if @configFileHasErrors
    @save()
    @trigger 'updated'

  save: ->
    CSON.writeObject(@configFilePath, @settings)

_.extend Config.prototype, EventEmitter
