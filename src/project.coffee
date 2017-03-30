path = require 'path'

_ = require 'underscore-plus'
fs = require 'fs-plus'
{Emitter, Disposable} = require 'event-kit'
TextBuffer = require 'text-buffer'

DefaultDirectoryProvider = require './default-directory-provider'
Model = require './model'
GitRepositoryProvider = require './git-repository-provider'

# Extended: Represents a project that's opened in Atom.
#
# An instance of this class is always available as the `atom.project` global.
module.exports =
class Project extends Model
  ###
  Section: Construction and Destruction
  ###

  constructor: ({@notificationManager, packageManager, config, @applicationDelegate}) ->
    @emitter = new Emitter
    @buffers = []
    @rootDirectories = []
    @repositories = []
    @directoryProviders = []
    @defaultDirectoryProvider = new DefaultDirectoryProvider()
    @repositoryPromisesByPath = new Map()
    @repositoryProviders = [new GitRepositoryProvider(this, config)]
    @consumeServices(packageManager)

  destroyed: ->
    buffer.destroy() for buffer in @buffers.slice()
    repository?.destroy() for repository in @repositories.slice()
    @rootDirectories = []
    @repositories = []

  reset: (packageManager) ->
    @emitter.dispose()
    @emitter = new Emitter

    buffer?.destroy() for buffer in @buffers
    @buffers = []
    @setPaths([])
    @consumeServices(packageManager)

  destroyUnretainedBuffers: ->
    buffer.destroy() for buffer in @getBuffers() when not buffer.isRetained()
    return

  ###
  Section: Serialization
  ###

  deserialize: (state) ->
    state.paths = [state.path] if state.path? # backward compatibility

    @buffers = _.compact state.buffers.map (bufferState) ->
      # Check that buffer's file path is accessible
      return if fs.isDirectorySync(bufferState.filePath)
      if bufferState.filePath
        try
          fs.closeSync(fs.openSync(bufferState.filePath, 'r'))
        catch error
          return unless error.code is 'ENOENT'
      unless bufferState.shouldDestroyOnFileDelete?
        bufferState.shouldDestroyOnFileDelete =
          -> atom.config.get('core.closeDeletedFileTabs')
      TextBuffer.deserialize(bufferState)

    @subscribeToBuffer(buffer) for buffer in @buffers
    @setPaths(state.paths)

  serialize: (options={}) ->
    deserializer: 'Project'
    paths: @getPaths()
    buffers: _.compact(@buffers.map (buffer) ->
      if buffer.isRetained()
        state = buffer.serialize({markerLayers: options.isUnloading is true})
        # Skip saving large buffer text unless unloading to avoid blocking main thread
        if not options.isUnloading and state.text.length > 2 * 1024 * 1024
          delete state.text
          delete state.digestWhenLastPersisted
        state
    )

  ###
  Section: Event Subscription
  ###

  # Public: Invoke the given callback when the project paths change.
  #
  # * `callback` {Function} to be called after the project paths change.
  #    * `projectPaths` An {Array} of {String} project paths.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChangePaths: (callback) ->
    @emitter.on 'did-change-paths', callback

  # Public: Invoke the given callback when a text buffer is added to the
  # project.
  #
  # * `callback` {Function} to be called when a text buffer is added.
  #   * `buffer` A {TextBuffer} item.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidAddBuffer: (callback) ->
    @emitter.on 'did-add-buffer', callback

  # Public: Invoke the given callback with all current and future text
  # buffers in the project.
  #
  # * `callback` {Function} to be called with current and future text buffers.
  #   * `buffer` A {TextBuffer} item.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  observeBuffers: (callback) ->
    callback(buffer) for buffer in @getBuffers()
    @onDidAddBuffer callback

  ###
  Section: Accessing the git repository
  ###

  # Public: Get an {Array} of {GitRepository}s associated with the project's
  # directories.
  #
  # This method will be removed in 2.0 because it does synchronous I/O.
  # Prefer the following, which evaluates to a {Promise} that resolves to an
  # {Array} of {Repository} objects:
  # ```
  # Promise.all(atom.project.getDirectories().map(
  #     atom.project.repositoryForDirectory.bind(atom.project)))
  # ```
  getRepositories: -> @repositories

  # Public: Get the repository for a given directory asynchronously.
  #
  # * `directory` {Directory} for which to get a {Repository}.
  #
  # Returns a {Promise} that resolves with either:
  # * {Repository} if a repository can be created for the given directory
  # * `null` if no repository can be created for the given directory.
  repositoryForDirectory: (directory) ->
    pathForDirectory = directory.getRealPathSync()
    promise = @repositoryPromisesByPath.get(pathForDirectory)
    unless promise
      promises = @repositoryProviders.map (provider) ->
        provider.repositoryForDirectory(directory)
      promise = Promise.all(promises).then (repositories) =>
        repo = _.find(repositories, (repo) -> repo?) ? null

        # If no repository is found, remove the entry in for the directory in
        # @repositoryPromisesByPath in case some other RepositoryProvider is
        # registered in the future that could supply a Repository for the
        # directory.
        @repositoryPromisesByPath.delete(pathForDirectory) unless repo?
        repo?.onDidDestroy?(=> @repositoryPromisesByPath.delete(pathForDirectory))
        repo
      @repositoryPromisesByPath.set(pathForDirectory, promise)
    promise

  ###
  Section: Managing Paths
  ###

  # Public: Get an {Array} of {String}s containing the paths of the project's
  # directories.
  getPaths: -> rootDirectory.getPath() for rootDirectory in @rootDirectories

  # Public: Set the paths of the project's directories.
  #
  # * `projectPaths` {Array} of {String} paths.
  setPaths: (projectPaths) ->
    repository?.destroy() for repository in @repositories
    @rootDirectories = []
    @repositories = []

    @addPath(projectPath, emitEvent: false) for projectPath in projectPaths

    @emitter.emit 'did-change-paths', projectPaths

  # Public: Add a path to the project's list of root paths
  #
  # * `projectPath` {String} The path to the directory to add.
  addPath: (projectPath, options) ->
    directory = @getDirectoryForProjectPath(projectPath)
    return unless directory.existsSync()
    for existingDirectory in @getDirectories()
      return if existingDirectory.getPath() is directory.getPath()

    @rootDirectories.push(directory)

    repo = null
    for provider in @repositoryProviders
      break if repo = provider.repositoryForDirectorySync?(directory)
    @repositories.push(repo ? null)

    unless options?.emitEvent is false
      @emitter.emit 'did-change-paths', @getPaths()

  getDirectoryForProjectPath: (projectPath) ->
    directory = null
    for provider in @directoryProviders
      break if directory = provider.directoryForURISync?(projectPath)
    directory ?= @defaultDirectoryProvider.directoryForURISync(projectPath)
    directory

  # Public: remove a path from the project's list of root paths.
  #
  # * `projectPath` {String} The path to remove.
  removePath: (projectPath) ->
    # The projectPath may be a URI, in which case it should not be normalized.
    unless projectPath in @getPaths()
      projectPath = @defaultDirectoryProvider.normalizePath(projectPath)

    indexToRemove = null
    for directory, i in @rootDirectories
      if directory.getPath() is projectPath
        indexToRemove = i
        break

    if indexToRemove?
      [removedDirectory] = @rootDirectories.splice(indexToRemove, 1)
      [removedRepository] = @repositories.splice(indexToRemove, 1)
      removedRepository?.destroy() unless removedRepository in @repositories
      @emitter.emit "did-change-paths", @getPaths()
      true
    else
      false

  # Public: Get an {Array} of {Directory}s associated with this project.
  getDirectories: ->
    @rootDirectories

  resolvePath: (uri) ->
    return unless uri

    if uri?.match(/[A-Za-z0-9+-.]+:\/\//) # leave path alone if it has a scheme
      uri
    else
      if fs.isAbsolute(uri)
        @defaultDirectoryProvider.normalizePath(fs.resolveHome(uri))
      # TODO: what should we do here when there are multiple directories?
      else if projectPath = @getPaths()[0]
        @defaultDirectoryProvider.normalizePath(fs.resolveHome(path.join(projectPath, uri)))
      else
        undefined

  relativize: (fullPath) ->
    @relativizePath(fullPath)[1]

  # Public: Get the path to the project directory that contains the given path,
  # and the relative path from that project directory to the given path.
  #
  # * `fullPath` {String} An absolute path.
  #
  # Returns an {Array} with two elements:
  # * `projectPath` The {String} path to the project directory that contains the
  #   given path, or `null` if none is found.
  # * `relativePath` {String} The relative path from the project directory to
  #   the given path.
  relativizePath: (fullPath) ->
    result = [null, fullPath]
    if fullPath?
      for rootDirectory in @rootDirectories
        relativePath = rootDirectory.relativize(fullPath)
        if relativePath?.length < result[1].length
          result = [rootDirectory.getPath(), relativePath]
    result

  # Public: Determines whether the given path (real or symbolic) is inside the
  # project's directory.
  #
  # This method does not actually check if the path exists, it just checks their
  # locations relative to each other.
  #
  # ## Examples
  #
  # Basic operation
  #
  # ```coffee
  # # Project's root directory is /foo/bar
  # project.contains('/foo/bar/baz')        # => true
  # project.contains('/usr/lib/baz')        # => false
  # ```
  #
  # Existence of the path is not required
  #
  # ```coffee
  # # Project's root directory is /foo/bar
  # fs.existsSync('/foo/bar/baz')           # => false
  # project.contains('/foo/bar/baz')        # => true
  # ```
  #
  # * `pathToCheck` {String} path
  #
  # Returns whether the path is inside the project's root directory.
  contains: (pathToCheck) ->
    @rootDirectories.some (dir) -> dir.contains(pathToCheck)

  ###
  Section: Private
  ###

  consumeServices: ({serviceHub}) ->
    serviceHub.consume(
      'atom.directory-provider',
      '^0.1.0',
      (provider) =>
        @directoryProviders.unshift(provider)
        new Disposable =>
          @directoryProviders.splice(@directoryProviders.indexOf(provider), 1)
    )

    serviceHub.consume(
      'atom.repository-provider',
      '^0.1.0',
      (provider) =>
        @repositoryProviders.unshift(provider)
        @setPaths(@getPaths()) if null in @repositories
        new Disposable =>
          @repositoryProviders.splice(@repositoryProviders.indexOf(provider), 1)
    )

  # Retrieves all the {TextBuffer}s in the project; that is, the
  # buffers for all open files.
  #
  # Returns an {Array} of {TextBuffer}s.
  getBuffers: ->
    @buffers.slice()

  # Is the buffer for the given path modified?
  isPathModified: (filePath) ->
    @findBufferForPath(@resolvePath(filePath))?.isModified()

  findBufferForPath: (filePath) ->
    _.find @buffers, (buffer) -> buffer.getPath() is filePath

  findBufferForId: (id) ->
    _.find @buffers, (buffer) -> buffer.getId() is id

  # Only to be used in specs
  bufferForPathSync: (filePath) ->
    absoluteFilePath = @resolvePath(filePath)
    existingBuffer = @findBufferForPath(absoluteFilePath) if filePath
    existingBuffer ? @buildBufferSync(absoluteFilePath)

  # Only to be used when deserializing
  bufferForIdSync: (id) ->
    existingBuffer = @findBufferForId(id) if id
    existingBuffer ? @buildBufferSync()

  # Given a file path, this retrieves or creates a new {TextBuffer}.
  #
  # If the `filePath` already has a `buffer`, that value is used instead. Otherwise,
  # `text` is used as the contents of the new buffer.
  #
  # * `filePath` A {String} representing a path. If `null`, an "Untitled" buffer is created.
  #
  # Returns a {Promise} that resolves to the {TextBuffer}.
  bufferForPath: (absoluteFilePath) ->
    existingBuffer = @findBufferForPath(absoluteFilePath) if absoluteFilePath?
    if existingBuffer
      Promise.resolve(existingBuffer)
    else
      @buildBuffer(absoluteFilePath)

  shouldDestroyBufferOnFileDelete: ->
    atom.config.get('core.closeDeletedFileTabs')

  # Still needed when deserializing a tokenized buffer
  buildBufferSync: (absoluteFilePath) ->
    buffer = new TextBuffer({
      filePath: absoluteFilePath
      shouldDestroyOnFileDelete: @shouldDestroyBufferOnFileDelete})
    @addBuffer(buffer)
    buffer.loadSync()
    buffer

  # Given a file path, this sets its {TextBuffer}.
  #
  # * `absoluteFilePath` A {String} representing a path.
  # * `text` The {String} text to use as a buffer.
  #
  # Returns a {Promise} that resolves to the {TextBuffer}.
  buildBuffer: (absoluteFilePath) ->
    buffer = new TextBuffer({
      filePath: absoluteFilePath
      shouldDestroyOnFileDelete: @shouldDestroyBufferOnFileDelete})
    @addBuffer(buffer)
    buffer.load()
      .then((buffer) -> buffer)
      .catch(=> @removeBuffer(buffer))

  addBuffer: (buffer, options={}) ->
    @addBufferAtIndex(buffer, @buffers.length, options)

  addBufferAtIndex: (buffer, index, options={}) ->
    @buffers.splice(index, 0, buffer)
    @subscribeToBuffer(buffer)
    @emitter.emit 'did-add-buffer', buffer
    buffer

  # Removes a {TextBuffer} association from the project.
  #
  # Returns the removed {TextBuffer}.
  removeBuffer: (buffer) ->
    index = @buffers.indexOf(buffer)
    @removeBufferAtIndex(index) unless index is -1

  removeBufferAtIndex: (index, options={}) ->
    [buffer] = @buffers.splice(index, 1)
    buffer?.destroy()

  eachBuffer: (args...) ->
    subscriber = args.shift() if args.length > 1
    callback = args.shift()

    callback(buffer) for buffer in @getBuffers()
    if subscriber
      subscriber.subscribe this, 'buffer-created', (buffer) -> callback(buffer)
    else
      @on 'buffer-created', (buffer) -> callback(buffer)

  subscribeToBuffer: (buffer) ->
    buffer.onWillSave ({path}) => @applicationDelegate.emitWillSavePath(path)
    buffer.onDidSave ({path}) => @applicationDelegate.emitDidSavePath(path)
    buffer.onDidDestroy => @removeBuffer(buffer)
    buffer.onDidChangePath =>
      unless @getPaths().length > 0
        @setPaths([path.dirname(buffer.getPath())])
    buffer.onWillThrowWatchError ({error, handle}) =>
      handle()
      @notificationManager.addWarning """
        Unable to read file after file `#{error.eventType}` event.
        Make sure you have permission to access `#{buffer.getPath()}`.
        """,
        detail: error.message
        dismissable: true
