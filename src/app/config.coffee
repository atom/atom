fs = require 'fs'
_ = require 'underscore'
EventEmitter = require 'event-emitter'
{$$} = require 'space-pen'
jQuery = require 'jquery'
Specificity = require 'specificity'

configDirPath = fs.absolute("~/.atom")
configJsonPath = fs.join(configDirPath, "config.json")
userInitScriptPath = fs.join(configDirPath, "atom.coffee")
bundledPackagesDirPath = fs.join(resourcePath, "src/packages")
userPackagesDirPath = fs.join(configDirPath, "packages")

require.paths.unshift userPackagesDirPath

module.exports =
class Config
  configDirPath: configDirPath
  packageDirPaths: [userPackagesDirPath, bundledPackagesDirPath]
  settings: null

  constructor: ->
    @settings =
      core: _.clone(require('root-view').configDefaults)
      editor: _.clone(require('editor').configDefaults)

  load: ->
    @loadUserConfig()
    @requireUserInitScript()
    atom.loadPackages()

  loadUserConfig: ->
    if fs.exists(configJsonPath)
      userConfig = JSON.parse(fs.read(configJsonPath))
      _.extend(@settings, userConfig)

  get: (args...) ->
    scopeStack = args.shift() if args.length > 1
    keyPath = args.shift()
    keys = @keysForKeyPath(keyPath)

    settingsToSearch = []
    settingsToSearch.push(@settingsForScopeChain(scopeStack)...) if scopeStack
    settingsToSearch.push(@settings)

    for settings in settingsToSearch
      value = settings
      for key in keys
        value = value[key]
        break unless value?
      return value if value?
    undefined

  set: (args...) ->
    scope = args.shift() if args.length > 2
    keyPath = args.shift()
    value = args.shift()

    keys = @keysForKeyPath(keyPath)
    if scope
      keys.unshift(scope)
      keys.unshift('scopes')

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

  keysForKeyPath: (keyPath) ->
    if typeof keyPath is 'string'
      keyPath.split(".")
    else
      new Array(keyPath...)

  settingsForScopeChain: (scopeStack) ->
    return [] unless @settings.scopes?

    matchingScopeSelectors = []
    node = @buildDomNodeFromScopeChain(scopeStack)
    while node
      scopeSelectorsForNode = []
      for scopeSelector of @settings.scopes
        if jQuery.find.matchesSelector(node, scopeSelector)
          scopeSelectorsForNode.push(scopeSelector)
      scopeSelectorsForNode.sort (a, b) -> Specificity(b) - Specificity(a)
      matchingScopeSelectors.push(scopeSelectorsForNode...)
      node = node.parentNode

    matchingScopeSelectors.map (scopeSelector) => @settings.scopes[scopeSelector]

  buildDomNodeFromScopeChain: (scopeStack) ->
    scopeStack = new Array(scopeStack...)
    element = $$ ->
      elementsForRemainingScopes = =>
        classString = scopeStack.shift()
        classes = classString.replace(/^\./, '').replace(/\./g, ' ')
        if scopeStack.length
          @div class: classes, elementsForRemainingScopes
        else
          @div class: classes
      elementsForRemainingScopes()

    deepestChild = element.find(":not(:has(*))")
    if deepestChild.length
      deepestChild[0]
    else
      element[0]

  requireUserInitScript: ->
    try
      require userInitScriptPath if fs.exists(userInitScriptPath)
    catch error
      console.error "Failed to load `#{userInitScriptPath}`", error.stack, error

_.extend Config.prototype, EventEmitter
