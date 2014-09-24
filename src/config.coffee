_ = require 'underscore-plus'
fs = require 'fs-plus'
EmitterMixin = require('emissary').Emitter
{Emitter} = require 'event-kit'
CSON = require 'season'
path = require 'path'
async = require 'async'
pathWatcher = require 'pathwatcher'
{deprecate} = require 'grim'

# Essential: Used to access all of Atom's configuration details.
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
  EmitterMixin.includeInto(this)
  @typeFilters = {}

  @addTypeFilter: (typeName, filterFunction) ->
    @typeFilters[typeName] ?= []
    @typeFilters[typeName].push(filterFunction)

  @addTypeFilters: (filters) ->
    for typeName, functions of filters
      for name, filterFunction of functions
        @addTypeFilter(typeName, filterFunction)

  @executeTypeFilters: (value, schema) ->
    failedValidation = false
    types = schema.type
    types = [types] unless Array.isArray(types)
    for type in types
      try
        if filterFunctions = @typeFilters[type]
          for filter in filterFunctions
            value = filter.call(this, value, schema)
          failedValidation = false
          break
      catch e
        failedValidation = true

    throw new Error('value is not valid') if failedValidation
    value

  # Created during initialization, available as `atom.config`
  constructor: ({@configDirPath, @resourcePath}={}) ->
    @emitter = new Emitter
    @schema =
      type: 'object'
      properties: {}
    @defaultSettings = {}
    @settings = {}
    @configFileHasErrors = false
    @configFilePath = fs.resolve(@configDirPath, 'config', ['json', 'cson'])
    @configFilePath ?= path.join(@configDirPath, 'config.cson')

  ###
  Section: Config Subscription
  ###

  # Essential: Add a listener for changes to a given key path.
  #
  # * `keyPath` The {String} name of the key to observe
  # * `callback` The {Function} to call when the value of the key changes.
  #   The first argument will be the new value of the key and the
  #   second argument will be an {Object} with a `previous` property
  #   that is the prior value of the key.
  #
  # Returns a {Disposable} with the following keys on which you can call
  # `.dispose()` to unsubscribe.
  onDidChange: (keyPath, callback) ->
    value = @get(keyPath)
    previousValue = _.clone(value)
    updateCallback = =>
      value = @get(keyPath)
      unless _.isEqual(value, previousValue)
        previous = previousValue
        previousValue = _.clone(value)
        callback(value, {previous})

    @emitter.on 'did-change', updateCallback

  # Essential: Add a listener for changes to a given key path. This is different
  # than {::onDidChange} in that it will immediately call your callback with the
  # current value of the config entry.
  #
  # * `keyPath` The {String} name of the key to observe
  # * `callback` The {Function} to call when the value of the key changes.
  #   The first argument will be the new value of the key and the
  #   second argument will be an {Object} with a `previous` property
  #   that is the prior value of the key.
  #
  # Returns a {Disposable} with the following keys on which you can call
  # `.dispose()` to unsubscribe.
  observe: (keyPath, options={}, callback) ->
    if _.isFunction(options)
      callback = options
      options = {}
    else
      message = ''
      message = '`callNow` as been set to false. Use ::onDidChange instead.' if options.callNow == false
      deprecate 'Config::observe no longer supports options. #{message}'

    callback(_.clone(@get(keyPath))) unless options.callNow == false
    @onDidChange(keyPath, callback)

  ###
  Section: get / set
  ###

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

  # Essential: Sets the value for a configuration setting.
  #
  # This value is stored in Atom's internal configuration file.
  #
  # * `keyPath` The {String} name of the key.
  # * `value` The value of the setting.
  #
  # Returns a {Boolean} true if the value was set.
  set: (keyPath, value) ->
    try
      value = @scrubValue(keyPath, value)
    catch e
      return false

    if @get(keyPath) isnt value
      defaultValue = _.valueForKeyPath(@defaultSettings, keyPath)
      value = undefined if _.isEqual(defaultValue, value)
      _.setValueForKeyPath(@settings, keyPath, value)
      @update()
    true

  # Extended: Get the {String} path to the config file being used.
  getUserConfigPath: ->
    @configFilePath

  # Extended: Returns a new {Object} containing all of settings and defaults.
  getSettings: ->
    _.deepExtend(@settings, @defaultSettings)

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

  getSchema: (keyPath) ->
    keys = keyPath.split('.')
    schema = @schema
    for key in keys
      break unless schema?
      schema = schema.properties[key]
    schema

  ###
  Section: To Deprecate
  ###

  # Retrieves the setting for the given key as an integer.
  #
  # * `keyPath` The {String} name of the key to retrieve
  #
  # Returns the value from Atom's default settings, the user's configuration
  # file, or `NaN` if the key doesn't exist in either.
  getInt: (keyPath) ->
    parseInt(@get(keyPath))

  # Retrieves the setting for the given key as a positive integer.
  #
  # * `keyPath` The {String} name of the key to retrieve
  # * `defaultValue` The integer {Number} to fall back to if the value isn't
  #                positive, defaults to 0.
  #
  # Returns the value from Atom's default settings, the user's configuration
  # file, or `defaultValue` if the key value isn't greater than zero.
  getPositiveInt: (keyPath, defaultValue=0) ->
    Math.max(@getInt(keyPath), 0) or defaultValue

  # Toggle the value at the key path.
  #
  # The new value will be `true` if the value is currently falsy and will be
  # `false` if the value is currently truthy.
  #
  # * `keyPath` The {String} name of the key.
  #
  # Returns the new value.
  toggle: (keyPath) ->
    @set(keyPath, !@get(keyPath))

  ###
  Section: Deprecated
  ###

  # Unobserve all callbacks on a given key.
  # * `keyPath` The {String} name of the key to unobserve.
  #
  unobserve: (keyPath) ->
    deprecate 'Config::unobserve no longer does anything. Call `.dispose()` on the object returned by Config::observe instead.'

  # Push the value to the array at the key path.
  #
  # * `keyPath` The {String} key path.
  # * `value` The value to push to the array.
  #
  # Returns the new array length {Number} of the setting.
  pushAtKeyPath: (keyPath, value) ->
    deprecate 'Please remove from your code. Config::pushAtKeyPath is going away. Please push the value onto the array, and call Config::set'
    arrayValue = @get(keyPath) ? []
    result = arrayValue.push(value)
    @set(keyPath, arrayValue)
    result

  # Add the value to the beginning of the array at the key path.
  #
  # * `keyPath` The {String} key path.
  # * `value` The value to shift onto the array.
  #
  # Returns the new array length {Number} of the setting.
  unshiftAtKeyPath: (keyPath, value) ->
    deprecate 'Please remove from your code. Config::unshiftAtKeyPath is going away. Please unshift the value onto the array, and call Config::set'
    arrayValue = @get(keyPath) ? []
    result = arrayValue.unshift(value)
    @set(keyPath, arrayValue)
    result

  # Remove the value from the array at the key path.
  #
  # * `keyPath` The {String} key path.
  # * `value` The value to remove from the array.
  #
  # Returns the new array value of the setting.
  removeAtKeyPath: (keyPath, value) ->
    deprecate 'Please remove from your code. Config::removeAtKeyPath is going away. Please remove the value from the array, and call Config::set'
    arrayValue = @get(keyPath) ? []
    result = _.remove(arrayValue, value)
    @set(keyPath, arrayValue)
    result

  ###
  Section: Private
  ###

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
      @emitter.emit 'did-change'
    catch error
      @configFileHasErrors = true
      console.error "Failed to load user config '#{@configFilePath}'", error.message
      console.error error.stack

  observeUserConfig: ->
    try
      @watchSubscription ?= pathWatcher.watch @configFilePath, (eventType) =>
        @loadUserConfig() if eventType is 'change' and @watchSubscription?
    catch error
      console.error "Failed to watch user config '#{@configFilePath}'", error.message
      console.error error.stack

  unobserveUserConfig: ->
    @watchSubscription?.close()
    @watchSubscription = null

  update: ->
    return if @configFileHasErrors
    @save()
    @emit 'updated'
    @emitter.emit 'did-change'

  save: ->
    CSON.writeFileSync(@configFilePath, @settings)

  setDefaults: (keyPath, defaults) ->
    if typeof defaults isnt 'object'
      return _.setValueForKeyPath(@defaultSettings, keyPath, defaults)

    keys = keyPath.split('.')
    hash = @defaultSettings
    for key in keys
      hash[key] ?= {}
      hash = hash[key]

    _.extend hash, defaults
    @emit 'updated'
    @emitter.emit 'did-change'

  setSchema: (keyPath, schema) ->
    unless typeof schema is "object"
      throw new Error("Schemas can only be objects!")

    unless typeof schema.type?
      throw new Error("Schema object's must have a type attribute")

    keys = keyPath.split('.')
    rootSchema = @schema
    for key in keys
      rootSchema.type = 'object'
      rootSchema.properties ?= {}
      properties = rootSchema.properties
      properties[key] ?= {}
      rootSchema = properties[key]

    _.extend rootSchema, schema
    @setDefaults(keyPath, @extractDefaultsFromSchema(schema))

  extractDefaultsFromSchema: (schema) ->
    if schema.default?
      schema.default
    else if schema.type is 'object' and schema.properties? and typeof schema.properties is "object"
      defaults = {}
      properties = schema.properties or {}
      defaults[key] = @extractDefaultsFromSchema(value) for key, value of properties
      defaults

  scrubValue: (keyPath, value) ->
    value = @constructor.executeTypeFilters(value, schema) if schema = @getSchema(keyPath)
    value

Config.addTypeFilters
  'integer':
    coercion: (value, schema) ->
      value = parseInt(value)
      throw new Error() if isNaN(value)
      value

  'number':
    coercion: (value, schema) ->
      value = parseFloat(value)
      throw new Error() if isNaN(value)
      value

  'boolean':
    coercion: (value, schema) ->
      switch typeof value
        when 'string'
          value.toLowerCase() in ['true', 't']
        else
          !!value

  'string':
    typeCheck: (value, schema) ->
      throw new Error() if typeof value isnt 'string'
      value

  'null':
    # null sort of isnt supported. It will just unset in this case
    coercion: (value, schema) ->
      throw new Error() unless value == null
      value

  'object':
    coercion: (value, schema) ->
      throw new Error() if typeof value isnt 'object'
      return value unless schema.properties?
      for prop, childSchema of schema.properties
        value[prop] = @executeTypeFilters(value[prop], childSchema) if prop of value
      value

  'array':
    coercion: (value, schema) ->
      throw new Error() unless Array.isArray(value)
      itemSchema = schema.items
      if itemSchema?
        @executeTypeFilters(item, itemSchema) for item in value
      else
        value
