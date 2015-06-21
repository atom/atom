path = require 'path'
url = require 'url'

_ = require 'underscore-plus'
fs = require 'fs-plus'
Q = require 'q'
{includeDeprecatedAPIs, deprecate} = require 'grim'
{Emitter} = require 'event-kit'
Serializable = require 'serializable'
TextBuffer = require 'text-buffer'
Grim = require 'grim'

DefaultDirectoryProvider = require './default-directory-provider'
Model = require './model'
TextEditor = require './text-editor'
Task = require './task'
GitRepositoryProvider = require './git-repository-provider'

# Extended: Represents a project that's opened in Atom.
#
# An instance of this class is always available as the `atom.project` global.
module.exports =
class Project extends Model
  atom.deserializers.add(this)
  Serializable.includeInto(this)

  ###
  Section: Construction and Destruction
  ###

  constructor: ({path, paths, @buffers}={}) ->
    @emitter = new Emitter
    @buffers ?= []
    @rootDirectories = []
    @repositories = []

    @directoryProviders = [new DefaultDirectoryProvider()]
    atom.packages.serviceHub.consume(
      'atom.directory-provider',
      '^0.1.0',
      # New providers are added to the front of @directoryProviders because
      # DefaultDirectoryProvider is a catch-all that will always provide a Directory.
      (provider) => @directoryProviders.unshift(provider))

    # Mapping from the real path of a {Directory} to a {Promise} that resolves
    # to either a {Repository} or null. Ideally, the {Directory} would be used
    # as the key; however, there can be multiple {Directory} objects created for
    # the same real path, so it is not a good key.
    @repositoryPromisesByPath = new Map()

    # Note that the GitRepositoryProvider is registered synchronously so that
    # it is available immediately on startup.
    @repositoryProviders = [new GitRepositoryProvider(this)]
    atom.packages.serviceHub.consume(
      'atom.repository-provider',
      '^0.1.0',
      (provider) =>
        @repositoryProviders.push(provider)

        # If a path in getPaths() does not have a corresponding Repository, try
        # to assign one by running through setPaths() again now that
        # @repositoryProviders has been updated.
        if null in @repositories
          @setPaths(@getPaths())
      )

    @subscribeToBuffer(buffer) for buffer in @buffers

    if Grim.includeDeprecatedAPIs and path?
      Grim.deprecate("Pass 'paths' array instead of 'path' to project constructor")

    paths ?= _.compact([path])
    @setPaths(paths)

  destroyed: ->
    buffer.destroy() for buffer in @getBuffers()
    @setPaths([])

  destroyUnretainedBuffers: ->
    buffer.destroy() for buffer in @getBuffers() when not buffer.isRetained()
    return

  ###
  Section: Serialization
  ###

  serializeParams: ->
    paths: @getPaths()
    buffers: _.compact(@buffers.map (buffer) -> buffer.serialize() if buffer.isRetained())

  deserializeParams: (params) ->
    params.buffers = _.compact params.buffers.map (bufferState) ->
      # Check that buffer's file path is accessible
      return if fs.isDirectorySync(bufferState.filePath)
      if bufferState.filePath
        try
          fs.closeSync(fs.openSync(bufferState.filePath, 'r'))
        catch error
          return unless error.code is 'ENOENT'

      atom.deserializers.deserialize(bufferState)
    params

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

  onDidAddBuffer: (callback) ->
    @emitter.on 'did-add-buffer', callback

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
    if includeDeprecatedAPIs
      rootDirectory.off() for rootDirectory in @rootDirectories

    repository?.destroy() for repository in @repositories
    @rootDirectories = []
    @repositories = []

    @addPath(projectPath, emitEvent: false) for projectPath in projectPaths

    @emit "path-changed" if includeDeprecatedAPIs
    @emitter.emit 'did-change-paths', projectPaths

  # Public: Add a path to the project's list of root paths
  #
  # * `projectPath` {String} The path to the directory to add.
  addPath: (projectPath, options) ->
    for directory in @getDirectories()
      # Apparently a Directory does not believe it can contain itself, so we
      # must also check whether the paths match.
      return if directory.contains(projectPath) or directory.getPath() is projectPath

    directory = null
    for provider in @directoryProviders
      break if directory = provider.directoryForURISync?(projectPath)
    if directory is null
      # This should never happen because DefaultDirectoryProvider should always
      # return a Directory.
      throw new Error(projectPath + ' could not be resolved to a directory')
    @rootDirectories.push(directory)

    repo = null
    for provider in @repositoryProviders
      break if repo = provider.repositoryForDirectorySync?(directory)
    @repositories.push(repo ? null)

    unless options?.emitEvent is false
      @emit "path-changed" if includeDeprecatedAPIs
      @emitter.emit 'did-change-paths', @getPaths()

  # Public: remove a path from the project's list of root paths.
  #
  # * `projectPath` {String} The path to remove.
  removePath: (projectPath) ->
    # The projectPath may be a URI, in which case it should not be normalized.
    unless projectPath in @getPaths()
      projectPath = path.normalize(projectPath)

    indexToRemove = null
    for directory, i in @rootDirectories
      if directory.getPath() is projectPath
        indexToRemove = i
        break

    if indexToRemove?
      [removedDirectory] = @rootDirectories.splice(indexToRemove, 1)
      [removedRepository] = @repositories.splice(indexToRemove, 1)
      removedDirectory.off() if includeDeprecatedAPIs
      removedRepository?.destroy() unless removedRepository in @repositories
      @emit "path-changed" if includeDeprecatedAPIs
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
        path.normalize(fs.absolute(uri))

      # TODO: what should we do here when there are multiple directories?
      else if projectPath = @getPaths()[0]
        path.normalize(fs.absolute(path.join(projectPath, uri)))
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
    for rootDirectory in @rootDirectories
      relativePath = rootDirectory.relativize(fullPath)
      return [rootDirectory.getPath(), relativePath] unless relativePath is fullPath
    [null, fullPath]

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

  # Given a path to a file, this constructs and associates a new
  # {TextEditor}, showing the file.
  #
  # * `filePath` The {String} path of the file to associate with.
  # * `options` Options that you can pass to the {TextEditor} constructor.
  #
  # Returns a promise that resolves to an {TextEditor}.
  open: (filePath, options={}) ->
    filePath = @resolvePath(filePath)

    if filePath?
      try
        fs.closeSync(fs.openSync(filePath, 'r'))
      catch error
        # allow ENOENT errors to create an editor for paths that dont exist
        throw error unless error.code is 'ENOENT'

    absoluteFilePath = @resolvePath(filePath)

    fileSize = fs.getSizeSync(absoluteFilePath)

    if fileSize >= 20 * 1048576 # 20MB
      choice = atom.confirm
        message: 'Atom will be unresponsive during the loading of very large files.'
        detailedMessage: "Do you still want to load this file?"
        buttons: ["Proceed", "Cancel"]
      if choice is 1
        error = new Error
        error.code = 'CANCELLED'
        throw error

    @bufferForPath(absoluteFilePath).then (buffer) =>
      @buildEditorForBuffer(buffer, _.extend({fileSize}, options))

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

  # Only to be used in specs
  bufferForPathSync: (filePath) ->
    absoluteFilePath = @resolvePath(filePath)
    existingBuffer = @findBufferForPath(absoluteFilePath) if filePath
    existingBuffer ? @buildBufferSync(absoluteFilePath)

  # Given a file path, this retrieves or creates a new {TextBuffer}.
  #
  # If the `filePath` already has a `buffer`, that value is used instead. Otherwise,
  # `text` is used as the contents of the new buffer.
  #
  # * `filePath` A {String} representing a path. If `null`, an "Untitled" buffer is created.
  #
  # Returns a promise that resolves to the {TextBuffer}.
  bufferForPath: (absoluteFilePath) ->
    existingBuffer = @findBufferForPath(absoluteFilePath) if absoluteFilePath
    Q(existingBuffer ? @buildBuffer(absoluteFilePath))

  bufferForId: (id) ->
    _.find @buffers, (buffer) -> buffer.id is id

  # Still needed when deserializing a tokenized buffer
  buildBufferSync: (absoluteFilePath) ->
    buffer = new TextBuffer({filePath: absoluteFilePath})
    @addBuffer(buffer)
    buffer.loadSync()
    buffer

  # Given a file path, this sets its {TextBuffer}.
  #
  # * `absoluteFilePath` A {String} representing a path.
  # * `text` The {String} text to use as a buffer.
  #
  # Returns a promise that resolves to the {TextBuffer}.
  buildBuffer: (absoluteFilePath) ->
    buffer = new TextBuffer({filePath: absoluteFilePath})
    @addBuffer(buffer)
    buffer.load()
      .then((buffer) -> buffer)
      .catch(=> @removeBuffer(buffer))

  addBuffer: (buffer, options={}) ->
    @addBufferAtIndex(buffer, @buffers.length, options)
    @subscribeToBuffer(buffer)

  addBufferAtIndex: (buffer, index, options={}) ->
    @buffers.splice(index, 0, buffer)
    @subscribeToBuffer(buffer)
    @emit 'buffer-created', buffer if includeDeprecatedAPIs
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

  buildEditorForBuffer: (buffer, editorOptions) ->
    largeFileMode = editorOptions.fileSize >= 2 * 1048576 # 2MB
    editor = new TextEditor(_.extend({buffer, largeFileMode, registerEditor: true}, editorOptions))
    editor

  eachBuffer: (args...) ->
    subscriber = args.shift() if args.length > 1
    callback = args.shift()

    callback(buffer) for buffer in @getBuffers()
    if subscriber
      subscriber.subscribe this, 'buffer-created', (buffer) -> callback(buffer)
    else
      @on 'buffer-created', (buffer) -> callback(buffer)

  subscribeToBuffer: (buffer) ->
    buffer.onDidDestroy => @removeBuffer(buffer)
    buffer.onWillThrowWatchError ({error, handle}) ->
      handle()
      atom.notifications.addWarning """
        Unable to read file after file `#{error.eventType}` event.
        Make sure you have permission to access `#{buffer.getPath()}`.
        """,
        detail: error.message
        dismissable: true

