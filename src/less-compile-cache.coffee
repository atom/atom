path = require 'path'

_ = require './underscore-extensions'
LessCache = require 'less-cache'

module.exports =
class LessCompileCache
  _.extend @prototype, require('./subscriber')

  @cacheDir: '/tmp/atom-compile-cache/less'

  constructor: ->
    @cache = new LessCache
      cacheDir: @constructor.cacheDir
      importPaths: @getImportPaths()
      resourcePath: window.resourcePath
      fallbackDir: path.join(window.resourcePath, 'less-compile-cache')

    @subscribe atom.themes, 'reloaded', => @cache.setImportPaths(@getImportPaths())

  getImportPaths: -> atom.themes.getImportPaths().concat(config.lessSearchPaths)

  read: (stylesheetPath) -> @cache.readFileSync(stylesheetPath)

  destroy: -> @unsubscribe()
