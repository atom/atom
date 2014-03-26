{View} = require 'space-pen'
{$$} = require 'space-pencil'
{React} = require 'reactionary'
EditorContentsComponent = require './editor-contents-component'

module.exports =
class ReactEditorView extends View
  @content: ->
    @div class: 'editor', =>
      @div class: 'scroll-view', outlet: 'scrollView'

  constructor: (@editor) ->
    super
    @scrollView = @scrollView.element
    @contents = React.renderComponent(EditorContentsComponent({@editor}), @scrollView)

  afterAttach: (onDom) ->
    @measureLineHeight()

    @contents.setState
      height: @scrollView.clientHeight
      scrollTop: @scrollView.scrollTop
      lineHeight: @lineHeight

  measureLineHeight: ->
    fragment = $$ ->
      @div class: 'lines', ->
        @div class: 'line', style: 'position: absolute; visibility: hidden;', -> @span 'x'

    @scrollView.appendChild(fragment)
    lineRect = fragment.getBoundingClientRect()
    charRect = fragment.firstChild.getBoundingClientRect()
    @lineHeight = lineRect.height
    @charWidth = charRect.width
    @charHeight = charRect.height
    @scrollView.removeChild(fragment)
