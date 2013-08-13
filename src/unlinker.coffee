path = require 'path'
fs = require 'fs'
CSON = require 'season'
config = require './config'

module.exports =
class Unlinker
  constructor: ->

  run: (options) ->
    linkPath = path.resolve(process.cwd(), options.commandArgs.shift() ? '.')
    try
      packageName = CSON.readFileSync(CSON.resolve(path.join(linkPath, 'package'))).name
    packageName = path.basename(linkPath) unless packageName

    targetPath = path.join(config.getAtomDirectory(), 'packages', packageName)
    try
      fs.unlinkSync(targetPath) if fs.existsSync(targetPath)
      console.log "Unlinked #{targetPath}"
      options.callback()
    catch error
      console.error("Unlinking #{targetPath} failed")
      options.callback(error)
