fsUtils = require 'fs-utils'
_ = require 'underscore'

# Public: Manages the states between {Editor}s, images, and the project as a whole.
#
# Essentially, the graphical version of a {EditSession}.
module.exports=
class ImageEditSession
  registerDeserializer(this)

  @activate: ->
    # Files with these extensions will be opened as images
    imageExtensions = ['.gif', '.jpeg', '.jpg', '.png']
    Project = require 'project'
    Project.registerOpener (filePath) ->
      if _.include(imageExtensions, fsUtils.extension(filePath))
        new ImageEditSession(filePath)

  @deserialize: ({path}={}) ->
    if fsUtils.exists(path)
      new ImageEditSession(path)
    else
      console.warn "Could not build image edit session for path '#{path}' because that file no longer exists"

  constructor: (@path) ->

  serialize: ->
    deserializer: 'ImageEditSession'
    path: @path

  getViewClass: ->
    require './image-view'

  ### Public ###

  # Retrieves the filename of the open file.
  #
  # This is `'untitled'` if the file is new and not saved to the disk.
  #
  # Returns a {String}.
  getTitle: ->
    if path = @getPath()
      fsUtils.base(path)
    else
      'untitled'

  # Retrieves the URI of the current image.
  #
  # Returns a {String}.
  getUri: -> @path

  # Retrieves the path of the current image.
  #
  # Returns a {String}.
  getPath: -> @path

  # Compares two `ImageEditSession`s to determine equality.
  #
  # Equality is based on the condition that the two URIs are the same.
  #
  # Returns a {Boolean}.
  isEqual: (other) ->
    other instanceof ImageEditSession and @getUri() is other.getUri()
