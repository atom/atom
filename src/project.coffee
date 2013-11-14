path = require 'path'
url = require 'url'

_ = require 'underscore-plus'
fs = require 'fs-plus'
Q = require 'q'
telepath = require 'telepath'
{Model, Range} = telepath

TextBuffer = require './text-buffer'
EditSession = require './edit-session'
{Emitter} = require 'emissary'
Directory = require './directory'
Task = require './task'
Git = require './git'

# Public: Represents a project that's opened in Atom.
#
# Ultimately, a project is a git directory that's been opened. It's a collection
# of directories and files that you can operate on.
module.exports =
class Project extends Model
  Emitter.includeInto(this)

  @properties
    buffers: []
    path: null

  # Public: Find the local path for the given repository URL.
  @pathForRepositoryUrl: (repoUrl) ->
    [repoName] = url.parse(repoUrl).path.split('/')[-1..]
    repoName = repoName.replace(/\.git$/, '')
    path.join(atom.config.get('core.projectHome'), repoName)

  # Private:
  attached: ->
    @openers = []
    @editSessions = []
    @setPath(@path)

  # Private:
  beforePersistence: ->
    @destroyUnretainedBuffers()

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

  # Private:
  destroyUnretainedBuffers: ->
    buffer.destroy() for buffer in @getBuffers() when not buffer.isRetained()

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
      directory = if fs.isDirectorySync(projectPath) then projectPath else path.dirname(projectPath)
      @rootDirectory = new Directory(directory)
      if @repo = Git.open(projectPath, project: this)
        @repo.refreshIndex()
        @repo.refreshStatus()
    else
      @rootDirectory = null

    @emit "path-changed"

  # Public: Returns the name of the root directory.
  getRootDirectory: ->
    @rootDirectory

  # Public: Determines if a path is ignored via Atom configuration.
  isPathIgnored: (path) ->
    for segment in path.split("/")
      ignoredNames = atom.config.get("core.ignoredNames") or []
      return true if _.contains(ignoredNames, segment)

    @ignoreRepositoryPath(path)

  # Public: Determines if a given path is ignored via repository configuration.
  ignoreRepositoryPath: (repositoryPath) ->
    atom.config.get("core.hideGitIgnoredFiles") and @repo?.isPathIgnored(path.join(@getPath(), repositoryPath))

  # Public: Given a uri, this resolves it relative to the project directory. If
  # the path is already absolute or if it is prefixed with a scheme, it is
  # returned unchanged.
  #
  # * uri:
  #   The String name of the path to convert
  #
  # Returns a String.
  resolve: (uri) ->
    return unless uri

    if uri?.match(/[A-Za-z0-9+-.]+:\/\//) # leave path alone if it has a scheme
      uri
    else
      uri = path.join(@getPath(), uri) unless fs.isAbsolute(uri)
      fs.absolute uri

  # Public: Make the given path relative to the project directory.
  relativize: (fullPath) ->
    return fullPath if fullPath?.match(/[A-Za-z0-9+-.]+:\/\//) # leave path alone if it has a scheme
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
  # Returns a promise that resolves to an {EditSession}.
  open: (filePath, options={}) ->
    filePath = @resolve(filePath)
    resource = null
    _.find @openers, (opener) -> resource = opener(filePath, options)

    if resource
      Q(resource)
    else
      @bufferForPath(filePath).then (buffer) =>
        @buildEditSessionForBuffer(buffer, options)

  # Private: Only be used in specs
  openSync: (filePath, options={}) ->
    filePath = @resolve(filePath)
    for opener in @openers
      return resource if resource = opener(filePath, options)

    @buildEditSessionForBuffer(@bufferForPathSync(filePath), options)

  # Public: Retrieves all {EditSession}s for all open files.
  #
  # Returns an {Array} of {EditSession}s.
  getEditSessions: ->
    new Array(@editSessions...)

  # Public: Add the given {EditSession}.
  addEditSession: (editSession) ->
    @editSessions.push editSession
    @emit 'edit-session-created', editSession

  # Public: Return and removes the given {EditSession}.
  removeEditSession: (editSession) ->
    _.remove(@editSessions, editSession)

  # Private: Retrieves all the {TextBuffer}s in the project; that is, the
  # buffers for all open files.
  #
  # Returns an {Array} of {TextBuffer}s.
  getBuffers: ->
    new Array(@buffers.getValues()...)

  isPathModified: (filePath) ->
    @findBufferForPath(@resolve(filePath))?.isModified()

  findBufferForPath: (filePath) ->
    _.find @buffers.getValues(), (buffer) -> buffer.getPath() == filePath

  # Private: Only to be used in specs
  bufferForPathSync: (filePath) ->
    absoluteFilePath = @resolve(filePath)
    existingBuffer = @findBufferForPath(absoluteFilePath) if filePath
    existingBuffer ? @buildBufferSync(absoluteFilePath)

  # Private: Given a file path, this retrieves or creates a new {TextBuffer}.
  #
  # If the `filePath` already has a `buffer`, that value is used instead. Otherwise,
  # `text` is used as the contents of the new buffer.
  #
  # filePath - A {String} representing a path. If `null`, an "Untitled" buffer is created.
  #
  # Returns a promise that resolves to the {TextBuffer}.
  bufferForPath: (filePath) ->
    absoluteFilePath = @resolve(filePath)
    existingBuffer = @findBufferForPath(absoluteFilePath) if absoluteFilePath
    Q(existingBuffer ? @buildBuffer(absoluteFilePath))

  # Private:
  bufferForId: (id) ->
    _.find @buffers, (buffer) -> buffer.id is id

  # Private: DEPRECATED
  buildBufferSync: (absoluteFilePath) ->
    buffer = new TextBuffer({filePath: absoluteFilePath})
    @addBuffer(buffer)
    buffer.loadSync()
    buffer

  # Private: Given a file path, this sets its {TextBuffer}.
  #
  # absoluteFilePath - A {String} representing a path
  # text - The {String} text to use as a buffer
  #
  # Returns a promise that resolves to the {TextBuffer}.
  buildBuffer: (absoluteFilePath) ->
    buffer = new TextBuffer({filePath: absoluteFilePath})
    @addBuffer(buffer)
    buffer.load()
      .then((buffer) -> buffer)
      .catch(=> @removeBuffer(buffer))

  # Private:
  addBuffer: (buffer, options={}) ->
    @addBufferAtIndex(buffer, @buffers.length, options)

  # Private:
  addBufferAtIndex: (buffer, index, options={}) ->
    buffer = @buffers.insert(index, buffer)
    buffer.once 'destroyed', => @removeBuffer(buffer)
    @emit 'buffer-created', buffer
    buffer

  # Private: Removes a {TextBuffer} association from the project.
  #
  # Returns the removed {TextBuffer}.
  removeBuffer: (buffer) ->
    index = @buffers.indexOf(buffer)
    @removeBufferAtIndex(index) unless index is -1

  # Private:
  removeBufferAtIndex: (index, options={}) ->
    [buffer] = @buffers.splice(index, 1)
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

    deferred = Q.defer()

    searchOptions =
      ignoreCase: regex.ignoreCase
      inclusions: options.paths
      includeHidden: true
      excludeVcsIgnores: atom.config.get('core.excludeVcsIgnoredPaths')
      exclusions: atom.config.get('core.ignoredNames')

    task = Task.once require.resolve('./scan-handler'), @getPath(), regex.source, searchOptions, ->
      deferred.resolve()

    task.on 'scan:result-found', (result) =>
      iterator(result) unless @isPathModified(result.filePath)

    if _.isFunction(options.onPathsSearched)
      task.on 'scan:paths-searched', (numberOfPathsSearched) ->
        options.onPathsSearched(numberOfPathsSearched)

    for buffer in @buffers.getValues() when buffer.isModified()
      filePath = buffer.getPath()
      matches = []
      buffer.scan regex, (match) -> matches.push match
      iterator {filePath, matches} if matches.length > 0

    deferred.promise

  # Public: Performs a replace across all the specified files in the project.
  #
  # * regex: A RegExp to search with
  # * replacementText: Text to replace all matches of regex with
  # * filePaths: List of file path strings to run the replace on.
  # * iterator: A Function callback on each file with replacements. ({filePath, replacements}) ->
  replace: (regex, replacementText, filePaths, iterator) ->
    deferred = Q.defer()

    openPaths = (buffer.getPath() for buffer in @buffers.getValues())
    outOfProcessPaths = _.difference(filePaths, openPaths)

    inProcessFinished = !openPaths.length
    outOfProcessFinished = !outOfProcessPaths.length
    checkFinished = ->
      deferred.resolve() if outOfProcessFinished and inProcessFinished

    unless outOfProcessFinished.length
      flags = 'g'
      flags += 'i' if regex.ignoreCase

      task = Task.once require.resolve('./replace-handler'), outOfProcessPaths, regex.source, flags, replacementText, ->
        outOfProcessFinished = true
        checkFinished()

      task.on 'replace:path-replaced', iterator

    for buffer in @buffers.getValues()
      replacements = buffer.replace(regex, replacementText, iterator)
      iterator({filePath: buffer.getPath(), replacements}) if replacements

    inProcessFinished = true
    checkFinished()

    deferred.promise

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
