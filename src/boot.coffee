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

_ = require 'underscore'
require 'app/atom'
require 'app/window'
global.document = window.document

require 'spec-bootstrap'
