ScrollView = require 'scroll-view'
_ = require 'underscore'
$ = require 'jquery'

# Public: Renders images in the {Editor}.
module.exports =
class ImageView extends ScrollView

  ### Internal ###

  @content: ->
    @div class: 'image-view', tabindex: -1, =>
      @img outlet: 'image'

  initialize: (imageEditSession) ->
    super

    requireStylesheet 'image-view'

    @image.load =>
      @originalHeight = @image.height()
      @originalWidth = @image.width()
      @loaded = true
      @centerImage()
    @setPath(imageEditSession?.getPath())

    @subscribe $(window), 'resize', _.debounce((=> @centerImage()), 300)
    @command 'image-view:zoom-in', => @zoomIn()
    @command 'image-view:zoom-out', => @zoomOut()
    @command 'image-view:reset-zoom', => @resetZoom()

  afterAttach: (onDom) ->
    return unless onDom

    if pane = @getPane()
      @active = @is(pane.activeView)
      @subscribe pane, 'pane:active-item-changed', (event, item) =>
        wasActive = @active
        @active = @is(pane.activeView)
        @centerImage() if @active and not wasActive

  ### Public ###

  # Places the image in the center of the {Editor}.
  centerImage: ->
    return unless @loaded and @isVisible()

    @image.css
      'top': Math.max((@height() - @image.outerHeight()) / 2, 0)
      'left': Math.max((@width() - @image.outerWidth()) / 2, 0)
    @image.show()

  # Indicates the path of the image.
  #
  # path - A {String} for the new image path.
  setPath: (path) ->
    if path?
      if @image.attr('src') isnt path
        @loaded = false
        @image.hide().attr('src', path)
    else
      @image.hide()

  # Retrieve's the {Editor}'s pane.
  #
  # Returns a {Pane}.
  getPane: ->
    @parent('.item-views').parent('.pane').view()

  # Zooms the image out.
  #
  # This is done by a factor of `0.9`.
  zoomOut: ->
    @adjustSize(0.9)

  # Zooms the image in.
  #
  # This is done by a factor of `1.1`.
  zoomIn: ->
    @adjustSize(1.1)

  # Zooms the image to its normal width and height.
  resetZoom: ->
    return unless @loaded and @isVisible()

    @image.width(@originalWidth)
    @image.height(@originalHeight)
    @centerImage()

  ### Internal ###

  adjustSize: (factor) ->
    return unless @loaded and @isVisible()

    newWidth = @image.width() * factor
    newHeight = @image.height() * factor
    @image.width(newWidth)
    @image.height(newHeight)
    @centerImage()

  setModel: (imageEditSession) ->
    @setPath(imageEditSession?.getPath())
