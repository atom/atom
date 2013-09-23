fsUtils = require './fs-utils'
path = require 'path'
url = require 'url'
{PathSearcher, PathScanner, search} = require 'scandal'

_ = require './underscore-extensions'
$ = require './jquery-extensions'
telepath = require 'telepath'
{Range} = telepath
TextBuffer = require './text-buffer'
EditSession = require './edit-session'
EventEmitter = require './event-emitter'
Directory = require './directory'
Git = require './git'

# Public: Represents a project that's opened in Atom.
#
# Ultimately, a project is a git directory that's been opened. It's a collection
# of directories and files that you can operate on.
module.exports =
class Project
  _.extend @prototype, EventEmitter

  @acceptsDocuments: true
  @version: 1

  registerDeserializer(this)

  # Private:
  @deserialize: (state) -> new Project(state)

  # Public: Find the local path for the given repository URL.
  @pathForRepositoryUrl: (repoUrl) ->
    [repoName] = url.parse(repoUrl).path.split('/')[-1..]
    repoName = repoName.replace(/\.git$/, '')
    path.join(config.get('core.projectHome'), repoName)

  rootDirectory: null
  editSessions: null
  ignoredPathRegexes: null
  openers: null

  # Public:
  registerOpener: (opener) -> @openers.push(opener)

  # Public:
  unregisterOpener: (opener) -> _.remove(@openers, opener)

  # Private:
  destroy: ->
    editSession.destroy() for editSession in @getEditSessions()
    buffer.release() for buffer in @getBuffers()
    @destroyRepo()

  # Private:
  destroyRepo: ->
    if @repo?
      @repo.destroy()
      @repo = null

  # Public: Establishes a new project at a given path.
  #
  # path - The {String} name of the path
  constructor: (pathOrState) ->
    @openers = []
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

  # Private:
  serialize: ->
    state = @state.clone()
    state.set('path', @getPath())
    @destroyUnretainedBuffers()
    state.set('buffers', buffer.serialize() for buffer in @getBuffers())
    state

  # Private:
  destroyUnretainedBuffers: ->
    buffer.destroy() for buffer in @getBuffers() when not buffer.isRetained()

  # Public: ?
  getState: -> @state

  # Public: Returns the {Git} repository if available.
  getRepo: -> @repo

  # Public: Returns the project's fullpath.
  getPath: ->
    @rootDirectory?.path

  # Public: Sets the project's fullpath.
  setPath: (projectPath) ->
    @rootDirectory?.off()

    @destroyRepo()
    if projectPath?
      directory = if fsUtils.isDirectorySync(projectPath) then projectPath else path.dirname(projectPath)
      @rootDirectory = new Directory(directory)
      @repo = Git.open(projectPath, project: this)
    else
      @rootDirectory = null

    if originUrl = @repo?.getOriginUrl()
      @state.set('repoUrl', originUrl)

    @trigger "path-changed"

  # Public: Returns the name of the root directory.
  getRootDirectory: ->
    @rootDirectory

  # Public: Fetches the name of every file (that's not `git ignore`d) in the
  # project.
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

  # Public: Determines if a path is ignored via Atom configuration.
  isPathIgnored: (path) ->
    for segment in path.split("/")
      ignoredNames = config.get("core.ignoredNames") or []
      return true if _.contains(ignoredNames, segment)

    @ignoreRepositoryPath(path)

  # Public: Determines if a given path is ignored via repository configuration.
  ignoreRepositoryPath: (repositoryPath) ->
    config.get("core.hideGitIgnoredFiles") and @repo?.isPathIgnored(path.join(@getPath(), repositoryPath))

  # Public: Given a uri, this resolves it relative to the project directory. If
  # the path is already absolute or if it is prefixed with a scheme, it is
  # returned unchanged.
  #
  # * uri:
  #   The String name of the path to convert
  #
  # Returns a String.
  resolve: (uri) ->
    if uri?.match(/[A-Za-z0-9+-.]+:\/\//) # leave path alone if it has a scheme
      uri
    else
      uri = path.join(@getPath(), uri) unless uri[0] == '/'
      fsUtils.absolute uri

  # Public: Make the given path relative to the project directory.
  relativize: (fullPath) ->
    @rootDirectory?.relativize(fullPath) ? fullPath

  # Public: Returns whether the given path is inside this project.
  contains: (pathToCheck) ->
    @rootDirectory?.contains(pathToCheck) ? false

  # Public: Given a path to a file, this constructs and associates a new
  # {EditSession}, showing the file.
  #
  # * filePath:
  #   The {String} path of the file to associate with
  # * editSessionOptions:
  #   Options that you can pass to the {EditSession} constructor
  #
  # Returns an {EditSession}.
  open: (filePath, options={}) ->
    filePath = @resolve(filePath) if filePath?
    for opener in @openers
      return resource if resource = opener(filePath, options)

    @buildEditSessionForBuffer(@bufferForPath(filePath), options)

  # Public: Retrieves all {EditSession}s for all open files.
  #
  # Returns an {Array} of {EditSession}s.
  getEditSessions: ->
    new Array(@editSessions...)

  # Public: Add the given {EditSession}.
  addEditSession: (editSession) ->
    @editSessions.push editSession
    @trigger 'edit-session-created', editSession

  # Public: Return and removes the given {EditSession}.
  removeEditSession: (editSession) ->
    _.remove(@editSessions, editSession)

  # Private: Retrieves all the {TextBuffer}s in the project; that is, the
  # buffers for all open files.
  #
  # Returns an {Array} of {TextBuffer}s.
  getBuffers: ->
    new Array(@buffers...)

  # Private: Given a file path, this retrieves or creates a new {TextBuffer}.
  #
  # If the `filePath` already has a `buffer`, that value is used instead. Otherwise,
  # `text` is used as the contents of the new buffer.
  #
  # filePath - A {String} representing a path. If `null`, an "Untitled" buffer is created.
  # text - The {String} text to use as a buffer, if the file doesn't have any contents
  #
  # Returns the {TextBuffer}.
  bufferForPath: (filePath, text) ->
    if filePath?
      filePath = @resolve(filePath)
      if filePath
        buffer = _.find @buffers, (buffer) -> buffer.getPath() == filePath
        buffer or @buildBuffer(filePath, text)
    else
      @buildBuffer(null, text)

  # Private:
  bufferForId: (id) ->
    _.find @buffers, (buffer) -> buffer.id is id

  # Private: Given a file path, this sets its {TextBuffer}.
  #
  # filePath - A {String} representing a path
  # text - The {String} text to use as a buffer
  #
  # Returns the {TextBuffer}.
  buildBuffer: (filePath, initialText) ->
    filePath = @resolve(filePath) if filePath?
    buffer = new TextBuffer({project: this, filePath, initialText})
    @addBuffer(buffer)
    buffer

  # Private:
  addBuffer: (buffer, options={}) ->
    @addBufferAtIndex(buffer, @buffers.length, options)

  # Private:
  addBufferAtIndex: (buffer, index, options={}) ->
    @buffers[index] = buffer
    @state.get('buffers').insert(index, buffer.getState()) if options.updateState ? true
    @trigger 'buffer-created', buffer

  # Private: Removes a {TextBuffer} association from the project.
  #
  # Returns the removed {TextBuffer}.
  removeBuffer: (buffer) ->
    index = @buffers.indexOf(buffer)
    @removeBufferAtIndex(index) unless index is -1

  # Private:
  removeBufferAtIndex: (index, options={}) ->
    [buffer] = @buffers.splice(index, 1)
    @state.get('buffers').remove(index) if options.updateState ? true
    buffer?.destroy()

  # Public: Performs a search across all the files in the project.
  #
  # * regex:
  #   A RegExp to search with
  # * options:
  #   - paths: an {Array} of glob patterns to search within
  # * iterator:
  #   A Function callback on each file found
  scan: (regex, options={}, iterator) ->
    if _.isFunction(options)
      iterator = options
      options = {}

    deferred = $.Deferred()
    searchOptions =
      inclusions: options.paths
      includeHidden: true
      excludeVcsIgnores: config.get('core.excludeVcsIgnoredPaths')
      # args.unshift('--ignore', ignoredNames.join(',')) if ignoredNames.length > 0

    searcher = new PathSearcher()
    scanner = new PathScanner(@getPath(), searchOptions)

    searcher.on 'results-found', (result) ->
      iterator(result)

    search regex, scanner, searcher, ->
      deferred.resolve()

    deferred

  # Private:
  buildEditSessionForBuffer: (buffer, editSessionOptions) ->
    editSession = new EditSession(_.extend({buffer}, editSessionOptions))
    @addEditSession(editSession)
    editSession

  # Private:
  eachEditSession: (callback) ->
    callback(editSession) for editSession in @getEditSessions()
    @on 'edit-session-created', (editSession) -> callback(editSession)

  # Private:
  eachBuffer: (args...) ->
    subscriber = args.shift() if args.length > 1
    callback = args.shift()

    callback(buffer) for buffer in @getBuffers()
    if subscriber
      subscriber.subscribe this, 'buffer-created', (buffer) -> callback(buffer)
    else
      @on 'buffer-created', (buffer) -> callback(buffer)
