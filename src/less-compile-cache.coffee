_ = require 'underscore'
LessCache = require 'less-cache'

module.exports =
class LessCompileCache
  _.extend @prototype, require('subscriber')

  @cacheDir: '/tmp/atom-compile-cache/less'

  constructor: ->
    importPaths =
    @cache = new LessCache
      cacheDir: @constructor.cacheDir
      importPaths: @getImportPaths()
    @subscribe atom.themes, 'reloaded', => @cache.setImportPaths(@getImportPaths())

  getImportPaths: -> atom.themes.getImportPaths().concat(config.lessSearchPaths)

  read: (stylesheetPath) -> @cache.readFileSync(stylesheetPath)

  destroy: -> @unsubscribe()
