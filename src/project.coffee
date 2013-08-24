fsUtils = require 'fs-utils'
path = require 'path'
url = require 'url'

_ = require 'underscore'
$ = require 'jquery'
telepath = require 'telepath'
{Range} = telepath
TextBuffer = require 'text-buffer'
EditSession = require 'edit-session'
EventEmitter = require 'event-emitter'
Directory = require 'directory'
BufferedNodeProcess = require 'buffered-node-process'
Git = require 'git'

# Public: Represents a project that's opened in Atom.
#
# Ultimately, a project is a git directory that's been opened. It's a collection
# of directories and files that you can operate on.
module.exports =
class Project
  @acceptsDocuments: true
  @version: 1

  registerDeserializer(this)

  @deserialize: (state) -> new Project(state)

  @openers: []

  @registerOpener: (opener) ->
    @openers.push(opener)

  @unregisterOpener: (opener) ->
    _.remove(@openers, opener)

  @pathForRepositoryUrl: (repoUrl) ->
    [repoName] = url.parse(repoUrl).path.split('/')[-1..]
    repoName = repoName.replace(/\.git$/, '')
    path.join(config.get('core.projectHome'), repoName)

  rootDirectory: null
  editSessions: null
  ignoredPathRegexes: null

  ### Internal ###

  destroy: ->
    editSession.destroy() for editSession in @getEditSessions()
    buffer.release() for buffer in @getBuffers()
    if @repo?
      @repo.destroy()
      @repo = null

  ### Public ###

  # Establishes a new project at a given path.
  #
  # path - The {String} name of the path
  constructor: (pathOrState) ->
    @editSessions = []
    @buffers = []

    if pathOrState instanceof telepath.Document
      @state = pathOrState
      if projectPath = @state.remove('path')
        @setPath(projectPath)
      else
        @setPath(@constructor.pathForRepositoryUrl(@state.get('repoUrl')))

      @state.get('buffers').each (bufferState) =>
        if buffer = deserialize(bufferState, project: this)
          @addBuffer(buffer, updateState: false)
    else
      @state = site.createDocument(deserializer: @constructor.name, version: @constructor.version, buffers: [])
      @setPath(pathOrState)

    @state.get('buffers').on 'changed', ({inserted, removed, index, site}) =>
      return if site is @state.site.id

      for removedBuffer in removed
        @removeBufferAtIndex(index, updateState: false)
      for insertedBuffer, i in inserted
        @addBufferAtIndex(deserialize(insertedBuffer, project: this), index + i, updateState: false)

  serialize: ->
    state = @state.clone()
    state.set('path', @getPath())
    state.set('buffers', buffer.serialize() for buffer in @getBuffers())
    state

  getState: -> @state

  getRepo: -> @repo

  # Retrieves the project path.
  #
  # Returns a {String}.
  getPath: ->
    @rootDirectory?.path

  # Sets the project path.
  #
  # projectPath - A {String} representing the new path
  setPath: (projectPath) ->
    @rootDirectory?.off()

    if projectPath?
      directory = if fsUtils.isDirectorySync(projectPath) then projectPath else path.dirname(projectPath)
      @rootDirectory = new Directory(directory)
      @repo = Git.open(projectPath)
    else
      @rootDirectory = null
      if @repo?
        @repo.destroy()
        @repo = null

    if originUrl = @repo?.getOriginUrl()
      @state.set('repoUrl', originUrl)

    @trigger "path-changed"

  # Retrieves the name of the root directory.
  #
  # Returns a {String}.
  getRootDirectory: ->
    @rootDirectory

  # Retrieves the names of every file (that's not `git ignore`d) in the project.
  #
  # Returns an {Array} of {String}s.
  getFilePaths: ->
    deferred = $.Deferred()
    paths = []
    onFile = (path) => paths.push(path) unless @isPathIgnored(path)
    onDirectory = -> true
    fsUtils.traverseTreeSync(@getPath(), onFile, onDirectory)
    deferred.resolve(paths)
    deferred.promise()

  # Identifies if a path is ignored.
  #
  # path - The {String} name of the path to check
  #
  # Returns a {Boolean}.
  isPathIgnored: (path) ->
    for segment in path.split("/")
      ignoredNames = config.get("core.ignoredNames") or []
      return true if _.contains(ignoredNames, segment)

    @ignoreRepositoryPath(path)

  # Identifies if a path is ignored.
  #
  # repositoryPath - The {String} name of the path to check
  #
  # Returns a {Boolean}.
  ignoreRepositoryPath: (repositoryPath) ->
    config.get("core.hideGitIgnoredFiles") and @repo?.isPathIgnored(path.join(@getPath(), repositoryPath))

  # Given a uri, this resolves it relative to the project directory. If the path
  # is already absolute or if it is prefixed with a scheme, it is returned unchanged.
  #
  # uri - The {String} name of the path to convert
  #
  # Returns a {String}.
  resolve: (uri) ->
    if uri?.match(/[A-Za-z0-9+-.]+:\/\//) # leave path alone if it has a scheme
      uri
    else
      uri = path.join(@getPath(), uri) unless uri[0] == '/'
      fsUtils.absolute uri

  # Given a path, this makes it relative to the project directory.
  #
  # fullPath - The {String} path to convert.
  #
  # Returns a {String}.
  relativize: (fullPath) ->
    @rootDirectory?.relativize(fullPath) ? fullPath

  # Is the given path inside this project?
  #
  # pathToCheck - the {String} path to check.
  #
  # Returns a {Boolean}.
  contains: (pathToCheck) ->
    @rootDirectory?.contains(pathToCheck) ? false

  # Given a path to a file, this constructs and associates a new `EditSession`, showing the file.
  #
  # filePath - The {String} path of the file to associate with
  # editSessionOptions - Options that you can pass to the `EditSession` constructor
  #
  # Returns either an {EditSession} (for text) or {ImageEditSession} (for images).
  open: (filePath, options={}) ->
    filePath = @resolve(filePath) if filePath?
    for opener in @constructor.openers
      return resource if resource = opener(filePath, options)

    @buildEditSessionForBuffer(@bufferForPath(filePath), options)

  # Retrieves all the {EditSession}s in the project; that is, the `EditSession`s for all open files.
  #
  # Returns an {Array} of {EditSession}s.
  getEditSessions: ->
    new Array(@editSessions...)

  addEditSession: (editSession) ->
    @editSessions.push editSession
    @trigger 'edit-session-created', editSession

  ### Public ###

  # Removes an {EditSession} association from the project.
  #
  # Returns the removed {EditSession}.
  removeEditSession: (editSession) ->
    _.remove(@editSessions, editSession)

  # Retrieves all the {Buffer}s in the project; that is, the buffers for all open files.
  #
  # Returns an {Array} of {Buffer}s.
  getBuffers: ->
    new Array(@buffers...)

  # Given a file path, this retrieves or creates a new {Buffer}.
  #
  # If the `filePath` already has a `buffer`, that value is used instead. Otherwise,
  # `text` is used as the contents of the new buffer.
  #
  # filePath - A {String} representing a path. If `null`, an "Untitled" buffer is created.
  # text - The {String} text to use as a buffer, if the file doesn't have any contents
  #
  # Returns the {Buffer}.
  bufferForPath: (filePath, text) ->
    if filePath?
      filePath = @resolve(filePath)
      if filePath
        buffer = _.find @buffers, (buffer) -> buffer.getPath() == filePath
        buffer or @buildBuffer(filePath, text)
    else
      @buildBuffer(null, text)

  bufferForId: (id) ->
    _.find @buffers, (buffer) -> buffer.id is id

  # Given a file path, this sets its {Buffer}.
  #
  # filePath - A {String} representing a path
  # text - The {String} text to use as a buffer
  #
  # Returns the {Buffer}.
  buildBuffer: (filePath, initialText) ->
    filePath = @resolve(filePath) if filePath?
    buffer = new TextBuffer({project: this, filePath, initialText})
    @addBuffer(buffer)
    @trigger 'buffer-created', buffer
    buffer

  addBuffer: (buffer, options={}) ->
    @addBufferAtIndex(buffer, @buffers.length, options)

  addBufferAtIndex: (buffer, index, options={}) ->
    @buffers[index] = buffer
    @state.get('buffers').insert(index, buffer.getState()) if options.updateState ? true

  # Removes a {Buffer} association from the project.
  #
  # Returns the removed {Buffer}.
  removeBuffer: (buffer) ->
    index = @buffers.indexOf(buffer)
    @removeBufferAtIndex(index) unless index is -1

  removeBufferAtIndex: (index, options={}) ->
    [buffer] = @buffers.splice(index, 1)
    @state.get('buffers').remove(index) if options.updateState ? true
    buffer?.destroy()

  # Performs a search across all the files in the project.
  #
  # regex - A {RegExp} to search with
  # iterator - A {Function} callback on each file found
  scan: (regex, iterator) ->
    bufferedData = ""
    state = 'readingPath'
    filePath = null

    readPath = (line) ->
      if /^[0-9,; ]+:/.test(line)
        state = 'readingLines'
      else if /^:/.test line
        filePath = line.substr(1)
      else
        filePath += ('\n' + line)

    readLine = (line) ->
      if line.length == 0
        state = 'readingPath'
        filePath = null
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
        iterator({path: filePath, range, match})

    deferred = $.Deferred()
    errors = []
    stderr = (data) ->
      errors.push(data)
    stdout = (data) ->
      lines = data.split('\n')
      lines.pop() # the last segment is a spurious '' because data always ends in \n due to bufferLines: true
      for line in lines
        readPath(line) if state is 'readingPath'
        readLine(line) if state is 'readingLines'
    exit = (code) ->
      if code is 0
        deferred.resolve()
      else
        console.error("Project scan failed: #{code}", errors.join('\n'))
        deferred.reject({command, code})

    command = require.resolve('.bin/nak')
    args = ['--hidden', '--ackmate', regex.source, @getPath()]
    ignoredNames = config.get('core.ignoredNames') ? []
    args.unshift('--ignore', ignoredNames.join(',')) if ignoredNames.length > 0
    args.unshift('--addVCSIgnores') if config.get('core.excludeVcsIgnoredPaths')
    new BufferedNodeProcess({command, args, stdout, stderr, exit})
    deferred

  ### Internal ###

  buildEditSessionForBuffer: (buffer, editSessionOptions) ->
    editSession = new EditSession(_.extend({buffer}, editSessionOptions))
    @addEditSession(editSession)
    editSession

  eachEditSession: (callback) ->
    callback(editSession) for editSession in @getEditSessions()
    @on 'edit-session-created', (editSession) -> callback(editSession)

  eachBuffer: (args...) ->
    subscriber = args.shift() if args.length > 1
    callback = args.shift()

    callback(buffer) for buffer in @getBuffers()
    if subscriber
      subscriber.subscribe this, 'buffer-created', (buffer) -> callback(buffer)
    else
      @on 'buffer-created', (buffer) -> callback(buffer)

_.extend Project.prototype, EventEmitter
