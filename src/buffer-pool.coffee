Model = require './model'   # When to extend Model?
_ = require 'underscore-plus'
fs = require 'fs-plus'

TextBuffer = require 'text-buffer'
{Emitter} = require 'event-kit'

module.exports =
class BufferPool extends Model

  constructor: (@notificationManager) ->
    @buffers = []
    @emitter = new Emitter

  destroy: ->
    buffer.destroy() for buffer in @buffers

  reset: ->
    @destroy()
    @buffers = []

  destroyUnretainedBuffers: ->
    buffer.destroy() for buffer in @getBuffers() when not buffer.isRetained()
    return

  deserialize: (state, deserializerManager) ->

    @buffers = _.compact state.buffers.map (bufferState) ->
      # Check that buffer's file path is accessible
      return if fs.isDirectorySync(bufferState.filePath)
      if bufferState.filePath
        try
          fs.closeSync(fs.openSync(bufferState.filePath, 'r'))
        catch error
          return unless error.code is 'ENOENT'
      deserializerManager.deserialize(bufferState)

    @subscribeToBuffer(buffer) for buffer in @buffers

  serialize: ->
    _.compact(@buffers.map (buffer) -> buffer.serialize() if buffer.isRetained())

  onDidAddBuffer: (callback) ->
    @emitter.on 'did-add-buffer', callback

  # Retrieves all the {TextBuffer}s in the Buffer Pool; that is, the
  # buffers for all open files.
  #
  # Returns an {Array} of {TextBuffer}s.
  getBuffers: ->
    @buffers.slice()

  # Is the buffer for the given path modified?
  isPathModified: (resolvedPath) ->
    @findBufferForPath(resolvedPath)?.isModified()

  findBufferForPath: (filePath) ->
    _.find @buffers, (buffer) -> buffer.getPath() is filePath

  findBufferForId: (id) ->
    _.find @buffers, (buffer) -> buffer.getId() is id

  # Only to be used in specs
  bufferForPathSync: (absoluteFilePath) ->
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
  # Returns a {Promise} that resolves to the {TextBuffer}.
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
    buffer.onDidDestroy => @removeBuffer(buffer)
    buffer.onWillThrowWatchError ({error, handle}) =>
      handle()
      @notificationManager.addWarning """
        Unable to read file after file `#{error.eventType}` event.
        Make sure you have permission to access `#{buffer.getPath()}`.
        """,
        detail: error.message
        dismissable: true
