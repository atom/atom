crypto = require 'crypto'
path = require 'path'

CoffeeScript = require 'coffee-script'
CSON = require 'season'
fs = require 'fs-plus'

cacheDir = path.join(fs.absolute('~/.atom'), 'compile-cache')
coffeeCacheDir = path.join(cacheDir, 'coffee')
CSON.setCacheDir(path.join(cacheDir, 'cson'))

getCachePath = (coffee) ->
  digest = crypto.createHash('sha1').update(coffee, 'utf8').digest('hex')
  path.join(coffeeCacheDir, "#{digest}.js")

getCachedJavaScript = (cachePath) ->
  if fs.isFileSync(cachePath)
    try
      fs.readFileSync(cachePath, 'utf8')

convertFilePath = (filePath) ->
  if process.platform is 'win32'
    filePath = "/#{path.resolve(filePath).replace(/\\/g, '/')}"
  encodeURI(filePath)

compileCoffeeScript = (coffee, filePath, cachePath) ->
  {js, v3SourceMap} = CoffeeScript.compile(coffee, filename: filePath, sourceMap: true)
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
    extension = path.extname(filePath)
    if extension is '.coffee'
      content = fs.readFileSync(filePath, 'utf8')
      cachePath = getCachePath(coffee)
      compileCoffeeScript(coffee, filePath, cachePath)
    else if extension is '.cson'
      CSON.readFileSync(filePath)
