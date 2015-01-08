path = require 'path'
fs = require 'fs-plus'
LessCache = require 'less-cache'
{Subscriber} = require 'emissary'

# {LessCache} wrapper used by {ThemeManager} to read stylesheets.
module.exports =
class LessCompileCache
  Subscriber.includeInto(this)

  @cacheDir: path.join(require('./coffee-cache').cacheDir, 'less')

  constructor: ({resourcePath, importPaths}) ->
    @lessSearchPaths = [
      path.join(resourcePath, 'static', 'variables')
      path.join(resourcePath, 'static')
    ]

    if importPaths?
      importPaths = importPaths.concat(@lessSearchPaths)
    else
      importPaths = @lessSearchPaths

    @cache = new LessCache
      cacheDir: @constructor.cacheDir
      importPaths: importPaths
      resourcePath: resourcePath
      fallbackDir: path.join(resourcePath, 'less-compile-cache')

  setImportPaths: (importPaths=[]) ->
    @cache.setImportPaths(importPaths.concat(@lessSearchPaths))

  read: (stylesheetPath) ->
    @cache.readFileSync(stylesheetPath)

  cssForFile: (stylesheetPath, lessContent) ->
    @cache.cssForFile(stylesheetPath, lessContent)

  destroy: -> @unsubscribe()
