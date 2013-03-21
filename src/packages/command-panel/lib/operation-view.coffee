{View} = require 'space-pen'

module.exports =
class OperationView extends View
  @content: ({operation} = {}) ->
    {prefix, suffix, match, range} = operation.preview()
    @li class: 'operation', =>
      @span range.start.row + 1, class: 'line-number'
      @span class: 'preview', =>
        @span prefix
        @span match, class: 'match'
        @span suffix

  initialize: ({@previewList, @operation}) ->
    @subscribe @previewList, 'core:confirm', =>
      if @hasClass('selected')
        @executeOperation()
        false
    @on 'mousedown', (e) =>
      @executeOperation()
      @previewList.find('.selected').removeClass('selected')
      @addClass('selected')

  executeOperation: ->
    editSession = rootView.open(@operation.getPath())
    bufferRange = @operation.execute(editSession)
    editSession.setSelectedBufferRange(bufferRange, autoscroll: true) if bufferRange
    @previewList.focus()

  scrollTo: ->
    top = @previewList.scrollTop() + @offset().top - @previewList.offset().top
    bottom = top + @outerHeight()
    @previewList.scrollTo(top, bottom)
