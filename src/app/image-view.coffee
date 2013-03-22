ScrollView = require 'scroll-view'

module.exports =
class ImageView extends ScrollView
  @content: ->
    @div class: 'image-view', tabindex: -1, =>
      @img outlet: 'image'

  initialize: (imageEditSession) ->
    requireStylesheet 'image-view'

    @image.load => @updateSize()
    @setPath(imageEditSession?.getPath())

  afterAttach: (onDom) ->
    return unless onDom

    if pane = @getPane()
      @active = @is(pane.activeView)
      @subscribe pane, 'pane:active-item-changed', (event, item) =>
        wasActive = @active
        @active = @is(pane.activeView)
        @updateSize() if @active and not wasActive

  updateSize: ->
    return unless @isVisible()

    @image.css
      'margin-left': -@image.width() / 2
      'margin-top': -@image.height() / 2
    @image.show()

  setPath: (path) ->
    if path?
      @image.hide().attr('src', path) if @image.attr('src') isnt path
    else
      @image.hide()

  setModel: (imageEditSession) ->
    @setPath(imageEditSession?.getPath())

  getPane: ->
    @parent('.item-views').parent('.pane').view()
