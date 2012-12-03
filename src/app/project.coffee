fs = require 'fs'
path = require 'path'
_ = require 'underscore'
$ = require 'jquery'
Range = require 'app/range'
Buffer = require 'app/buffer'
EditSession = require 'app/edit-session'
EventEmitter = require 'app/event-emitter'
Directory = require 'app/directory'
ChildProcess = require 'stdlib/child-process'
Git = require 'app/git'

module.exports =
class Project
  tabLength: 2
  autoIndent: true
  softTabs: true
  softWrap: false
  hideIgnoredFiles: false
  rootDirectory: null
  editSessions: null
  ignoredPathRegexes: null

  constructor: (pathName) ->
    @setPath(pathName)
    @editSessions = []
    @buffers = []
    @ignoredFolderNames = [
      '.git'
    ]
    @ignoredFileNames = [
      '.DS_Store'
    ]
    @ignoredPathRegexes = []
    @repo = new Git(pathName)

  destroy: ->
    editSession.destroy() for editSession in @getEditSessions()

  getPath: ->
    @rootDirectory?.path

  setPath: (pathName) ->
    @rootDirectory?.off()

    if pathName?
      directory = if fs.statSync(pathName).isDirectory() then pathName else path.dirname(pathName)
      @rootDirectory = new Directory(directory)
      @repo = new Git(pathName)
    else
      @rootDirectory = null

    @trigger "path-change"

  getRootDirectory: ->
    @rootDirectory

  getFilePaths: ->
    filePaths = []

    onFile = (pathName) =>
      filePaths.push(pathName) unless @ignoreFile(pathName)

    onDirectory = (pathName) =>
      return not @ignoreDirectory(pathName)

    fs.traverseTree @getPath(), onFile, onDirectory
    filePaths

  ignoreDirectory: (pathName) ->
    lastSlash = pathName.lastIndexOf('/')
    if lastSlash isnt -1
      name = pathName.substring(lastSlash + 1)
    else
      name = pathName

    for ignored in @ignoredFolderNames
      return true if name is ignored

    for regex in @ignoredPathRegexes
      return true if pathName.match(regex)

    @ignoreRepositoryPath(pathName)

  ignoreFile: (pathName) ->
    lastSlash = pathName.lastIndexOf('/')
    if lastSlash isnt -1
      name = pathName.substring(lastSlash + 1)
    else
      name = pathName

    for ignored in @ignoredFileNames
      return true if name is ignored
    for regex in @ignoredPathRegexes
      return true if pathName.match(regex)

    @ignoreRepositoryPath(pathName)

  ignoreRepositoryPath: (pathName) ->
    @hideIgnoredFiles and @repo.isPathIgnored(fs.join(@getPath(), pathName))

  ignorePathRegex: ->
    @ignoredPathRegexes.map((regex) -> "(#{regex.source})").join("|")

  resolve: (filePath) ->
    filePath = path.join(@getPath(), filePath) unless filePath[0] == '/'
    fs.realpathSync(filePath)

  relativize: (fullPath) ->
    fullPath.replace(@getPath(), "").replace(/^\//, '')

  getAutoIndent: -> @autoIndent
  setAutoIndent: (@autoIndent) ->

  getSoftTabs: -> @softTabs
  setSoftTabs: (@softTabs) ->

  getSoftWrap: -> @softWrap
  setSoftWrap: (@softWrap) ->

  toggleIgnoredFiles: -> @setHideIgnoredFiles(not @hideIgnoredFiles)
  getHideIgnoredFiles: -> @hideIgnoredFiles
  setHideIgnoredFiles: (@hideIgnoredFiles) ->

  buildEditSessionForPath: (filePath, editSessionOptions={}) ->
    @buildEditSession(@bufferForPath(filePath), editSessionOptions)

  buildEditSession: (buffer, editSessionOptions) ->
    options = _.extend(@defaultEditSessionOptions(), editSessionOptions)
    options.project = this
    options.buffer = buffer
    editSession = new EditSession(options)
    @editSessions.push editSession
    @trigger 'new-edit-session', editSession
    editSession

  defaultEditSessionOptions: ->
    tabLength: @tabLength
    autoIndent: @getAutoIndent()
    softTabs: @getSoftTabs()
    softWrap: @getSoftWrap()

  getEditSessions: ->
    new Array(@editSessions...)

  removeEditSession: (editSession) ->
    _.remove(@editSessions, editSession)

  getBuffers: ->
    buffers = []
    for editSession in @editSessions when not _.include(buffers, editSession.buffer)
      buffers.push editSession.buffer

    buffers

  bufferForPath: (filePath) ->
    if filePath?
      filePath = @resolve(filePath)
      if filePath
        buffer = _.find @buffers, (buffer) -> buffer.getPath() == filePath
        buffer or @buildBuffer(filePath)
      else

    else
      @buildBuffer()

  buildBuffer: (filePath) ->
    buffer = new Buffer(filePath, this)
    @buffers.push buffer
    @trigger 'new-buffer', buffer
    buffer

  removeBuffer: (buffer) ->
    _.remove(@buffers, buffer)

  scan: (regex, iterator) ->
    command = "#{require.resolve('ag')} --ackmate '#{regex.source}' '#{@getPath()}'"
    bufferedData = ""

    state = 'readingPath'
    pathName = null

    readPath = (line) ->
      if /^[0-9,; ]+:/.test(line)
        state = 'readingLines'
      else if /^:/.test line
        pathName = line.substr(1)
      else
        pathName += ('\n' + line)

    readLine = (line) ->
      if line.length == 0
        state = 'readingPath'
        pathName = null
      else
        colonIndex = line.indexOf(':')
        matchInfo = line.substring(0, colonIndex)
        lineText = line.substring(colonIndex + 1)
        readMatches(matchInfo, lineText)

    readMatches = (matchInfo, lineText) ->
      [lineNumber, matchPositionsText] = matchInfo.match(/(\d+);(.+)/)[1..]
      row = parseInt(lineNumber) - 1
      matchPositions = matchPositionsText.split(',').map (positionText) -> positionText.split(' ').map (pos) -> parseInt(pos)

      for [column, length] in matchPositions
        range = new Range([row, column], [row, column + length])
        match = lineText.substr(column, length)
        iterator({path: pathName, range, match})

    ChildProcess.exec command , bufferLines: true, stdout: (data) ->
      lines = data.split('\n')
      lines.pop() # the last segment is a spurios '' because data always ends in \n due to bufferLines: true
      for line in lines
        readPath(line) if state is 'readingPath'
        readLine(line) if state is 'readingLines'

_.extend Project.prototype, EventEmitter
