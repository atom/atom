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
  constructor: (@sourcePath, destinationPath) ->
    @destinationPath = path.resolve(destinationPath)

    @plistExtensions = [
      '.plist'
      '.tmCommand'
      '.tmLanguage'
      '.tmMacro'
      '.tmPreferences'
      '.tmSnippet'
    ]

    @directoryMappings = {
      'Preferences': 'scoped-properties'
      'Snippets': 'snippets'
      'Syntaxes': 'grammars'
    }

  convert: (callback) ->
    {protocol} = url.parse(@sourcePath)
    if protocol is 'http:' or protocol is 'https:'
      @downloadBundle(callback)
    else
      @copyDirectories(@sourcePath, callback)

  getDownloadUrl: ->
    downloadUrl = @sourcePath
    downloadUrl = downloadUrl.replace(/(\.git)?\/*$/, '')
    downloadUrl += '/archive/master.tar.gz'

  downloadBundle: (callback) ->
    tempPath = temp.mkdirSync('atom-bundle-')
    request(@getDownloadUrl())
      .on 'response', ({headers, statusCode}) ->
        if statusCode isnt 200
          callback("Download failed (#{headers.status})")
      .pipe(zlib.createGunzip())
      .pipe(tar.Extract(path: tempPath))
      .on 'error', (error) -> callback(error)
      .on 'end', =>
        sourcePath = path.join(tempPath, fs.readdirSync(tempPath)[0])
        @copyDirectories(sourcePath, callback)

  copyDirectories: (sourcePath, callback) ->
    sourcePath = path.resolve(sourcePath)
    for source, target of @directoryMappings
      @convertDirectory(path.join(sourcePath, source), target)
    callback()

  filterObject: (object) ->
    delete object.uuid

  convertSettings: (settings) ->
    if settings.shellVariables
      shellVariables = {}
      for {name, value} in settings.shellVariables
        shellVariables[name] = value
      settings.shellVariables = shellVariables

    editorProperties = _.compactObject(
      commentStart: _.valueForKeyPath(settings, 'shellVariables.TM_COMMENT_START')
      commentEnd: _.valueForKeyPath(settings, 'shellVariables.TM_COMMENT_END')
      increaseIndentPattern: settings.increaseIndentPattern
      decreaseIndentPattern: settings.decreaseIndentPattern
      foldEndPattern: settings.foldingStopMarker
      completions: settings.completions
    )
    {editor: editorProperties} unless _.isEmpty(editorProperties)

  convertPreferences: ({scope, settings}={}) ->
    return unless scope and settings

    if properties = @convertSettings(settings)
      preferences = {}
      preferences[scope] = properties
      preferences

  convertFile: (sourcePath, destinationDir) ->
    extension = path.extname(sourcePath)
    destinationName = "#{path.basename(sourcePath, extension)}.json"
    destinationName = destinationName.toLowerCase()
    destinationPath = path.join(destinationDir, destinationName)

    if _.contains(@plistExtensions, path.extname(sourcePath))
      contents = plist.parseFileSync(sourcePath) ? {}
      @filterObject(contents)

      if path.basename(path.dirname(sourcePath)) is 'Preferences'
        contents = @convertPreferences(contents)
        return unless contents

      fs.writeFileSync(destinationPath, JSON.stringify(contents, null, 2))

  normalizeFilenames: (directoryPath) ->
    return unless fs.isDirectorySync(directoryPath)

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

  convertDirectory: (source, targetName) ->
    return unless fs.isDirectorySync(source)

    destination = path.join(@destinationPath, targetName)
    for child in fs.readdirSync(source)
      childPath = path.join(source, child)
      @convertFile(childPath, destination) if fs.isFileSync(childPath)

    @normalizeFilenames(destination)
