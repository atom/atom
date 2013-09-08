crypto = require 'crypto'
fs = require 'fs'
path = require 'path'

CoffeeScript = require 'coffee-script'
mkdir = require('mkdirp').sync

getCachePath = (coffeeContents)->
  digest = crypto.createHash('sha1').update(coffeeContents, 'utf8').digest('hex')
  path.join('/tmp/atom-compile-cache/coffee', "#{digest}.coffee")

require.extensions['.coffee'] = (module, filePath) ->
  coffeeContents = fs.readFileSync(filePath, 'utf8')
  cachePath = getCachePath(coffeeContents)
  try
    jsContents = fs.readFileSync(cachePath, 'utf8') if fs.statSync(cachePath).isFile()

  unless jsContents?
    jsContents = CoffeeScript.compile(coffeeContents, filename: filePath)
    try
      mkdir(path.dirname(cachePath))
      fs.writeFileSync(cachePath, jsContents)

  module._compile(jsContents, filePath)