if includeDeprecatedAPIs
  Project.pathForRepositoryUrl = (repoUrl) ->
    deprecate '::pathForRepositoryUrl will be removed. Please remove from your code.'
    [repoName] = url.parse(repoUrl).path.split('/')[-1..]
    repoName = repoName.replace(/\.git$/, '')
    path.join(atom.config.get('core.projectHome'), repoName)

  Project::registerOpener = (opener) ->
    deprecate("Use Workspace::addOpener instead")
    atom.workspace.addOpener(opener)

  Project::unregisterOpener = (opener) ->
    deprecate("Call .dispose() on the Disposable returned from ::addOpener instead")
    atom.workspace.unregisterOpener(opener)

  Project::eachEditor = (callback) ->
    deprecate("Use Workspace::observeTextEditors instead")
    atom.workspace.observeTextEditors(callback)

  Project::getEditors = ->
    deprecate("Use Workspace::getTextEditors instead")
    atom.workspace.getTextEditors()

  Project::on = (eventName) ->
    if eventName is 'path-changed'
      Grim.deprecate("Use Project::onDidChangePaths instead")
    else
      Grim.deprecate("Project::on is deprecated. Use documented event subscription methods instead.")
    super

  Project::getRepo = ->
    Grim.deprecate("Use ::getRepositories instead")
    @getRepositories()[0]

  Project::getPath = ->
    Grim.deprecate("Use ::getPaths instead")
    @getPaths()[0]

  Project::setPath = (path) ->
    Grim.deprecate("Use ::setPaths instead")
    @setPaths([path])

  Project::getRootDirectory = ->
    Grim.deprecate("Use ::getDirectories instead")
    @getDirectories()[0]

  Project::resolve = (uri) ->
    Grim.deprecate("Use `Project::getDirectories()[0]?.resolve()` instead")
    @resolvePath(uri)

  Project::scan = (regex, options={}, iterator) ->
    Grim.deprecate("Use atom.workspace.scan instead of atom.project.scan")
    atom.workspace.scan(regex, options, iterator)

  Project::replace = (regex, replacementText, filePaths, iterator) ->
    Grim.deprecate("Use atom.workspace.replace instead of atom.project.replace")
    atom.workspace.replace(regex, replacementText, filePaths, iterator)

  Project::openSync = (filePath, options={}) ->
    deprecate("Use Project::open instead")
    filePath = @resolvePath(filePath)
    @buildEditorForBuffer(@bufferForPathSync(filePath), options)
