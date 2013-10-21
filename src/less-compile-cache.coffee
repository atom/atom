path = require 'path'
LessCache = require 'less-cache'
{Subscriber} = require 'emissary'

module.exports =
class LessCompileCache
  Subscriber.includeInto(this)

  @cacheDir: path.join(atom.getTempDirPath(), 'atom-compile-cache', 'less')

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
