React = require 'react-atom-fork'
{div} = require 'reactionary-atom-fork'
{extend, isEqualForProperties} = require 'underscore-plus'

module.exports =
ScrollbarComponent = React.createClass
  displayName: 'ScrollbarComponent'

  render: ->
    {orientation, className} = @props

    style = {}

    style.transform = 'translateZ(0)' # See atom/atom#3559
    style.left = 0 if orientation is 'horizontal'

    div {className, style},
      switch orientation
        when 'vertical'
          div ref: 'content', className: 'scrollbar-content'
        when 'horizontal'
          div ref: 'content', className: 'scrollbar-content'

  componentDidMount: ->
    {orientation} = @props

    unless orientation is 'vertical' or orientation is 'horizontal'
      throw new Error("Must specify an orientation property of 'vertical' or 'horizontal'")

    @getDOMNode().addEventListener 'scroll', @onScroll

    @updateSync()

  componentWillUnmount: ->
    @getDOMNode().removeEventListener 'scroll', @onScroll

  componentDidUpdate: ->
    @updateSync()

  updateSync: ->
    {presenter, orientation} = @props
    node = @getDOMNode()

    @oldState ?= {}
    switch orientation
      when 'vertical'
        @newState = presenter.state.verticalScrollbar
        @updateVertical()
      when 'horizontal'
        @newState = presenter.state.horizontalScrollbar
        @updateHorizontal()

    if @newState.visible isnt @oldState.visible
      if @newState.visible
        node.style.display = ''
      else
        node.style.display = 'none'
      @oldState.visible = @newState.visible

  updateVertical: ->
    node = @getDOMNode()

    if @newState.width isnt @oldState.width
      node.style.width = @newState.width + 'px'
      @oldState.width = @newState.width

    if @newState.bottom isnt @oldState.bottom
      node.style.bottom = @newState.bottom + 'px'
      @oldState.bottom = @newState.bottom

    if @newState.scrollTop isnt @oldState.scrollTop
      node.scrollTop = @newState.scrollTop
      @oldState = @newState.scrollTop

    if @newState.scrollHeight isnt @oldState.scrollHeight
      @refs.content.getDOMNode().style.height = @newState.scrollHeight + 'px'
      @oldState = @newState.scrollHeight

  updateHorizontal: ->
    node = @getDOMNode()

    if @newState.height isnt @oldState.height
      node.style.height = @newState.height + 'px'
      @oldState.height = @newState.height

    if @newState.right isnt @oldState.right
      node.style.right = @newState.right + 'px'
      @oldState.right = @newState.right

    if @newState.scrollLeft isnt @oldState.scrollLeft
      node.scrollLeft = @newState.scrollLeft
      @oldState = @newState.scrollLeft

    if @newState.scrollWidth isnt @oldState.scrollWidth
      @refs.content.getDOMNode().style.width = @newState.scrollWidth + 'px'
      @oldState = @newState.scrollWidth

  onScroll: ->
    {orientation, onScroll} = @props
    node = @getDOMNode()

    switch orientation
      when 'vertical'
        scrollTop = node.scrollTop
        onScroll(scrollTop)
      when 'horizontal'
        scrollLeft = node.scrollLeft
        onScroll(scrollLeft)
