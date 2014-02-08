path = require 'path'
os = require 'os'
LessCache = require 'less-cache'
{Subscriber} = require 'emissary'

tmpDir = if process.platform is 'win32' then os.tmpdir() else '/tmp'

# {LessCache} wrapper used by {ThemeManager} to read stylesheets.
module.exports =
class LessCompileCache
  Subscriber.includeInto(this)

  @cacheDir: path.join(tmpDir, 'atom-compile-cache', 'less')

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

  read: (stylesheetPath) -> @cache.readFileSync(stylesheetPath)

  destroy: -> @unsubscribe()
