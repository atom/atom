path = require 'path'
os = require 'os'
LessCache = require 'less-cache'
{Subscriber} = require 'emissary'

tmpDir = if process.platform is 'win32' then os.tmpdir() else '/tmp'

module.exports =
class LessCompileCache
  Subscriber.includeInto(this)

  @cacheDir: path.join(tmpDir, 'atom-compile-cache', 'less')

  constructor: ({resourcePath}) ->
    @lessSearchPaths = [
      path.join(resourcePath, 'static', 'variables')
      path.join(resourcePath, 'static')
    ]

    @cache = new LessCache
      cacheDir: @constructor.cacheDir
      importPaths: @getImportPaths()
      resourcePath: window.resourcePath
      fallbackDir: path.join(resourcePath, 'less-compile-cache')

    @subscribe atom.themes, 'reloaded', => @cache.setImportPaths(@getImportPaths())

  getImportPaths: -> atom.themes.getImportPaths().concat(@lessSearchPaths)

  read: (stylesheetPath) -> @cache.readFileSync(stylesheetPath)

  destroy: -> @unsubscribe()
