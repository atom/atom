path = require 'path'
url = require 'url'
zlib = require 'zlib'

_ = require 'underscore-plus'
plist = require 'plist'
request = require 'request'
tar = require 'tar'
temp = require 'temp'

fs = require './fs'

# Convert a TextMate bundle to an Atom package
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
    {protocol} = url.parse(@sourcePath)
    if protocol is 'http:' or protocol is 'https:'
      tempPath = temp.mkdirSync('atom-bundle-')
      request(@getDownloadUrl())
        .pipe(zlib.createGunzip())
        .pipe(tar.Extract(path: tempPath))
        .on 'error', (error) -> callback(error)
        .on 'end', =>
          sourcePath = path.join(tempPath, fs.readdirSync(tempPath)[0])
          @copyDirectories(sourcePath, callback)
    else
      @copyDirectories(@sourcePath, callback)

  getDownloadUrl: ->
    downloadUrl = @sourcePath
    downloadUrl += '/' unless downloadUrl[downloadUrl.length - 1] is '/'
    downloadUrl += 'archive/master.tar.gz'

  copyDirectories: (sourcePath, callback) ->
    for directoryName in @directoryNames
      @convertDirectory(sourcePath, directoryName)
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

  convertDirectory: (sourcePath, directoryName) ->
    source = path.join(sourcePath, directoryName)
    return unless fs.isDirectorySync(source)

    destination = path.join(@destinationPath, directoryName)
    fs.makeTreeSync(destination)

    for child in fs.readdirSync(source)
      childPath = path.join(source, child)
      @convertFile(childPath, destination) if fs.isFileSync(childPath)

    @normalizeFilenames(destination)
