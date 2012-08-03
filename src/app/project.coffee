fs = require 'fs'
_ = require 'underscore'
$ = require 'jquery'
Range = require 'range'
Buffer = require 'buffer'
EditSession = require 'edit-session'
EventEmitter = require 'event-emitter'
Directory = require 'directory'
ChildProcess = require 'child-process'

module.exports =
class Project
  tabText: '  '
  autoIndent: false
  softTabs: true
  softWrap: false
  rootDirectory: null
  editSessions: null
  ignoredPathRegexes: null

  constructor: (path) ->
    @setPath(path)
    @editSessions = []
    @buffers = []
    @ignoredPathRegexes = [
      /\.DS_Store$/
      /(^|\/)\.git(\/|$)/
    ]

  destroy: ->
    editSession.destroy() for editSession in @getEditSessions()

  getPath: ->
    @rootDirectory?.path

  setPath: (path) ->
    @rootDirectory?.off()

    if path?
      directory = if fs.isDirectory(path) then path else fs.directory(path)
      @rootDirectory = new Directory(directory)
    else
      @rootDirectory = null

    @trigger "path-change"

  getRootDirectory: ->
    @rootDirectory

  getFilePaths: ->
    deferred = $.Deferred()

    filePaths = []
    fs.traverseTree @getPath(), (path, prune) =>
      if @ignorePath(path)
        prune()
      else if fs.isFile(path)
        filePaths.push @relativize(path)

    deferred.resolve filePaths
    deferred

  ignorePath: (path) ->
    _.find @ignoredPathRegexes, (regex) -> path.match(regex)

  ignorePathRegex: ->
    @ignoredPathRegexes.map((regex) -> "(#{regex.source})").join("|")

  resolve: (filePath) ->
    filePath = fs.join(@getPath(), filePath) unless filePath[0] == '/'
    fs.absolute filePath

  relativize: (fullPath) ->
    fullPath.replace(@getPath(), "").replace(/^\//, '')

  getTabText: -> @tabText
  setTabText: (@tabText) ->

  getAutoIndent: -> @autoIndent
  setAutoIndent: (@autoIndent) ->

  getSoftTabs: -> @softTabs
  setSoftTabs: (@softTabs) ->

  getSoftWrap: -> @softWrap
  setSoftWrap: (@softWrap) ->

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
    tabText: @getTabText()
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
      buffer = _.find @buffers, (buffer) -> buffer.getPath() == filePath
      buffer or @buildBuffer(filePath)
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
    regex = new RegExp(regex.source, 'g')
    command = "#{require.resolve('ag')} --ackmate \"#{regex.source}\" \"#{@getPath()}\""
    bufferedData = ""

    state = 'readingPath'
    path = null

    readPath = (line) ->
      if /^[0-9,; ]+:/.test(line)
        state = 'readingLines'
      else if /^:/.test line
        path = line.substr(1)
      else
        path += ('\n' + line)

    readLine = (line) ->
      if line.length == 0
        state = 'readingPath'
        path = null
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
        iterator({path, range, match})

    ChildProcess.exec command , bufferLines: true, stdout: (data) ->
      lines = data.split('\n')
      lines.pop() # the last segment is a spurios '' because data always ends in \n due to bufferLines: true
      for line in lines
        readPath(line) if state is 'readingPath'
        readLine(line) if state is 'readingLines'

_.extend Project.prototype, EventEmitter
