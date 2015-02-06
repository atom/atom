crypto = require 'crypto'
path = require 'path'

CoffeeScript = require 'coffee-script'
CSON = require 'season'
fs = require 'fs-plus'

cacheDir = path.join(process.env.ATOM_HOME, 'compile-cache')

stats =
  hits: 0
  misses: 0

# Use separate compile cache when sudo'ing as root to avoid permission issues
if process.env.USER is 'root' and process.env.SUDO_USER and process.env.SUDO_USER isnt process.env.USER
  cacheDir = path.join(cacheDir, 'root')

coffeeCacheDir = path.join(cacheDir, 'coffee')
CSON.setCacheDir(path.join(cacheDir, 'cson'))

getCachePath = (coffee) ->
  digest = crypto.createHash('sha1').update(coffee, 'utf8').digest('hex')
  path.join(coffeeCacheDir, "#{digest}.js")

getCachedJavaScript = (cachePath) ->
  if fs.isFileSync(cachePath)
    try
      cachedJavaScript = fs.readFileSync(cachePath, 'utf8')
      stats.hits++
      return cachedJavaScript
  return

convertFilePath = (filePath) ->
  if process.platform is 'win32'
    filePath = "/#{path.resolve(filePath).replace(/\\/g, '/')}"
  encodeURI(filePath)

compileCoffeeScript = (coffee, filePath, cachePath) ->
  {js, v3SourceMap} = CoffeeScript.compile(coffee, filename: filePath, sourceMap: true)
  stats.misses++
  # Include source map in the web page environment.
  if btoa? and JSON? and unescape? and encodeURIComponent?
    js = "#{js}\n//# sourceMappingURL=data:application/json;base64,#{btoa unescape encodeURIComponent v3SourceMap}\n//# sourceURL=#{convertFilePath(filePath)}"
  try
    fs.writeFileSync(cachePath, js)
  js

requireCoffeeScript = (module, filePath) ->
  coffee = fs.readFileSync(filePath, 'utf8')
  cachePath = getCachePath(coffee)
  js = getCachedJavaScript(cachePath) ? compileCoffeeScript(coffee, filePath, cachePath)
  module._compile(js, filePath)

module.exports =
  cacheDir: cacheDir

  register: ->
    Object.defineProperty(require.extensions, '.coffee', {
      writable: false
      value: requireCoffeeScript
    })

  addPathToCache: (filePath) ->
    switch path.extname(filePath)
      when '.coffee'
        content = fs.readFileSync(filePath, 'utf8')
        cachePath = getCachePath(coffee)
        compileCoffeeScript(coffee, filePath, cachePath)
      when '.cson'
        CSON.readFileSync(filePath)
      when '.js'
        require('./6to5').addPathToCache(filePath)

  getCacheMisses: -> stats.misses

  getCacheHits: -> stats.hits
