crypto = require 'crypto'
fs = require 'fs'
path = require 'path'

CoffeeScript = require 'coffee-script'
mkdir = require('mkdirp').sync

cacheDir = '/tmp/atom-compile-cache/coffee'

getCachePath = (coffee) ->
  digest = crypto.createHash('sha1').update(coffee, 'utf8').digest('hex')
  path.join(cacheDir, "#{digest}.coffee")

getCachedJavaScript = (cachePath) ->
  try
    fs.readFileSync(cachePath, 'utf8') if fs.statSync(cachePath).isFile()

compileCoffeeScript = (coffee, filePath, cachePath) ->
  js = CoffeeScript.compile(coffee, filename: filePath)
  try
    mkdir(path.dirname(cachePath))
    fs.writeFileSync(cachePath, js)
  js

require.extensions['.coffee'] = (module, filePath) ->
  coffee = fs.readFileSync(filePath, 'utf8')
  cachePath = getCachePath(coffee)
  js = getCachedJavaScript(cachePath) ? compileCoffeeScript(coffee, filePath, cachePath)
  module._compile(js, filePath)

module.exports = {cacheDir}
