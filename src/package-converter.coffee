path = require 'path'
url = require 'url'
zlib = require 'zlib'

_ = require 'underscore-plus'
CSON = require 'season'
plist = require 'plist'
{ScopeSelector} = require 'first-mate'
tar = require 'tar'
temp = require 'temp'

fs = require './fs'
request = require './request'

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
    requestOptions = url: @getDownloadUrl()
    request.createReadStream requestOptions, (readStream) =>
      readStream.on 'response', ({headers, statusCode}) ->
        if statusCode isnt 200
          callback("Download failed (#{headers.status})")

      readStream.pipe(zlib.createGunzip()).pipe(tar.Extract(path: tempPath))
        .on 'error', (error) -> callback(error)
        .on 'end', =>
          sourcePath = path.join(tempPath, fs.readdirSync(tempPath)[0])
          @copyDirectories(sourcePath, callback)

  copyDirectories: (sourcePath, callback) ->
    sourcePath = path.resolve(sourcePath)
    try
      packageName = JSON.parse(fs.readFileSync(path.join(sourcePath, 'package.json')))?.packageName
    packageName ?= path.basename(@destinationPath)

    @convertSnippets(packageName, sourcePath)
    @convertPreferences(packageName, sourcePath)
    @convertGrammars(sourcePath)
    callback()

  filterObject: (object) ->
    delete object.uuid
    delete object.keyEquivalent

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

  readFileSync: (filePath) ->
    if _.contains(@plistExtensions, path.extname(filePath))
      plist.parseFileSync(filePath)
    else if _.contains(['.json', '.cson'], path.extname(filePath))
      CSON.readFileSync(filePath)

  writeFileSync: (filePath, object={}) ->
    @filterObject(object)
    if Object.keys(object).length > 0
      CSON.writeFileSync(filePath, object)

  convertFile: (sourcePath, destinationDir) ->
    extension = path.extname(sourcePath)
    destinationName = "#{path.basename(sourcePath, extension)}.cson"
    destinationName = destinationName.toLowerCase()
    destinationPath = path.join(destinationDir, destinationName)

    if _.contains(@plistExtensions, path.extname(sourcePath))
      contents = plist.parseFileSync(sourcePath)
    else if _.contains(['.json', '.cson'], path.extname(sourcePath))
      contents = CSON.readFileSync(sourcePath)

    @writeFileSync(destinationPath, contents)

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

  convertSnippets: (packageName, source) ->
    sourceSnippets = path.join(source, 'snippets')
    unless fs.isDirectorySync(sourceSnippets)
      sourceSnippets = path.join(source, 'Snippets')
    return unless fs.isDirectorySync(sourceSnippets)

    snippetsBySelector = {}
    destination = path.join(@destinationPath, 'snippets')
    for child in fs.readdirSync(sourceSnippets)
      snippet = @readFileSync(path.join(sourceSnippets, child)) ? {}
      {scope, name, content, tabTrigger} = snippet
      continue unless tabTrigger and content

      # Replace things like '${TM_C_POINTER: *}' with ' *'
      content = content.replace(/\$\{TM_[A-Z_]+:([^}]+)}/g, '$1')

      # Replace things like '${1:${TM_FILENAME/(\\w+)*/(?1:$1:NSObject)/}}'
      # with '$1'
      content = content.replace(/\$\{(\d)+:\s*\$\{TM_[^}]+\s*\}\s*\}/g, '$$1')

      # Unescape escaped dollar signs $
      content = content.replace(/\\\$/g, '$')

      unless name?
        extension = path.extname(child)
        name = path.basename(child, extension)

      selector = new ScopeSelector(scope).toCssSelector() if scope
      selector ?= '*'

      snippetsBySelector[selector] ?= {}
      snippetsBySelector[selector][name] = {prefix: tabTrigger, body: content}

    @writeFileSync(path.join(destination, "#{packageName}.cson"), snippetsBySelector)
    @normalizeFilenames(destination)

  convertPreferences: (packageName, source) ->
    sourcePreferences = path.join(source, 'preferences')
    unless fs.isDirectorySync(sourcePreferences)
      sourcePreferences = path.join(source, 'Preferences')
    return unless fs.isDirectorySync(sourcePreferences)

    preferencesBySelector = {}
    destination = path.join(@destinationPath, 'scoped-properties')
    for child in fs.readdirSync(sourcePreferences)
      {scope, settings} = @readFileSync(path.join(sourcePreferences, child)) ? {}
      continue unless scope and settings

      if properties = @convertSettings(settings)
        selector = new ScopeSelector(scope).toCssSelector()
        for key, value of properties
          preferencesBySelector[selector] ?= {}
          if preferencesBySelector[selector][key]?
            preferencesBySelector[selector][key] = _.extend(value, preferencesBySelector[selector][key])
          else
            preferencesBySelector[selector][key] = value

    @writeFileSync(path.join(destination, "#{packageName}.cson"), preferencesBySelector)
    @normalizeFilenames(destination)

  convertGrammars: (source) ->
    sourceSyntaxes = path.join(source, 'syntaxes')
    unless fs.isDirectorySync(sourceSyntaxes)
      sourceSyntaxes = path.join(source, 'Syntaxes')
    return unless fs.isDirectorySync(sourceSyntaxes)

    destination = path.join(@destinationPath, 'grammars')
    for child in fs.readdirSync(sourceSyntaxes)
      childPath = path.join(sourceSyntaxes, child)
      @convertFile(childPath, destination) if fs.isFileSync(childPath)

    @normalizeFilenames(destination)
