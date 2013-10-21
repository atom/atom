crypto = require 'crypto'
fs = require 'fs'
path = require 'path'
os = require 'os'

CoffeeScript = require 'coffee-script'
CSON = require 'season'
mkdir = require('mkdirp').sync

tmpDir = if process.platform is 'win32' then os.tmpdir() else '/tmp'
cacheDir = path.join(tmpDir, 'atom-compile-cache')
coffeeCacheDir = path.join(cacheDir, 'coffee')
CSON.setCacheDir(path.join(cacheDir, 'cson'))

getCachePath = (coffee) ->
  digest = crypto.createHash('sha1').update(coffee, 'utf8').digest('hex')
  path.join(coffeeCacheDir, "#{digest}.coffee")

getCachedJavaScript = (cachePath) ->
  if stat = fs.statSyncNoException(cachePath)
    try
      fs.readFileSync(cachePath, 'utf8') if stat.isFile()

compileCoffeeScript = (coffee, filePath, cachePath) ->
  js = CoffeeScript.compile(coffee, filename: filePath)
  try
    mkdir(path.dirname(cachePath))
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
