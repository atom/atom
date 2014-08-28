_ = require 'underscore-plus'
fs = require 'fs-plus'
{Emitter} = require 'emissary'
CSON = require 'season'
path = require 'path'
async = require 'async'
pathWatcher = require 'pathwatcher'

# Public: Used to access all of Atom's configuration details.
#
# An instance of this class is always available as the `atom.config` global.
#
# ## Best practices
#
# * Create your own root keypath using your package's name.
# * Don't depend on (or write to) configuration keys outside of your keypath.
#
# ## Examples
#
# ```coffee
# atom.config.set('my-package.key', 'value')
# atom.config.observe 'my-package.key', ->
#   console.log 'My configuration changed:', atom.config.get('my-package.key')
# ```
module.exports =
class Config
  Emitter.includeInto(this)

  # Created during initialization, available as `atom.config`
  constructor: ({@configDirPath, @resourcePath}={}) ->
    @defaultSettings = {}
    @settings = {}
    @configFileHasErrors = false
    @configFilePath = fs.resolve(@configDirPath, 'config', ['json', 'cson'])
    @configFilePath ?= path.join(@configDirPath, 'config.cson')

  initializeConfigDirectory: (done) ->
    return if fs.existsSync(@configDirPath)

    fs.makeTreeSync(@configDirPath)

    queue = async.queue ({sourcePath, destinationPath}, callback) ->
      fs.copy(sourcePath, destinationPath, callback)
    queue.drain = done

    templateConfigDirPath = fs.resolve(@resourcePath, 'dot-atom')
    onConfigDirFile = (sourcePath) =>
      relativePath = sourcePath.substring(templateConfigDirPath.length + 1)
      destinationPath = path.join(@configDirPath, relativePath)
      queue.push({sourcePath, destinationPath})
    fs.traverseTree(templateConfigDirPath, onConfigDirFile, (path) -> true)

  load: ->
    @initializeConfigDirectory()
    @loadUserConfig()
    @observeUserConfig()

  loadUserConfig: ->
    unless fs.existsSync(@configFilePath)
      fs.makeTreeSync(path.dirname(@configFilePath))
      CSON.writeFileSync(@configFilePath, {})

    try
      userConfig = CSON.readFileSync(@configFilePath)
      _.extend(@settings, userConfig)
      @configFileHasErrors = false
      @emit 'updated'
    catch e
      @configFileHasErrors = true
      console.error "Failed to load user config '#{@configFilePath}'", e.message
      console.error e.stack

  observeUserConfig: ->
    @watchSubscription ?= pathWatcher.watch @configFilePath, (eventType) =>
      @loadUserConfig() if eventType is 'change' and @watchSubscription?

  unobserveUserConfig: ->
    @watchSubscription?.close()
    @watchSubscription = null

  setDefaults: (keyPath, defaults) ->
    keys = keyPath.split('.')
    hash = @defaultSettings
    for key in keys
      hash[key] ?= {}
      hash = hash[key]

    _.extend hash, defaults
    @emit 'updated'

  # Extended: Get the {String} path to the config file being used.
  getUserConfigPath: ->
    @configFilePath

  # Extended: Returns a new {Object} containing all of settings and defaults.
  getSettings: ->
    _.deepExtend(@settings, @defaultSettings)

  # Essential: Retrieves the setting for the given key.
  #
  # * `keyPath` The {String} name of the key to retrieve.
  #
  # Returns the value from Atom's default settings, the user's configuration
  # file, or `null` if the key doesn't exist in either.
  get: (keyPath) ->
    value = _.valueForKeyPath(@settings, keyPath)
    defaultValue = _.valueForKeyPath(@defaultSettings, keyPath)

    if value?
      value = _.deepClone(value)
      valueIsObject = _.isObject(value) and not _.isArray(value)
      defaultValueIsObject = _.isObject(defaultValue) and not _.isArray(defaultValue)
      if valueIsObject and defaultValueIsObject
        _.defaults(value, defaultValue)
    else
      value = _.deepClone(defaultValue)

    value

  # Extended: Retrieves the setting for the given key as an integer.
  #
  # * `keyPath` The {String} name of the key to retrieve
  #
  # Returns the value from Atom's default settings, the user's configuration
  # file, or `NaN` if the key doesn't exist in either.
  getInt: (keyPath) ->
    parseInt(@get(keyPath))

  # Extended: Retrieves the setting for the given key as a positive integer.
  #
  # * `keyPath` The {String} name of the key to retrieve
  # * `defaultValue` The integer {Number} to fall back to if the value isn't
  #                positive, defaults to 0.
  #
  # Returns the value from Atom's default settings, the user's configuration
  # file, or `defaultValue` if the key value isn't greater than zero.
  getPositiveInt: (keyPath, defaultValue=0) ->
    Math.max(@getInt(keyPath), 0) or defaultValue

  # Essential: Sets the value for a configuration setting.
  #
  # This value is stored in Atom's internal configuration file.
  #
  # * `keyPath` The {String} name of the key.
  # * `value` The value of the setting.
  #
  # Returns the `value`.
  set: (keyPath, value) ->
    if @get(keyPath) isnt value
      defaultValue = _.valueForKeyPath(@defaultSettings, keyPath)
      value = undefined if _.isEqual(defaultValue, value)
      _.setValueForKeyPath(@settings, keyPath, value)
      @update()
    value

  # Extended: Toggle the value at the key path.
  #
  # The new value will be `true` if the value is currently falsy and will be
  # `false` if the value is currently truthy.
  #
  # * `keyPath` The {String} name of the key.
  #
  # Returns the new value.
  toggle: (keyPath) ->
    @set(keyPath, !@get(keyPath))

  # Extended: Restore the key path to its default value.
  #
  # * `keyPath` The {String} name of the key.
  #
  # Returns the new value.
  restoreDefault: (keyPath) ->
    @set(keyPath, _.valueForKeyPath(@defaultSettings, keyPath))

  # Extended: Get the default value of the key path.
  #
  # * `keyPath` The {String} name of the key.
  #
  # Returns the default value.
  getDefault: (keyPath) ->
    defaultValue = _.valueForKeyPath(@defaultSettings, keyPath)
    _.deepClone(defaultValue)

  # Extended: Is the key path value its default value?
  #
  # * `keyPath` The {String} name of the key.
  #
  # Returns a {Boolean}, `true` if the current value is the default, `false`
  # otherwise.
  isDefault: (keyPath) ->
    not _.valueForKeyPath(@settings, keyPath)?

  # Extended: Push the value to the array at the key path.
  #
  # * `keyPath` The {String} key path.
  # * `value` The value to push to the array.
  #
  # Returns the new array length {Number} of the setting.
  pushAtKeyPath: (keyPath, value) ->
    arrayValue = @get(keyPath) ? []
    result = arrayValue.push(value)
    @set(keyPath, arrayValue)
    result

  # Extended: Add the value to the beginning of the array at the key path.
  #
  # * `keyPath` The {String} key path.
  # * `value` The value to shift onto the array.
  #
  # Returns the new array length {Number} of the setting.
  unshiftAtKeyPath: (keyPath, value) ->
    arrayValue = @get(keyPath) ? []
    result = arrayValue.unshift(value)
    @set(keyPath, arrayValue)
    result

  # Public: Remove the value from the array at the key path.
  #
  # * `keyPath` The {String} key path.
  # * `value` The value to remove from the array.
  #
  # Returns the new array value of the setting.
  removeAtKeyPath: (keyPath, value) ->
    arrayValue = @get(keyPath) ? []
    result = _.remove(arrayValue, value)
    @set(keyPath, arrayValue)
    result

  # Essential: Add a listener for changes to a given key path.
  #
  # * `keyPath` The {String} name of the key to observe
  # * `options` An optional {Object} containing the `callNow` key.
  # * `callback` The {Function} to call when the value of the key changes.
  #              The first argument will be the new value of the key and the
  #              second argument will be an {Object} with a `previous` property
  #              that is the prior value of the key.
  #
  # Returns an {Object} with the following keys:
  #  * `off` A {Function} that unobserves the `keyPath` when called.
  observe: (keyPath, options={}, callback) ->
    if _.isFunction(options)
      callback = options
      options = {}

    value = @get(keyPath)
    previousValue = _.clone(value)
    updateCallback = =>
      value = @get(keyPath)
      unless _.isEqual(value, previousValue)
        previous = previousValue
        previousValue = _.clone(value)
        callback(value, {previous})

    eventName = "updated.#{keyPath.replace(/\./, '-')}"
    subscription = @on eventName, updateCallback
    callback(value) if options.callNow ? true
    subscription

  # Unobserve all callbacks on a given key.
  #
  # * `keyPath` The {String} name of the key to unobserve.
  unobserve: (keyPath) ->
    @off("updated.#{keyPath.replace(/\./, '-')}")

  update: ->
    return if @configFileHasErrors
    @save()
    @emit 'updated'

  save: ->
    CSON.writeFileSync(@configFilePath, @settings)
