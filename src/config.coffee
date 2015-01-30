_ = require 'underscore-plus'
fs = require 'fs-plus'
EmitterMixin = require('emissary').Emitter
{CompositeDisposable, Disposable, Emitter} = require 'event-kit'
CSON = require 'season'
path = require 'path'
async = require 'async'
pathWatcher = require 'pathwatcher'
Grim = require 'grim'

Color = require './color'
ScopedPropertyStore = require 'scoped-property-store'
ScopeDescriptor = require './scope-descriptor'

# Essential: Used to access all of Atom's configuration details.
#
# An instance of this class is always available as the `atom.config` global.
#
# ## Getting and setting config settings.
#
# ```coffee
# # Note that with no value set, ::get returns the setting's default value.
# atom.config.get('my-package.myKey') # -> 'defaultValue'
#
# atom.config.set('my-package.myKey', 'value')
# atom.config.get('my-package.myKey') # -> 'value'
# ```
#
# You may want to watch for changes. Use {::observe} to catch changes to the setting.
#
# ```coffee
# atom.config.set('my-package.myKey', 'value')
# atom.config.observe 'my-package.myKey', (newValue) ->
#   # `observe` calls immediately and every time the value is changed
#   console.log 'My configuration changed:', newValue
# ```
#
# If you want a notification only when the value changes, use {::onDidChange}.
#
# ```coffee
# atom.config.onDidChange 'my-package.myKey', ({newValue, oldValue}) ->
#   console.log 'My configuration changed:', newValue, oldValue
# ```
#
# ### Value Coercion
#
# Config settings each have a type specified by way of a
# [schema](json-schema.org). For example we might an integer setting that only
# allows integers greater than `0`:
#
# ```coffee
# # When no value has been set, `::get` returns the setting's default value
# atom.config.get('my-package.anInt') # -> 12
#
# # The string will be coerced to the integer 123
# atom.config.set('my-package.anInt', '123')
# atom.config.get('my-package.anInt') # -> 123
#
# # The string will be coerced to an integer, but it must be greater than 0, so is set to 1
# atom.config.set('my-package.anInt', '-20')
# atom.config.get('my-package.anInt') # -> 1
# ```
#
# ## Defining settings for your package
#
# Define a schema under a `config` key in your package main.
#
# ```coffee
# module.exports =
#   # Your config schema
#   config:
#     someInt:
#       type: 'integer'
#       default: 23
#       minimum: 1
#
#   activate: (state) -> # ...
#   # ...
# ```
#
# See [Creating a Package](https://atom.io/docs/latest/creating-a-package) for
# more info.
#
# ## Config Schemas
#
# We use [json schema](json-schema.org) which allows you to define your value's
# default, the type it should be, etc. A simple example:
#
# ```coffee
# # We want to provide an `enableThing`, and a `thingVolume`
# config:
#   enableThing:
#     type: 'boolean'
#     default: false
#   thingVolume:
#     type: 'integer'
#     default: 5
#     minimum: 1
#     maximum: 11
# ```
#
# The type keyword allows for type coercion and validation. If a `thingVolume` is
# set to a string `'10'`, it will be coerced into an integer.
#
# ```coffee
# atom.config.set('my-package.thingVolume', '10')
# atom.config.get('my-package.thingVolume') # -> 10
#
# # It respects the min / max
# atom.config.set('my-package.thingVolume', '400')
# atom.config.get('my-package.thingVolume') # -> 11
#
# # If it cannot be coerced, the value will not be set
# atom.config.set('my-package.thingVolume', 'cats')
# atom.config.get('my-package.thingVolume') # -> 11
# ```
#
# ### Supported Types
#
# The `type` keyword can be a string with any one of the following. You can also
# chain them by specifying multiple in an an array. For example
#
# ```coffee
# config:
#   someSetting:
#     type: ['boolean', 'integer']
#     default: 5
#
# # Then
# atom.config.set('my-package.someSetting', 'true')
# atom.config.get('my-package.someSetting') # -> true
#
# atom.config.set('my-package.someSetting', '12')
# atom.config.get('my-package.someSetting') # -> 12
# ```
#
# #### string
#
# Values must be a string.
#
# ```coffee
# config:
#   someSetting:
#     type: 'string'
#     default: 'hello'
# ```
#
# #### integer
#
# Values will be coerced into integer. Supports the (optional) `minimum` and
# `maximum` keys.
#
#   ```coffee
#   config:
#     someSetting:
#       type: 'integer'
#       default: 5
#       minimum: 1
#       maximum: 11
#   ```
#
# #### number
#
# Values will be coerced into a number, including real numbers. Supports the
# (optional) `minimum` and `maximum` keys.
#
# ```coffee
# config:
#   someSetting:
#     type: 'number'
#     default: 5.3
#     minimum: 1.5
#     maximum: 11.5
# ```
#
# #### boolean
#
# Values will be coerced into a Boolean. `'true'` and `'false'` will be coerced into
# a boolean. Numbers, arrays, objects, and anything else will not be coerced.
#
# ```coffee
# config:
#   someSetting:
#     type: 'boolean'
#     default: false
# ```
#
# #### array
#
# Value must be an Array. The types of the values can be specified by a
# subschema in the `items` key.
#
# ```coffee
# config:
#   someSetting:
#     type: 'array'
#     default: [1, 2, 3]
#     items:
#       type: 'integer'
#       minimum: 1.5
#       maximum: 11.5
# ```
#
# #### object
#
# Value must be an object. This allows you to nest config options. Sub options
# must be under a `properties key`
#
# ```coffee
# config:
#   someSetting:
#     type: 'object'
#     properties:
#       myChildIntOption:
#         type: 'integer'
#         minimum: 1.5
#         maximum: 11.5
# ```
#
# #### color
#
# Values will be coerced into a {Color} with `red`, `green`, `blue`, and `alpha`
# properties that all have numeric values. `red`, `green`, `blue` will be in
# the range 0 to 255 and `value` will be in the range 0 to 1. Values can be any
# valid CSS color format such as `#abc`, `#abcdef`, `white`,
# `rgb(50, 100, 150)`, and `rgba(25, 75, 125, .75)`.
#
# ```coffee
# config:
#   someSetting:
#     type: 'color'
#     default: 'white'
# ```
#
# ### Other Supported Keys
#
# #### enum
#
# All types support an `enum` key. The enum key lets you specify all values
# that the config setting can possibly be. `enum` _must_ be an array of values
# of your specified type. Schema:
#
# ```coffee
# config:
#   someSetting:
#     type: 'integer'
#     default: 4
#     enum: [2, 4, 6, 8]
# ```
#
# Usage:
#
# ```coffee
# atom.config.set('my-package.someSetting', '2')
# atom.config.get('my-package.someSetting') # -> 2
#
# # will not set values outside of the enum values
# atom.config.set('my-package.someSetting', '3')
# atom.config.get('my-package.someSetting') # -> 2
#
# # If it cannot be coerced, the value will not be set
# atom.config.set('my-package.someSetting', '4')
# atom.config.get('my-package.someSetting') # -> 4
# ```
#
# #### title and description
#
# The settings view will use the `title` and `description` keys to display your
# config setting in a readable way. By default the settings view humanizes your
# config key, so `someSetting` becomes `Some Setting`. In some cases, this is
# confusing for users, and a more descriptive title is useful.
#
# Descriptions will be displayed below the title in the settings view.
#
# ```coffee
# config:
#   someSetting:
#     title: 'Setting Magnitude'
#     description: 'This will affect the blah and the other blah'
#     type: 'integer'
#     default: 4
# ```
#
# __Note__: You should strive to be so clear in your naming of the setting that
# you do not need to specify a title or description!
#
# ## Best practices
#
# * Don't depend on (or write to) configuration keys outside of your keypath.
#
module.exports =
class Config
  EmitterMixin.includeInto(this)
  @schemaEnforcers = {}

  @addSchemaEnforcer: (typeName, enforcerFunction) ->
    @schemaEnforcers[typeName] ?= []
    @schemaEnforcers[typeName].push(enforcerFunction)

  @addSchemaEnforcers: (filters) ->
    for typeName, functions of filters
      for name, enforcerFunction of functions
        @addSchemaEnforcer(typeName, enforcerFunction)

  @executeSchemaEnforcers: (keyPath, value, schema) ->
    error = null
    types = schema.type
    types = [types] unless Array.isArray(types)
    for type in types
      try
        enforcerFunctions = @schemaEnforcers[type].concat(@schemaEnforcers['*'])
        for enforcer in enforcerFunctions
          # At some point in one's life, one must call upon an enforcer.
          value = enforcer.call(this, keyPath, value, schema)
        error = null
        break
      catch e
        error = e

    throw error if error?
    value

  # Created during initialization, available as `atom.config`
  constructor: ({@configDirPath, @resourcePath}={}) ->
    @emitter = new Emitter
    @schema =
      type: 'object'
      properties: {}
    @defaultSettings = {}
    @settings = {}
    @scopedSettingsStore = new ScopedPropertyStore
    @configFileHasErrors = false
    @configFilePath = fs.resolve(@configDirPath, 'config', ['json', 'cson'])
    @configFilePath ?= path.join(@configDirPath, 'config.cson')
    @transactDepth = 0

    @debouncedSave = _.debounce(@save, 100)
    @debouncedLoad = _.debounce(@loadUserConfig, 100)

  ###
  Section: Config Subscription
  ###

  # Essential: Add a listener for changes to a given key path. This is different
  # than {::onDidChange} in that it will immediately call your callback with the
  # current value of the config entry.
  #
  # ### Examples
  #
  # You might want to be notified when the themes change. We'll watch
  # `core.themes` for changes
  #
  # ```coffee
  # atom.config.observe 'core.themes', (value) ->
  #   # do stuff with value
  # ```
  #
  # * `keyPath` {String} name of the key to observe
  # * `options` {Object}
  #   * `scopeDescriptor` (optional) {ScopeDescriptor} describing a path from
  #     the root of the syntax tree to a token. Get one by calling
  #     {editor.getLastCursor().getScopeDescriptor()}. See {::get} for examples.
  #     See [the scopes docs](https://atom.io/docs/latest/advanced/scopes-and-scope-descriptors)
  #     for more information.
  # * `callback` {Function} to call when the value of the key changes.
  #   * `value` the new value of the key
  #
  # Returns a {Disposable} with the following keys on which you can call
  # `.dispose()` to unsubscribe.
  observe: ->
    if arguments.length is 2
      [keyPath, callback] = arguments
    else if arguments.length is 3 and (_.isArray(arguments[0]) or arguments[0] instanceof ScopeDescriptor)
      Grim.deprecate """
        Passing a scope descriptor as the first argument to Config::observe is deprecated.
        Pass a `scope` in an options hash as the third argument instead.
      """
      [scopeDescriptor, keyPath, callback] = arguments
    else if arguments.length is 3 and (_.isString(arguments[0]) and _.isObject(arguments[1]))
      [keyPath, options, callback] = arguments
      scopeDescriptor = options.scope
      if options.callNow?
        Grim.deprecate """
          Config::observe no longer takes a `callNow` option. Use ::onDidChange instead.
          Note that ::onDidChange passes its callback different arguments.
          See https://atom.io/docs/api/latest/Config
        """
    else
      console.error 'An unsupported form of Config::observe is being used. See https://atom.io/docs/api/latest/Config for details'
      return

    if scopeDescriptor?
      @observeScopedKeyPath(scopeDescriptor, keyPath, callback)
    else
      @observeKeyPath(keyPath, options ? {}, callback)

  # Essential: Add a listener for changes to a given key path. If `keyPath` is
  # not specified, your callback will be called on changes to any key.
  #
  # * `keyPath` (optional) {String} name of the key to observe. Must be
  #   specified if `scopeDescriptor` is specified.
  # * `optional` (optional) {Object}
  #   * `scopeDescriptor` (optional) {ScopeDescriptor} describing a path from
  #     the root of the syntax tree to a token. Get one by calling
  #     {editor.getLastCursor().getScopeDescriptor()}. See {::get} for examples.
  #     See [the scopes docs](https://atom.io/docs/latest/advanced/scopes-and-scope-descriptors)
  #     for more information.
  # * `callback` {Function} to call when the value of the key changes.
  #   * `event` {Object}
  #     * `newValue` the new value of the key
  #     * `oldValue` the prior value of the key.
  #     * `keyPath` the keyPath of the changed key
  #
  # Returns a {Disposable} with the following keys on which you can call
  # `.dispose()` to unsubscribe.
  onDidChange: ->
    if arguments.length is 1
      [callback] = arguments
    else if arguments.length is 2
      [keyPath, callback] = arguments
    else if _.isArray(arguments[0]) or arguments[0] instanceof ScopeDescriptor
      Grim.deprecate """
        Passing a scope descriptor as the first argument to Config::onDidChange is deprecated.
        Pass a `scope` in an options hash as the third argument instead.
      """
      [scopeDescriptor, keyPath, callback] = arguments
    else
      [keyPath, options, callback] = arguments
      scopeDescriptor = options.scope

    if scopeDescriptor?
      @onDidChangeScopedKeyPath(scopeDescriptor, keyPath, callback)
    else
      @onDidChangeKeyPath(keyPath, callback)

  ###
  Section: Managing Settings
  ###

  # Essential: Retrieves the setting for the given key.
  #
  # ### Examples
  #
  # You might want to know what themes are enabled, so check `core.themes`
  #
  # ```coffee
  # atom.config.get('core.themes')
  # ```
  #
  # With scope descriptors you can get settings within a specific editor
  # scope. For example, you might want to know `editor.tabLength` for ruby
  # files.
  #
  # ```coffee
  # atom.config.get('editor.tabLength', scope: ['source.ruby']) # => 2
  # ```
  #
  # This setting in ruby files might be different than the global tabLength setting
  #
  # ```coffee
  # atom.config.get('editor.tabLength') # => 4
  # atom.config.get('editor.tabLength', scope: ['source.ruby']) # => 2
  # ```
  #
  # You can get the language scope descriptor via
  # {TextEditor::getRootScopeDescriptor}. This will get the setting specifically
  # for the editor's language.
  #
  # ```coffee
  # atom.config.get('editor.tabLength', scope: @editor.getRootScopeDescriptor()) # => 2
  # ```
  #
  # Additionally, you can get the setting at the specific cursor position.
  #
  # ```coffee
  # scopeDescriptor = @editor.getLastCursor().getScopeDescriptor()
  # atom.config.get('editor.tabLength', scope: scopeDescriptor) # => 2
  # ```
  #
  # * `keyPath` The {String} name of the key to retrieve.
  # * `options` (optional) {Object}
  #   * `sources` (optional) {Array} of {String} source names. If provided, only
  #     values that were associated with these sources during {::set} will be used.
  #   * `excludeSources` (optional) {Array} of {String} source names. If provided,
  #     values that  were associated with these sources during {::set} will not
  #     be used.
  #   * `scope` (optional) {ScopeDescriptor} describing a path from
  #     the root of the syntax tree to a token. Get one by calling
  #     {editor.getLastCursor().getScopeDescriptor()}
  #     See [the scopes docs](https://atom.io/docs/latest/advanced/scopes-and-scope-descriptors)
  #     for more information.
  #
  # Returns the value from Atom's default settings, the user's configuration
  # file in the type specified by the configuration schema.
  get: ->
    if arguments.length > 1
      if typeof arguments[0] is 'string' or not arguments[0]?
        [keyPath, options] = arguments
        {scope} = options
      else
        Grim.deprecate """
          Passing a scope descriptor as the first argument to Config::get is deprecated.
          Pass a `scope` in an options hash as the final argument instead.
        """
        [scope, keyPath] = arguments
    else
      [keyPath] = arguments

    if scope?
      value = @getRawScopedValue(scope, keyPath, options)
      value ? @getRawValue(keyPath, options)
    else
      @getRawValue(keyPath, options)

  # Extended: Get all of the values for the given key-path, along with their
  # associated scope selector.
  #
  # * `keyPath` The {String} name of the key to retrieve
  # * `options` (optional) {Object} see the `options` argument to {::get}
  #
  # Returns an {Array} of {Object}s with the following keys:
  #  * `scopeSelector` The scope-selector {String} with which the value is associated
  #  * `value` The value for the key-path
  getAll: (keyPath, options) ->
    {scope, sources} = options if options?
    result = []

    if scope?
      scopeDescriptor = ScopeDescriptor.fromObject(scope)
      result = result.concat @scopedSettingsStore.getAll(scopeDescriptor.getScopeChain(), keyPath, options)

    if globalValue = @getRawValue(keyPath, options)
      result.push(scopeSelector: '*', value: globalValue)

    result

  # Essential: Sets the value for a configuration setting.
  #
  # This value is stored in Atom's internal configuration file.
  #
  # ### Examples
  #
  # You might want to change the themes programmatically:
  #
  # ```coffee
  # atom.config.set('core.themes', ['atom-light-ui', 'atom-light-syntax'])
  # ```
  #
  # You can also set scoped settings. For example, you might want change the
  # `editor.tabLength` only for ruby files.
  #
  # ```coffee
  # atom.config.get('editor.tabLength') # => 4
  # atom.config.get('editor.tabLength', scope: ['source.ruby']) # => 4
  # atom.config.get('editor.tabLength', scope: ['source.js']) # => 4
  #
  # # Set ruby to 2
  # atom.config.set('editor.tabLength', 2, scopeSelector: 'source.ruby') # => true
  #
  # # Notice it's only set to 2 in the case of ruby
  # atom.config.get('editor.tabLength') # => 4
  # atom.config.get('editor.tabLength', scope: ['source.ruby']) # => 2
  # atom.config.get('editor.tabLength', scope: ['source.js']) # => 4
  # ```
  #
  # * `keyPath` The {String} name of the key.
  # * `value` The value of the setting. Passing `undefined` will revert the
  #   setting to the default value.
  # * `options` (optional) {Object}
  #   * `scopeSelector` (optional) {String}. eg. '.source.ruby'
  #     See [the scopes docs](https://atom.io/docs/latest/advanced/scopes-and-scope-descriptors)
  #     for more information.
  #   * `source` (optional) {String} The name of a file with which the setting
  #     is associated. Defaults to the user's config file.
  #
  # Returns a {Boolean}
  # * `true` if the value was set.
  # * `false` if the value was not able to be coerced to the type specified in the setting's schema.
  set: ->
    if arguments[0]?[0] is '.'
      Grim.deprecate """
        Passing a scope selector as the first argument to Config::set is deprecated.
        Pass a `scopeSelector` in an options hash as the final argument instead.
      """
      [scopeSelector, keyPath, value] = arguments
      shouldSave = true
    else
      [keyPath, value, options] = arguments
      scopeSelector = options?.scopeSelector
      source = options?.source
      shouldSave = options?.save ? true

    if source and not scopeSelector
      throw new Error("::set with a 'source' and no 'sourceSelector' is not yet implemented!")

    source ?= @getUserConfigPath()

    unless value is undefined
      try
        value = @makeValueConformToSchema(keyPath, value)
      catch e
        return false

    if scopeSelector?
      @setRawScopedValue(keyPath, value, source, scopeSelector)
    else
      @setRawValue(keyPath, value)

    @debouncedSave() if source is @getUserConfigPath() and shouldSave and not @configFileHasErrors
    true

  # Essential: Restore the setting at `keyPath` to its default value.
  #
  # * `keyPath` The {String} name of the key.
  # * `options` (optional) {Object}
  #   * `scopeSelector` (optional) {String}. See {::set}
  #   * `source` (optional) {String}. See {::set}
  unset: (keyPath, options) ->
    if typeof options is 'string'
      Grim.deprecate """
        Passing a scope selector as the first argument to Config::unset is deprecated.
        Pass a `scopeSelector` in an options hash as the second argument instead.
      """
      scopeSelector = keyPath
      keyPath = options
    else
      {scopeSelector, source} = options ? {}

    source ?= @getUserConfigPath()

    if scopeSelector?
      if keyPath?
        settings = @scopedSettingsStore.propertiesForSourceAndSelector(source, scopeSelector)
        if _.valueForKeyPath(settings, keyPath)?
          @scopedSettingsStore.removePropertiesForSourceAndSelector(source, scopeSelector)
          _.setValueForKeyPath(settings, keyPath, undefined)
          settings = withoutEmptyObjects(settings)
          @set(null, settings, {scopeSelector, source, priority: @priorityForSource(source)}) if settings?
          @debouncedSave()
      else
        @scopedSettingsStore.removePropertiesForSourceAndSelector(source, scopeSelector)
        @emitChangeEvent()
    else
      for scopeSelector of @scopedSettingsStore.propertiesForSource(source)
        @unset(keyPath, {scopeSelector, source})
      if keyPath? and source is @getUserConfigPath()
        @set(keyPath, _.valueForKeyPath(@defaultSettings, keyPath))

  # Extended: Get an {Array} of all of the `source` {String}s with which
  # settings have been added via {::set}.
  getSources: ->
    _.uniq(_.pluck(@scopedSettingsStore.propertySets, 'source')).sort()

  # Deprecated: Restore the global setting at `keyPath` to its default value.
  #
  # Returns the new value.
  restoreDefault: (scopeSelector, keyPath) ->
    Grim.deprecate("Use ::unset instead.")
    @unset(scopeSelector, keyPath)
    @get(keyPath)

  # Deprecated: Get the global default value of the key path. _Please note_ that in most
  # cases calling this is not necessary! {::get} returns the default value when
  # a custom value is not specified.
  #
  # * `scopeSelector` (optional) {String}. eg. '.source.ruby'
  # * `keyPath` The {String} name of the key.
  #
  # Returns the default value.
  getDefault: ->
    Grim.deprecate("Use `::get(keyPath, {scope, excludeSources: [atom.config.getUserConfigPath()]})` instead")
    if arguments.length is 1
      [keyPath] = arguments
    else
      [scopeSelector, keyPath] = arguments
      scope = [scopeSelector]
    @get(keyPath, {scope, excludeSources: [@getUserConfigPath()]})

  # Deprecated: Is the value at `keyPath` its default value?
  #
  # * `scopeSelector` (optional) {String}. eg. '.source.ruby'
  # * `keyPath` The {String} name of the key.
  #
  # Returns a {Boolean}, `true` if the current value is the default, `false`
  # otherwise.
  isDefault: ->
    Grim.deprecate("Use `not ::get(keyPath, {scope, sources: [atom.config.getUserConfigPath()]})?` instead")
    if arguments.length is 1
      [keyPath] = arguments
    else
      [scopeSelector, keyPath] = arguments
      scope = [scopeSelector]
    not @get(keyPath, {scope, sources: [@getUserConfigPath()]})?

  # Extended: Retrieve the schema for a specific key path. The schema will tell
  # you what type the keyPath expects, and other metadata about the config
  # option.
  #
  # * `keyPath` The {String} name of the key.
  #
  # Returns an {Object} eg. `{type: 'integer', default: 23, minimum: 1}`.
  # Returns `null` when the keyPath has no schema specified.
  getSchema: (keyPath) ->
    keys = splitKeyPath(keyPath)
    schema = @schema
    for key in keys
      break unless schema?
      schema = schema.properties?[key]
    schema

  # Deprecated: Returns a new {Object} containing all of the global settings and
  # defaults. Returns the scoped settings when a `scopeSelector` is specified.
  getSettings: ->
    Grim.deprecate "Use ::get(keyPath) instead"
    _.deepExtend({}, @settings, @defaultSettings)

  # Extended: Get the {String} path to the config file being used.
  getUserConfigPath: ->
    @configFilePath

  # Extended: Suppress calls to handler functions registered with {::onDidChange}
  # and {::observe} for the duration of `callback`. After `callback` executes,
  # handlers will be called once if the value for their key-path has changed.
  #
  # * `callback` {Function} to execute while suppressing calls to handlers.
  transact: (callback) ->
    @transactDepth++
    try
      callback()
    finally
      @transactDepth--
      @emitChangeEvent()

  ###
  Section: Deprecated
  ###

  getInt: (keyPath) ->
    Grim.deprecate '''Config::getInt is no longer necessary. Use ::get instead.
    Make sure the config option you are accessing has specified an `integer`
    schema. See the schema section of
    https://atom.io/docs/api/latest/Config for more info.'''
    parseInt(@get(keyPath))

  getPositiveInt: (keyPath, defaultValue=0) ->
    Grim.deprecate '''Config::getPositiveInt is no longer necessary. Use ::get instead.
    Make sure the config option you are accessing has specified an `integer`
    schema with `minimum: 1`. See the schema section of
    https://atom.io/docs/api/latest/Config for more info.'''
    Math.max(@getInt(keyPath), 0) or defaultValue

  toggle: (keyPath) ->
    Grim.deprecate 'Config::toggle is no longer supported. Please remove from your code.'
    @set(keyPath, !@get(keyPath))

  unobserve: (keyPath) ->
    Grim.deprecate 'Config::unobserve no longer does anything. Call `.dispose()` on the object returned by Config::observe instead.'

  ###
  Section: Internal methods used by core
  ###

  pushAtKeyPath: (keyPath, value) ->
    arrayValue = @get(keyPath) ? []
    result = arrayValue.push(value)
    @set(keyPath, arrayValue)
    result

  unshiftAtKeyPath: (keyPath, value) ->
    arrayValue = @get(keyPath) ? []
    result = arrayValue.unshift(value)
    @set(keyPath, arrayValue)
    result

  removeAtKeyPath: (keyPath, value) ->
    arrayValue = @get(keyPath) ? []
    result = _.remove(arrayValue, value)
    @set(keyPath, arrayValue)
    result

  setSchema: (keyPath, schema) ->
    unless isPlainObject(schema)
      throw new Error("Error loading schema for #{keyPath}: schemas can only be objects!")

    unless typeof schema.type?
      throw new Error("Error loading schema for #{keyPath}: schema objects must have a type attribute")

    rootSchema = @schema
    if keyPath
      for key in splitKeyPath(keyPath)
        rootSchema.type = 'object'
        rootSchema.properties ?= {}
        properties = rootSchema.properties
        properties[key] ?= {}
        rootSchema = properties[key]

    _.extend rootSchema, schema
    @setDefaults(keyPath, @extractDefaultsFromSchema(schema))
    @setScopedDefaultsFromSchema(keyPath, schema)
    @resetSettingsForSchemaChange()

  load: ->
    @initializeConfigDirectory()
    @loadUserConfig()
    @observeUserConfig()

  ###
  Section: Private methods managing the user's config file
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

  loadUserConfig: ->
    unless fs.existsSync(@configFilePath)
      fs.makeTreeSync(path.dirname(@configFilePath))
      CSON.writeFileSync(@configFilePath, {})

    try
      userConfig = CSON.readFileSync(@configFilePath)
      @resetUserSettings(userConfig)
      @configFileHasErrors = false
    catch error
      @configFileHasErrors = true
      message = "Failed to load `#{path.basename(@configFilePath)}`"

      detail = if error.location?
        # stack is the output from CSON in this case
        error.stack
      else
        # message will be EACCES permission denied, et al
        error.message

      @notifyFailure(message, detail)

  observeUserConfig: ->
    try
      @watchSubscription ?= pathWatcher.watch @configFilePath, (eventType) =>
        @debouncedLoad() if eventType is 'change' and @watchSubscription?
    catch error
      @notifyFailure """
        Unable to watch path: `#{path.basename(@configFilePath)}`. Make sure you have permissions to
        `#{@configFilePath}`. On linux there are currently problems with watch
        sizes. See [this document][watches] for more info.
        [watches]:https://github.com/atom/atom/blob/master/docs/build-instructions/linux.md#typeerror-unable-to-watch-path
      """

  unobserveUserConfig: ->
    @watchSubscription?.close()
    @watchSubscription = null

  notifyFailure: (errorMessage, detail) ->
    atom.notifications.addError(errorMessage, {detail, dismissable: true})

  save: ->
    allSettings = {'*': @settings}
    allSettings = _.extend allSettings, @scopedSettingsStore.propertiesForSource(@getUserConfigPath())
    CSON.writeFileSync(@configFilePath, allSettings)

  ###
  Section: Private methods managing global settings
  ###

  resetUserSettings: (newSettings) ->
    unless isPlainObject(newSettings)
      @settings = {}
      @emitChangeEvent()
      return

    if newSettings.global?
      newSettings['*'] = newSettings.global
      delete newSettings.global

    if newSettings['*']?
      scopedSettings = newSettings
      newSettings = newSettings['*']
      delete scopedSettings['*']
      @resetUserScopedSettings(scopedSettings)

    @transact =>
      @settings = {}
      @set(key, value, save: false) for key, value of newSettings

  getRawValue: (keyPath, options) ->
    unless options?.excludeSources?.indexOf(@getUserConfigPath()) >= 0
      value = _.valueForKeyPath(@settings, keyPath)
    unless options?.sources?.length > 0
      defaultValue = _.valueForKeyPath(@defaultSettings, keyPath)

    if value?
      value = @deepClone(value)
      _.defaults(value, defaultValue) if isPlainObject(value) and isPlainObject(defaultValue)
    else
      value = @deepClone(defaultValue)

    value

  setRawValue: (keyPath, value) ->
    defaultValue = _.valueForKeyPath(@defaultSettings, keyPath)
    value = undefined if _.isEqual(defaultValue, value)

    if keyPath?
      _.setValueForKeyPath(@settings, keyPath, value)
    else
      @settings = value
    @emitChangeEvent()

  observeKeyPath: (keyPath, options, callback) ->
    callback(@get(keyPath))
    @onDidChangeKeyPath keyPath, (event) -> callback(event.newValue)

  onDidChangeKeyPath: (keyPath, callback) ->
    oldValue = @get(keyPath)
    @emitter.on 'did-change', =>
      newValue = @get(keyPath)
      unless _.isEqual(oldValue, newValue)
        event = {oldValue, newValue}
        oldValue = newValue
        callback(event)

  isSubKeyPath: (keyPath, subKeyPath) ->
    return false unless keyPath? and subKeyPath?
    pathSubTokens = splitKeyPath(subKeyPath)
    pathTokens = splitKeyPath(keyPath).slice(0, pathSubTokens.length)
    _.isEqual(pathTokens, pathSubTokens)

  setRawDefault: (keyPath, value) ->
    _.setValueForKeyPath(@defaultSettings, keyPath, value)
    @emitChangeEvent()

  setDefaults: (keyPath, defaults) ->
    if defaults? and isPlainObject(defaults)
      keys = splitKeyPath(keyPath)
      for key, childValue of defaults
        continue unless defaults.hasOwnProperty(key)
        @setDefaults(keys.concat([key]).join('.'), childValue)
    else
      try
        defaults = @makeValueConformToSchema(keyPath, defaults)
        @setRawDefault(keyPath, defaults)
      catch e
        console.warn("'#{keyPath}' could not set the default. Attempted default: #{JSON.stringify(defaults)}; Schema: #{JSON.stringify(@getSchema(keyPath))}")

  deepClone: (object) ->
    if object instanceof Color
      object.clone()
    else if _.isArray(object)
      object.map (value) => @deepClone(value)
    else if isPlainObject(object)
      _.mapObject object, (key, value) => [key, @deepClone(value)]
    else
      object

  # `schema` will look something like this
  #
  # ```coffee
  # type: 'string'
  # default: 'ok'
  # scopes:
  #   '.source.js':
  #     default: 'omg'
  # ```
  setScopedDefaultsFromSchema: (keyPath, schema) ->
    if schema.scopes? and isPlainObject(schema.scopes)
      scopedDefaults = {}
      for scope, scopeSchema of schema.scopes
        continue unless scopeSchema.hasOwnProperty('default')
        scopedDefaults[scope] = {}
        _.setValueForKeyPath(scopedDefaults[scope], keyPath, scopeSchema.default)
      @scopedSettingsStore.addProperties('schema-default', scopedDefaults)

    if schema.type is 'object' and schema.properties? and isPlainObject(schema.properties)
      keys = splitKeyPath(keyPath)
      for key, childValue of schema.properties
        continue unless schema.properties.hasOwnProperty(key)
        @setScopedDefaultsFromSchema(keys.concat([key]).join('.'), childValue)

    return

  extractDefaultsFromSchema: (schema) ->
    if schema.default?
      schema.default
    else if schema.type is 'object' and schema.properties? and isPlainObject(schema.properties)
      defaults = {}
      properties = schema.properties or {}
      defaults[key] = @extractDefaultsFromSchema(value) for key, value of properties
      defaults

  makeValueConformToSchema: (keyPath, value, options) ->
    if options?.suppressException
      try
        @makeValueConformToSchema(keyPath, value)
      catch e
        undefined
    else
      value = @constructor.executeSchemaEnforcers(keyPath, value, schema) if schema = @getSchema(keyPath)
      value

  # When the schema is changed / added, there may be values set in the config
  # that do not conform to the schema. This will reset make them conform.
  resetSettingsForSchemaChange: (source=@getUserConfigPath()) ->
    @transact =>
      @settings = @makeValueConformToSchema(null, @settings, suppressException: true)
      priority = @priorityForSource(source)
      selectorsAndSettings = @scopedSettingsStore.propertiesForSource(source)
      @scopedSettingsStore.removePropertiesForSource(source)
      for scopeSelector, settings of selectorsAndSettings
        settings = @makeValueConformToSchema(null, settings, suppressException: true)
        @setRawScopedValue(null, settings, source, scopeSelector)
      return

  ###
  Section: Private Scoped Settings
  ###

  priorityForSource: (source) ->
    if source is @getUserConfigPath()
      1000
    else
      0

  emitChangeEvent: ->
    @emitter.emit 'did-change' unless @transactDepth > 0

  resetUserScopedSettings: (newScopedSettings) ->
    source = @getUserConfigPath()
    priority = @priorityForSource(source)
    @scopedSettingsStore.removePropertiesForSource(source)

    for scopeSelector, settings of newScopedSettings
      settings = @makeValueConformToSchema(null, settings, suppressException: true)
      validatedSettings = {}
      validatedSettings[scopeSelector] = withoutEmptyObjects(settings)
      @scopedSettingsStore.addProperties(source, validatedSettings, {priority}) if validatedSettings[scopeSelector]?

    @emitChangeEvent()

  addScopedSettings: (source, selector, value, options) ->
    Grim.deprecate("Use ::set instead")
    settingsBySelector = {}
    settingsBySelector[selector] = value
    disposable = @scopedSettingsStore.addProperties(source, settingsBySelector, options)
    @emitChangeEvent()
    new Disposable =>
      disposable.dispose()
      @emitChangeEvent()

  setRawScopedValue: (keyPath, value, source, selector, options) ->
    if keyPath?
      newValue = {}
      _.setValueForKeyPath(newValue, keyPath, value)
      value = newValue

    settingsBySelector = {}
    settingsBySelector[selector] = value
    @scopedSettingsStore.addProperties(source, settingsBySelector, priority: @priorityForSource(source))
    @emitChangeEvent()

  getRawScopedValue: (scopeDescriptor, keyPath, options) ->
    scopeDescriptor = ScopeDescriptor.fromObject(scopeDescriptor)
    @scopedSettingsStore.getPropertyValue(scopeDescriptor.getScopeChain(), keyPath, options)

  observeScopedKeyPath: (scope, keyPath, callback) ->
    callback(@get(keyPath, {scope}))
    @onDidChangeScopedKeyPath scope, keyPath, (event) -> callback(event.newValue)

  onDidChangeScopedKeyPath: (scope, keyPath, callback) ->
    oldValue = @get(keyPath, {scope})
    @emitter.on 'did-change', =>
      newValue = @get(keyPath, {scope})
      unless _.isEqual(oldValue, newValue)
        event = {oldValue, newValue}
        oldValue = newValue
        callback(event)

  settingsForScopeDescriptor: (scopeDescriptor, keyPath) ->
    Grim.deprecate("Use Config::getAll instead")
    entries = @getAll(null, scope: scopeDescriptor)
    value for {value} in entries when _.valueForKeyPath(value, keyPath)?

