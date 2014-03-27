{View} = require 'space-pen'
{$$} = require 'space-pencil'
React = require 'react'
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
    @subscribe @editor, 'screen-lines-changed', (change) => @contents.onScreenLinesChanged(change)

  afterAttach: (onDom) ->
    return unless onDom

    @editor.setVisible(true)

    @measureLineHeight()
    @contents.setProps
      height: @scrollView.clientHeight
      scrollTop: @scrollView.scrollTop
      lineHeight: @lineHeight

  setScrollTop: (scrollTop) ->
    @contents.setProps({scrollTop})

  measureLineHeight: ->
    fragment = $$ ->
      @div class: 'lines', ->
        @div class: 'line', style: 'position: absolute; visibility: hidden;', -> @span 'x'

    @scrollView.appendChild(fragment)
    lineRect = fragment.firstChild.getBoundingClientRect()
    charRect = fragment.firstChild.firstChild.getBoundingClientRect()
    @lineHeight = lineRect.height
    @charWidth = charRect.width
    @charHeight = charRect.height
    @scrollView.removeChild(fragment)
