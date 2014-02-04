path = require 'path'

_ = require 'underscore-plus'
async = require 'async'
plist = require 'plist'

fs = require './fs'

module.exports =
class PackageConverter
  constructor: (@sourcePath, @destinationPath) ->
    @plistExtensions = [
      '.plist'
      '.tmCommand'
      '.tmLanguage'
      '.tmMacro'
      '.tmPreferences'
      '.tmSnippet'
    ]

    @directoryNames = [
      'preferences'
      'snippets'
      'syntaxes'
    ]

  convert: (callback) ->
    @convertDirectory(directoryName) for directoryName in @directoryNames
    callback()

  filterObject: (object) ->
    delete object.uuid

  convertFile: (sourcePath, destinationDir) ->
    extension = path.extname(sourcePath)
    destinationName = "#{path.basename(sourcePath, extension)}.json"
    destinationName = destinationName.toLowerCase()
    destinationPath = path.join(destinationDir, destinationName)

    if _.contains(@plistExtensions, path.extname(sourcePath))
      contents = plist.parseFileSync(sourcePath)
      @filterObject(contents)
      fs.writeFileSync(destinationPath, JSON.stringify(contents, null, 2))

  normalizeFilenames: (directoryPath) ->
    for child in fs.readdirSync(directoryPath)
      childPath = path.join(directoryPath, child)

      # Invalid characters taken from http://msdn.microsoft.com/en-us/library/windows/desktop/aa365247(v=vs.85).aspx
      convertedFileName = child.replace(/[|?*<>:"\\\/]+/g, '-')
      continue if child is convertedFileName

      convertedFileName = convertedFileName.replace(/[\s-]+/g, '-')
      convertedPath = path.join(directoryPath, convertedFileName)
      suffix = 1
      while fs.existsSync(convertedPath) or fs.existsSync(convertedPath.toLowerCase())
        extension = path.extname(convertedFileName)
        convertedFileName = "#{path.basename(convertedFileName, extension)}-#{suffix}#{extension}"
        convertedPath = path.join(directoryPath, convertedFileName)
        suffix++
      fs.renameSync(childPath, convertedPath)

  convertDirectory: (directoryName) ->
    source = path.join(@sourcePath, directoryName)
    destination = path.join(@destinationPath, directoryName)
    fs.makeTreeSync(destination)

    for child in fs.readdirSync(source)
      childPath = path.join(source, child)
      @convertFile(childPath, destination) if fs.isFileSync(childPath)

    @normalizeFilenames(destination)
