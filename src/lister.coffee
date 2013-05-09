path = require 'path'
fs = require 'fs'
config = require './config'

module.exports =
class Lister
  atomModulesDirectory: null

  constructor: ->
    @atomModulesDirectory = path.join(config.getAtomDirectory(), 'packages')

  isDirectory: (directoryPath) ->
    try
      fs.statSync(directoryPath).isDirectory()
    catch e
      false

  isFile: (filePath) ->
    try
      fs.statSync(filePath).isFile()
    catch e
      false

  list: (directoryPath) ->
    if @isDirectory(directoryPath)
      try
        fs.readdirSync(@atomModulesDirectory)
      catch e
        []
    else
      []

  listAtomPackagesDirectory: ->
    packages = []
    for child in @list(@atomModulesDirectory)
      manifest = path.join(@atomModulesDirectory, child, 'package.json')
      continue unless @isFile(manifest)
      try
        packageJson = JSON.parse(fs.readFileSync(manifest, 'utf8'))
      catch e
        continue

      name = packageJson.name ? child
      version = packageJson.version ? '0.0.0'
      packages.push({name, version})

    console.log @atomModulesDirectory
    for pack, index in packages
      if index is packages.length - 1
        prefix = '\u2514\u2500\u2500 '
      else
        prefix = '\u251C\u2500\u2500 '
      console.log "#{prefix}#{pack.name}@#{pack.version}"
  run: (options) ->
    @listAtomPackagesDirectory()
