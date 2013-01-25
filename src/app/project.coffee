fs = require 'fs'
_ = require 'underscore'
$ = require 'jquery'
Range = require 'range'
Buffer = require 'buffer'
EditSession = require 'edit-session'
EventEmitter = require 'event-emitter'
Directory = require 'directory'
ChildProcess = require 'child-process'
Git = require 'git'

module.exports =
class Project

  @deserialize: (state) ->
    new Project(state.path, state.grammarOverridesByPath)

  tabLength: 2
  softTabs: true
  softWrap: false
  rootDirectory: null
  editSessions: null
  ignoredPathRegexes: null
  grammarOverridesByPath: null

  constructor: (path, @grammarOverridesByPath={}) ->
    @setPath(path)
    @editSessions = []
    @buffers = []

  serialize: ->
    path: @getPath()
    grammarOverridesByPath: @grammarOverridesByPath

  destroy: ->
    @repo?.destroy()
    @repo = null
    editSession.destroy() for editSession in @getEditSessions()

  addGrammarOverrideForPath: (path, grammar) ->
    @grammarOverridesByPath[path] = grammar.scopeName

  removeGrammarOverrideForPath: (path) ->
    delete @grammarOverridesByPath[path]

  grammarOverrideForPath: (path) ->
    syntax.grammarForScopeName(@grammarOverridesByPath[path])

  grammarForFilePath: (path, contents) ->
    @grammarOverrideForPath(path) or syntax.grammarForFilePath(path, contents)

  getPath: ->
    @rootDirectory?.path

  setPath: (path) ->
    @rootDirectory?.off()

    if path?
      directory = if fs.isDirectory(path) then path else fs.directory(path)
      @rootDirectory = new Directory(directory)
      @repo = Git.open(path)
    else
      @rootDirectory = null
      @repo = null

    @trigger "path-changed"

  getRootDirectory: ->
    @rootDirectory

  getFilePaths: ->
    deferred = $.Deferred()
    fs.getAllFilePathsAsync @getPath(), (paths) =>
      paths = paths.filter (path) => not @isPathIgnored(path)
      deferred.resolve(paths)
    deferred.promise()

  isPathIgnored: (path) ->
    for segment in path.split("/")
      ignoredNames = config.get("core.ignoredNames") or []
      return true if _.contains(ignoredNames, segment)

    @ignoreRepositoryPath(path)

  ignoreRepositoryPath: (path) ->
    config.get("core.hideGitIgnoredFiles") and @repo?.isPathIgnored(fs.join(@getPath(), path))

  resolve: (filePath) ->
    filePath = fs.join(@getPath(), filePath) unless filePath[0] == '/'
    fs.absolute filePath

  relativize: (fullPath) ->
    fullPath.replace(@getPath(), "").replace(/^\//, '')

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
    @trigger 'edit-session-created', editSession
    editSession

  defaultEditSessionOptions: ->
    tabLength: @tabLength
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
    @trigger 'buffer-created', buffer
    buffer

  removeBuffer: (buffer) ->
    _.remove(@buffers, buffer)

  scan: (regex, iterator) ->
    command = "#{require.resolve('ag')} --ackmate '#{regex.source}' '#{@getPath()}'"
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
