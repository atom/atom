path = require 'path'
fs = require 'fs'

module.exports =
class Lister
  atomPackagesDirectory: null

  constructor: ->
    atomDirectory = process.env.ATOM_HOME ? path.join(process.env.HOME, '.atom')
    @atomModulesDirectory = path.join(atomDirectory, 'packages')

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

  listAtomPackagesDirectory: ->
    packages = []
    if @isDirectory(@atomModulesDirectory)
      for child in fs.readdirSync(@atomModulesDirectory)
        manifest = path.join(@atomModulesDirectory, child, 'package.json')
        continue unless @isFile(manifest)
        try
          packageJson = JSON.parse(fs.readFileSync(manifest, 'utf8'))
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
