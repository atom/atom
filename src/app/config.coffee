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

# Public: Handles all of Atom's configuration details.
#
# This includes loading and setting default options, as well as reading from the
# user's configuration file. 
module.exports =
class Config
  configDirPath: configDirPath
  themeDirPaths: [userThemesDirPath, bundledThemesDirPath, vendoredThemesDirPath]
  packageDirPaths: [userPackagesDirPath, vendoredPackagesDirPath, bundledPackagesDirPath]
  userPackagesDirPath: userPackagesDirPath
  defaultSettings: null
  settings: null
  configFileHasErrors: null

  # Internal:
  constructor: ->
    @defaultSettings =
      core: _.clone(require('root-view').configDefaults)
      editor: _.clone(require('editor').configDefaults)
    @settings = {}
    @configFilePath = fsUtils.resolve(configDirPath, 'config', ['json', 'cson'])
    @configFilePath ?= fsUtils.join(configDirPath, 'config.cson')

  # Internal:
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

  # Internal:
  load: ->
    @initializeConfigDirectory()
    @loadUserConfig()

  # Internal:
  loadUserConfig: ->
    if fsUtils.exists(@configFilePath)
      try
        userConfig = CSON.readObject(@configFilePath)
        _.extend(@settings, userConfig)
      catch e
        @configFileHasErrors = true
        console.error "Failed to load user config '#{@configFilePath}'", e.message
        console.error e.stack

  # Public: Retrieves the setting for the given key.
  #
  # keyPath - The {String} name of the key to retrieve
  #
  # Returns the value from Atom's default settings, the user's configuration file,
  # or `null` if the key doesn't exist in either. 
  get: (keyPath) ->
    _.valueForKeyPath(@settings, keyPath) ?
      _.valueForKeyPath(@defaultSettings, keyPath)

  # Public: Sets the value for a configuration setting.
  #
  # This value is stored in Atom's internal configuration file. 
  #
  # keyPath - The {String} name of the key
  # value - The value of the setting
  #
  # Returns the `value`.
  set: (keyPath, value) ->
    _.setValueForKeyPath(@settings, keyPath, value)
    @update()
    value

  #  Internal:
  setDefaults: (keyPath, defaults) ->
    keys = keyPath.split('.')
    hash = @defaultSettings
    for key in keys
      hash[key] ?= {}
      hash = hash[key]

    _.extend hash, defaults
    @update()

  # Public: Establishes an event listener for a given key.
  #
  # Whenever the value of the key is changed, a callback is fired.
  #
  # keyPath - The {String} name of the key to watch
  # callback - The {Function} that fires when the. It is given a single argument, `value`,
  #            which is the new value of `keyPath`.
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

  # Internal:
  update: ->
    return if @configFileHasErrors
    @save()
    @trigger 'updated'

  # Internal:
  save: ->
    CSON.writeObject(@configFilePath, @settings)

_.extend Config.prototype, EventEmitter
