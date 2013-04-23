fsUtils = require 'fs-utils'
_ = require 'underscore'

# Public: Manages the states between {Editor}s, images, and the project as a whole.
#
# Essentially, the graphical version of a {EditSession}.
module.exports=
class ImageEditSession
  registerDeserializer(this)

  # Public: Identifies if a path can be opened by the image viewer.
  #
  # path - The {String} name of the path to check
  #
  # Returns a {Boolean}.
  @canOpen: (path) ->
    _.indexOf([
      '.gif'
      '.jpeg'
      '.jpg'
      '.png'
    ], fsUtils.extension(path), true) >= 0

  ### Internal ###
  
  @deserialize: (state) ->
    if fsUtils.exists(state.path)
      project.buildEditSession(state.path)
    else
      console.warn "Could not build edit session for path '#{state.path}' because that file no longer exists"

  constructor: (@path) ->

  serialize: ->
    deserializer: 'ImageEditSession'
    path: @path

  getViewClass: ->
    require 'image-view'

  # Public: Retrieves the filename of the open file.
  #
  # This is `'untitled'` if the file is new and not saved to the disk.
  # 
  # Returns a {String}.
  getTitle: ->
    if path = @getPath()
      fsUtils.base(path)
    else
      'untitled'

  # Public: Retrieves the URI of the current image.
  #
  # Returns a {String}.
  getUri: -> @path

  # Public: Retrieves the path of the current image.
  #
  # Returns a {String}.
  getPath: -> @path

  # Public: Compares two `ImageEditSession`s to determine equality.
  #
  # Equality is based on the condition that the two URIs are the same.
  #
  # Returns a {Boolean}.
  isEqual: (other) ->
    other instanceof ImageEditSession and @getUri() is other.getUri()
