path = require 'path'
LessCache = require 'less-cache'

# {LessCache} wrapper used by {ThemeManager} to read stylesheets.
module.exports =
class LessCompileCache
  @cacheDir: path.join(process.env.ATOM_HOME, 'compile-cache', 'less')

  constructor: ({resourcePath, importPaths, lessSourcesByRelativeFilePath}) ->
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
      lessSourcesByRelativeFilePath: lessSourcesByRelativeFilePath
      fallbackDir: path.join(resourcePath, 'less-compile-cache')

  setImportPaths: (importPaths=[]) ->
    @cache.setImportPaths(importPaths.concat(@lessSearchPaths))

  read: (stylesheetPath) ->
    @cache.readFileSync(stylesheetPath)

  cssForFile: (stylesheetPath, lessContent) ->
    @cache.cssForFile(stylesheetPath, lessContent)
