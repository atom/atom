ScrollView = require 'scroll-view'

module.exports =
class ImageView extends ScrollView
  @content: ->
    @div class: 'image-view', tabindex: -1, =>
      @img outlet: 'image'

  initialize: (imageEditSession) ->
    requireStylesheet 'image-view'

    @image.load =>
      @originalHeight = @image.height()
      @originalWidth = @image.width()
      @loaded = true
      @centerImage()
    @setPath(imageEditSession?.getPath())

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

  centerImage: ->
    return unless @loaded and @isVisible()

    @image.css
      'top': Math.max((@height() - @image.outerHeight()) / 2, 0)
      'left': Math.max((@width() - @image.outerWidth()) / 2, 0)
    @image.show()

  setPath: (path) ->
    if path?
      if @image.attr('src') isnt path
        @loaded = false
        @image.hide().attr('src', path)
    else
      @image.hide()

  setModel: (imageEditSession) ->
    @setPath(imageEditSession?.getPath())

  getPane: ->
    @parent('.item-views').parent('.pane').view()

  adjustSize: (factor) ->
    return unless @loaded and @isVisible()

    newWidth = @image.width() * factor
    newHeight = @image.height() * factor
    @image.width(newWidth)
    @image.height(newHeight)
    @centerImage()

  zoomOut: ->
    @adjustSize(0.9)

  zoomIn: ->
    @adjustSize(1.1)

  resetZoom: ->
    return unless @loaded and @isVisible()

    @image.width(@originalWidth)
    @image.height(@originalHeight)
    @centerImage()