# Base schema enforcers. These will coerce raw input into the specified type,
# and will throw an error when the value cannot be coerced. Throwing the error
# will indicate that the value should not be set.
#
# Enforcers are run from most specific to least. For a schema with type
# `integer`, all the enforcers for the `integer` type will be run first, in
# order of specification. Then the `*` enforcers will be run, in order of
# specification.
Config.addSchemaEnforcers
  'integer':
    coerce: (keyPath, value, schema) ->
      value = parseInt(value)
      throw new Error("Validation failed at #{keyPath}, #{JSON.stringify(value)} cannot be coerced into an int") if isNaN(value) or not isFinite(value)
      value

  'number':
    coerce: (keyPath, value, schema) ->
      value = parseFloat(value)
      throw new Error("Validation failed at #{keyPath}, #{JSON.stringify(value)} cannot be coerced into a number") if isNaN(value) or not isFinite(value)
      value

  'boolean':
    coerce: (keyPath, value, schema) ->
      switch typeof value
        when 'string'
          if value.toLowerCase() is 'true'
            true
          else if value.toLowerCase() is 'false'
            false
          else
            throw new Error("Validation failed at #{keyPath}, #{JSON.stringify(value)} must be a boolean or the string 'true' or 'false'")
        when 'boolean'
          value
        else
          throw new Error("Validation failed at #{keyPath}, #{JSON.stringify(value)} must be a boolean or the string 'true' or 'false'")

  'string':
    validate: (keyPath, value, schema) ->
      unless typeof value is 'string'
        throw new Error("Validation failed at #{keyPath}, #{JSON.stringify(value)} must be a string")
      value

  'null':
    # null sort of isnt supported. It will just unset in this case
    coerce: (keyPath, value, schema) ->
      throw new Error("Validation failed at #{keyPath}, #{JSON.stringify(value)} must be null") unless value in [undefined, null]
      value

  'object':
    coerce: (keyPath, value, schema) ->
      throw new Error("Validation failed at #{keyPath}, #{JSON.stringify(value)} must be an object") unless isPlainObject(value)
      return value unless schema.properties?

      newValue = {}
      for prop, propValue of value
        childSchema = schema.properties[prop]
        if childSchema?
          try
            newValue[prop] = @executeSchemaEnforcers("#{keyPath}.#{prop}", propValue, childSchema)
          catch error
            console.warn "Error setting item in object: #{error.message}"
        else
          # Just pass through un-schema'd values
          newValue[prop] = propValue

      newValue

  'array':
    coerce: (keyPath, value, schema) ->
      throw new Error("Validation failed at #{keyPath}, #{JSON.stringify(value)} must be an array") unless Array.isArray(value)
      itemSchema = schema.items
      if itemSchema?
        newValue = []
        for item in value
          try
            newValue.push @executeSchemaEnforcers(keyPath, item, itemSchema)
          catch error
            console.warn "Error setting item in array: #{error.message}"
        newValue
      else
        value

  'color':
    coerce: (keyPath, value, schema) ->
      color = Color.parse(value)
      unless color?
        throw new Error("Validation failed at #{keyPath}, #{JSON.stringify(value)} cannot be coerced into a color")
      color

  '*':
    coerceMinimumAndMaximum: (keyPath, value, schema) ->
      return value unless typeof value is 'number'
      if schema.minimum? and typeof schema.minimum is 'number'
        value = Math.max(value, schema.minimum)
      if schema.maximum? and typeof schema.maximum is 'number'
        value = Math.min(value, schema.maximum)
      value

    validateEnum: (keyPath, value, schema) ->
      possibleValues = schema.enum
      return value unless possibleValues? and Array.isArray(possibleValues) and possibleValues.length

      for possibleValue in possibleValues
        # Using `isEqual` for possibility of placing enums on array and object schemas
        return value if _.isEqual(possibleValue, value)

      throw new Error("Validation failed at #{keyPath}, #{JSON.stringify(value)} is not one of #{JSON.stringify(possibleValues)}")

isPlainObject = (value) ->
  _.isObject(value) and not _.isArray(value) and not _.isFunction(value) and not _.isString(value) and not (value instanceof Color)

splitKeyPath = (keyPath) ->
  return [] unless keyPath?
  startIndex = 0
  keyPathArray = []
  for char, i in keyPath
    if char is '.' and (i is 0 or keyPath[i-1] != '\\')
      keyPathArray.push keyPath.substring(startIndex, i)
      startIndex = i + 1
  keyPathArray.push keyPath.substr(startIndex, keyPath.length)
  keyPathArray

withoutEmptyObjects = (object) ->
  resultObject = undefined
  if isPlainObject(object)
    for key, value of object
      newValue = withoutEmptyObjects(value)
      if newValue?
        resultObject ?= {}
        resultObject[key] = newValue
  else
    resultObject = object
  resultObject
