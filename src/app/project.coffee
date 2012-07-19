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
  rootDirectory: null
  editSessions: null
  tabText: null
  autoIndent: null
  softTabs: null
  softWrap: null
  ignoredPathRegexes: null

  constructor: (path) ->
    @setPath(path)
    @editSessions = []
    @buffers = []
    @setTabText('  ')
    @setAutoIndent(true)
    @setSoftTabs(true)
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
    command = [
      "find \"#{@getPath()}\" -type f -print0" # find all paths in the project's working directory
      "grep --text --perl-regexp --invert-match --regexp=\"#{@ignorePathRegex()}\"" # accept only non-ignored paths, separated by \0 (find doesn't support pcre)
      "perl -0pi -e 's/\\n\\z\//'" # delete grep's trailing newline because it screws up xargs
      "xargs -0 grep --null --perl-regexp --with-filename --line-number --recursive --regexp=\"#{regex.source}\"" # run grep on each filtered file
    ].join(" | ")

    ChildProcess.exec command, bufferLines: true, stdout: (data) ->
      for grepLine in data.split('\n') when grepLine.length
        nullCharIndex = grepLine.indexOf('\0')
        colonIndex = grepLine.indexOf(':')
        path = grepLine.substring(0, nullCharIndex)
        row = parseInt(grepLine.substring(nullCharIndex + 1, colonIndex)) - 1
        line = grepLine.substring(colonIndex + 1)
        while match = regex.exec(line)
          range = new Range([row, match.index], [row, match.index + match[0].length])
          iterator({path, match, range})

_.extend Project.prototype, EventEmitter
