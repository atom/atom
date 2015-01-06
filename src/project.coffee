path = require 'path'
url = require 'url'

_ = require 'underscore-plus'
fs = require 'fs-plus'
Q = require 'q'
{deprecate} = require 'grim'
{Model} = require 'theorist'
{Subscriber} = require 'emissary'
{Emitter} = require 'event-kit'
Serializable = require 'serializable'
TextBuffer = require 'text-buffer'
{Directory} = require 'pathwatcher'
Grim = require 'grim'

TextEditor = require './text-editor'
Task = require './task'
GitRepository = require './git-repository'

# Extended: Represents a project that's opened in Atom.
#
# An instance of this class is always available as the `atom.project` global.
module.exports =
class Project extends Model
  atom.deserializers.add(this)
  Serializable.includeInto(this)

  @pathForRepositoryUrl: (repoUrl) ->
    deprecate '::pathForRepositoryUrl will be removed. Please remove from your code.'
    [repoName] = url.parse(repoUrl).path.split('/')[-1..]
    repoName = repoName.replace(/\.git$/, '')
    path.join(atom.config.get('core.projectHome'), repoName)

  ###
  Section: Construction and Destruction
  ###

  constructor: ({path, paths, @buffers}={}) ->
    @emitter = new Emitter
    @buffers ?= []

    for buffer in @buffers
      do (buffer) =>
        buffer.onDidDestroy => @removeBuffer(buffer)

    Grim.deprecate("Pass 'paths' array instead of 'path' to project constructor") if path?
    paths ?= _.compact([path])
    @setPaths(paths)

  destroyed: ->
    buffer.destroy() for buffer in @getBuffers()
    @destroyRepo()

  destroyRepo: ->
    if @repo?
      @repo.destroy()
      @repo = null

  destroyUnretainedBuffers: ->
    buffer.destroy() for buffer in @getBuffers() when not buffer.isRetained()

  ###
  Section: Serialization
  ###

  serializeParams: ->
    paths: @getPaths()
    buffers: _.compact(@buffers.map (buffer) -> buffer.serialize() if buffer.isRetained())

  deserializeParams: (params) ->
    params.buffers = params.buffers.map (bufferState) -> atom.deserializers.deserialize(bufferState)
    params


  ###
  Section: Event Subscription
  ###

  onDidChangePaths: (callback) ->
    @emitter.on 'did-change-paths', callback

  on: (eventName) ->
    if eventName is 'path-changed'
      Grim.deprecate("Use Project::onDidChangePaths instead")
    super

  ###
  Section: Accessing the git repository
  ###

  # Public: Get an {Array} of {GitRepository}s associated with the project's
  # directories.
  getRepositories: -> _.compact([@repo])
  getRepo: ->
    Grim.deprecate("Use ::getRepositories instead")
    @repo

  ###
  Section: Managing Paths
  ###


  # Public: Get an {Array} of {String}s containing the paths of the project's
  # directories.
  getPaths: -> _.compact([@rootDirectory?.path])
  getPath: ->
    Grim.deprecate("Use ::getPaths instead")
    @rootDirectory?.path

  # Public: Set the paths of the project's directories.
  #
  # * `projectPaths` {Array} of {String} paths.
  setPaths: (projectPaths) ->
    [projectPath] = projectPaths
    projectPath = path.normalize(projectPath) if projectPath
    @path = projectPath
    @rootDirectory?.off()

    @destroyRepo()
    if projectPath?
      directory = if fs.isDirectorySync(projectPath) then projectPath else path.dirname(projectPath)
      @rootDirectory = new Directory(directory)
      if @repo = GitRepository.open(directory, project: this)
        @repo.refreshIndex()
        @repo.refreshStatus()
    else
      @rootDirectory = null

    @emit "path-changed"
    @emitter.emit 'did-change-paths', projectPaths
  setPath: (path) ->
    Grim.deprecate("Use ::setPaths instead")
    @setPaths([path])

  # Public: Get an {Array} of {Directory}s associated with this project.
  getDirectories: ->
    [@rootDirectory]
  getRootDirectory: ->
    Grim.deprecate("Use ::getDirectories instead")
    @rootDirectory

  # Public: Given a uri, this resolves it relative to the project directory. If
  # the path is already absolute or if it is prefixed with a scheme, it is
  # returned unchanged.
  #
  # * `uri` The {String} name of the path to convert.
  #
  # Returns a {String} or undefined if the uri is not missing or empty.
  resolve: (uri) ->
    return unless uri

    if uri?.match(/[A-Za-z0-9+-.]+:\/\//) # leave path alone if it has a scheme
      uri
    else
      if fs.isAbsolute(uri)
        path.normalize(fs.absolute(uri))
      else if projectPath = @getPaths()[0]
        path.normalize(fs.absolute(path.join(projectPath, uri)))
      else
        undefined

  # Public: Make the given path relative to the project directory.
  #
  # * `fullPath` {String} full path
  relativize: (fullPath) ->
    return fullPath if fullPath?.match(/[A-Za-z0-9+-.]+:\/\//) # leave path alone if it has a scheme
    @rootDirectory?.relativize(fullPath) ? fullPath

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
    @rootDirectory?.contains(pathToCheck) ? false

  ###
  Section: Searching and Replacing
  ###

  scan: (regex, options={}, iterator) ->
    Grim.deprecate("Use atom.workspace.scan instead of atom.project.scan")
    atom.workspace.scan(regex, options, iterator)

  replace: (regex, replacementText, filePaths, iterator) ->
    Grim.deprecate("Use atom.workspace.replace instead of atom.project.replace")
    atom.workspace.replace(regex, replacementText, filePaths, iterator)

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
    filePath = @resolve(filePath)
    @bufferForPath(filePath).then (buffer) =>
      @buildEditorForBuffer(buffer, options)

  # Deprecated
  openSync: (filePath, options={}) ->
    deprecate("Use Project::open instead")
    filePath = @resolve(filePath)
    @buildEditorForBuffer(@bufferForPathSync(filePath), options)

  # Retrieves all the {TextBuffer}s in the project; that is, the
  # buffers for all open files.
  #
  # Returns an {Array} of {TextBuffer}s.
  getBuffers: ->
    @buffers.slice()

  # Is the buffer for the given path modified?
  isPathModified: (filePath) ->
    @findBufferForPath(@resolve(filePath))?.isModified()

  findBufferForPath: (filePath) ->
    _.find @buffers, (buffer) -> buffer.getPath() == filePath

  # Only to be used in specs
  bufferForPathSync: (filePath) ->
    absoluteFilePath = @resolve(filePath)
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
  bufferForPath: (filePath) ->
    absoluteFilePath = @resolve(filePath)
    existingBuffer = @findBufferForPath(absoluteFilePath) if absoluteFilePath
    Q(existingBuffer ? @buildBuffer(absoluteFilePath))

  bufferForId: (id) ->
    _.find @buffers, (buffer) -> buffer.id is id

  # Still needed when deserializing a tokenized buffer
  buildBufferSync: (absoluteFilePath) ->
    buffer = new TextBuffer({filePath: absoluteFilePath})
    buffer.setEncoding(atom.config.get('core.fileEncoding'))
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
    if fs.getSizeSync(absoluteFilePath) >= 2 * 1048576 # 2MB
      throw new Error("Atom can only handle files < 2MB for now.")

    buffer = new TextBuffer({filePath: absoluteFilePath})
    buffer.setEncoding(atom.config.get('core.fileEncoding'))
    @addBuffer(buffer)
    buffer.load()
      .then((buffer) -> buffer)
      .catch(=> @removeBuffer(buffer))

  addBuffer: (buffer, options={}) ->
    @addBufferAtIndex(buffer, @buffers.length, options)
    buffer.onDidDestroy => @removeBuffer(buffer)

  addBufferAtIndex: (buffer, index, options={}) ->
    @buffers.splice(index, 0, buffer)
    buffer.onDidDestroy => @removeBuffer(buffer)
    @emit 'buffer-created', buffer
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
    editor = new TextEditor(_.extend({buffer, registerEditor: true}, editorOptions))
    editor

  eachBuffer: (args...) ->
    subscriber = args.shift() if args.length > 1
    callback = args.shift()

    callback(buffer) for buffer in @getBuffers()
    if subscriber
      subscriber.subscribe this, 'buffer-created', (buffer) -> callback(buffer)
    else
      @on 'buffer-created', (buffer) -> callback(buffer)

  # Deprecated: delegate
  registerOpener: (opener) ->
    deprecate("Use Workspace::addOpener instead")
    atom.workspace.registerOpener(opener)

  # Deprecated: delegate
  unregisterOpener: (opener) ->
    deprecate("Call .dispose() on the Disposable returned from ::addOpener instead")
    atom.workspace.unregisterOpener(opener)

  # Deprecated: delegate
  eachEditor: (callback) ->
    deprecate("Use Workspace::eachEditor instead")
    atom.workspace.eachEditor(callback)

  # Deprecated: delegate
  getEditors: ->
    deprecate("Use Workspace::getEditors instead")
    atom.workspace.getEditors()
