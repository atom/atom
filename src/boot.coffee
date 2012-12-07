#  add atom-specific paths to the load path
fs = require 'fs'
Module = require 'module'
loadPaths = ['./src/extensions', './src', './vendor', './static', './themes', './spec', './benchmark']
process.env.NODE_PATH = loadPaths.map((path) -> fs.realpathSync(path)).join(':')
Module._initPaths()

# make it easy to resolve paths on the load path
path = require 'path'
path.resolveOnLoadPath = (relativePath) ->
  for loadPath in Module.globalPaths
    candidatePath = path.join(loadPath, relativePath)
    return candidatePath if fs.existsSync(candidatePath)

# cache coffee-script compilation
CoffeeScript = require 'coffee-script'
crypto = require 'crypto'
path = require 'path'
Module._extensions['.coffee'] = (module, filename) ->
  source = fs.readFileSync(filename, 'utf8')
  md5 = crypto.createHash('md5').update(source).digest('hex')
  cachedPath = "/tmp/atom-compiled-scripts/#{md5}"
  if fs.existsSync(cachedPath)
    compiledSource = fs.readFileSync(cachedPath, 'utf8')
  else
    compiledSource = CoffeeScript.compile(source, filename: filename)
    fs.writeFileSync(cachedPath, compiledSource)
  module._compile(compiledSource, filename)

require 'app/atom'
require 'app/window'
# require 'spec-bootstrap'
require 'benchmark-bootstrap'
# require 'window-bootstrap'