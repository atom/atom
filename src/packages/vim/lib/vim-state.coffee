_ = require 'underscore'

class VimMotion
  constructor: (@name, @event, @count, @target) ->
    @select = false
  perform: (@operation) ->
    window.console.log "Performing motion #{@name} (#{@count}) with event #{@event}"
    if typeof @event == "function" then @event.apply(this)
    else @performEvent(@event) for n in [1..@count]
  performSelect: (@operation) ->
    @select = true
    @perform(@operation)
    @select = false
  selectEvent: (event) ->
    event.replace(/move/, 'select')
  performEvent: (event) ->
    event = @selectEvent(event) if @select
    @target.trigger(event)

class VimOperation
  constructor: (@name, @callback, @vim) ->
    @motion = null
    @performed = false
  perform: (@target, @motion) ->
    window.console.log "Beginning operation #{@name}"
    @performed = true
    @callback.apply(this, [@vim.state])
    window.console.log "Finished operation #{@name}"
  performEvent: (event) ->
    @target.trigger(event)
  performMotion: ->
    @motion.perform(this) if @motion?
  performSelectMotion: ->
    @motion.performSelect(this) if @motion?
  textInput: (text) ->
    @vim.editor.insertText(text)
  yank: () ->
    @vim.state.yankSelection()
  paste: (options={}) ->
    @vim.state.paste(options)

module.exports =
class VimState
  constructor: (@target, @vim) ->
    @resetState()
    @pasteBuffer = {}
    @lastOperation = null
    for m,event of @motionEvents
      do (m, event) =>
        @target.command "vim:motion-#{m}", => @motion(m)
    for o,callback of @operations
      do (o) =>
        @target.command "vim:operation-#{o}", => @operation(o)
    for a,options of @aliases
      do (a) =>
        @target.command "vim:alias-#{a}", => @alias(a)
  motion: (type) ->
    event = @motionEvents[type]
    m = new VimMotion(type, event, @_count, @target)
    if _.contains(@motionsWithInput, type)
      @_operation.motion = m
      @vim.enterAwaitInputMode()
    else
      @_operation.perform(@target, m)
      @resetState()
  defaultMotion: () ->
    new VimMotion('line', @motionEvents['line'], @_count, @target)
  addCountDecimal: (n) ->
    @_count = 0 if @state != "count"
    @enterState "count"
    @_count = @_count * 10 + n if n?
    @stateUpdated()
    @_count
  count: (n) ->
    @_count = n if n?
    @_count
  visual: () ->
    @vim.visual
  defaultOperation: () ->
    if @visual() then 'select' else 'move'
  buildOperation: (type) ->
    type = @defaultOperation() if !@operations[type]?
    new VimOperation(type, @operations[type], @vim)
  operation: (type) ->
    if _.contains(@operationsWithInput, type)
      @_operation = @buildOperation(type)
      @vim.enterAwaitInputMode()
    else if @visual()
      @_operation = @buildOperation(type)
      @_operation.perform(@target)
      # @vim.enterCommandMode()
      @resetState()
    else if _.contains(@noMotionOperations, type)
      @_operation = @buildOperation(type)
      @_operation.perform(@target)
      @resetState()
    else if @_operation.name == type
      @_operation.perform(@target, @defaultMotion())
      @resetState()
    else
      @_operation = @buildOperation(type)
  resetState: ->
    @enterState "idle"
    @_count = 1
    if @_operation?.performed
      @lastOperation = @_operation
    @_operation = @buildOperation(@defaultOperation())
  enterState: (state) ->
    @state = state
    @vim.stateChanged(@state) if @vim? and @vim.stateChanged?
  stateUpdated: ->
    @vim.stateUpdated(@state) if @vim? and @vim.stateUpdated?
  alias: (name) ->
    a = @aliases[name]
    @motion(a.beforeMotion) if a.beforeMotion?
    @operation(a.operation)
    @motion(a.motion)
    @motion(a.afterMotion) if a.afterMotion?
  input: (text) ->
    @_operation.input = text
    if @_operation.motion?
      @_operation.perform(@target, @_operation.motion)
    else
      @motion("right")
      @vim.enterCommandMode()
  editSession: () ->
    @vim.editor.activeEditSession
  currentCursorPosition: () ->
    @editSession().getCursorBufferPosition()
  setCursorPosition: (pos) ->
    @editSession().setCursorBufferPosition(pos)
  insertText: (text) ->
    @editSession().insertText(text)
  clearSelection: () ->
    @editSession().clearSelections()
  selectedText: () ->
    text = ""
    for selection in @editSession().getSelections()
      l = @editSession().buffer.getTextInRange(selection.getBufferRange())
      if selection.linewise
        text = text + l + '\n'
      else
        text = text + l
    text
  yankSelection: () ->
    text = @selectedText()
    @pasteBuffer[0] = text
  paste: (options={}) ->
    @insertText(@pasteBuffer[0]) if @pasteBuffer[0] && @pasteBuffer[0] != ''
  aliases:
    'delete-character':
      motion: 'right'
      operation: 'delete'
    'delete-until-end-of-line':
      motion: 'end-of-line'
      operation: 'delete'
    'insert-line-up':
      motion: 'beginning-of-line'
      operation: 'insert-line'
      afterMotion: 'up'
    'insert-line-down':
      motion: 'end-of-line'
      operation: 'insert-line'
    'join-lines':
      beforeMotion: 'end-of-line'
      motion: 'right'
      operation: 'delete'
  motionEvents:
    left: "core:move-left"
    right: "core:move-right"
    up: "core:move-up"
    down: "core:move-down"
    line: "editor:move-line"
    'beginning-of-line': "editor:move-to-beginning-of-line"
    'end-of-line': "editor:move-to-end-of-line"
    'next-word': "editor:move-to-beginning-of-next-word"
    'previous-word': "editor:move-to-beginning-of-word"
    'go-to-line': () ->
      (if n == 1 then @performEvent("core:move-to-top") else @performEvent("core:move-down")) for n in [1..@count]
    'go-to-line-bottom': () ->
      if @count == 1 then @performEvent("core:move-to-bottom")
      else (if n == 1 then @performEvent("core:move-to-top") else @performEvent("core:move-down")) for n in [1..@count]
    'find-character': () ->
      edit = @target.activeEditSession
      for n in [1..@count]
        found = false
        oldPos = edit.getCursorBufferPosition()
        if @select
          edit.selectRight()
        else
          edit.moveCursorRight()
        while !found
          edit.selectRight()
          char = _.last(edit.getSelectedText())
          edit.clearSelections() if !@select
          if !char || char == '' || edit.getCursorBufferPosition().row > edit.getEofBufferPosition().row
            edit.setCursorBufferPosition(oldPos) if !@select
            return
          found = char == @operation.input
        if !@select
          edit.moveCursorLeft()
  operations:
    'move': ->
      @performMotion()
    'select': ->
      @performSelectMotion()
    'change': ->
      @performSelectMotion()
      @yank()
      @performEvent("core:delete")
      @vim.enterInsertMode()
    'delete': ->
      @performSelectMotion()
      @yank()
      @performEvent("core:delete")
    'change-character': ->
      @performSelectMotion()
      @yank()
      @performEvent("core:delete")
      @textInput(@input)
    'insert-line': ->
      @performMotion()
      @performEvent("editor:newline")
    'repeat': (state) ->
      return if !state.lastOperation?
      state._operation = state.lastOperation
      state._operation.perform(@target, state._operation.motion)
    'yank': (state) ->
      pos = state.currentCursorPosition()
      @performSelectMotion()
      @yank()
      state.setCursorPosition(pos)
    'paste': () ->
      @performEvent("core:move-right")
      @paste select:false
      @performEvent("core:move-left")
    'paste-before': (state) ->
      pos = state.currentCursorPosition()
      @paste select:true
      state.setCursorPosition(pos)
  operationsWithInput: ['change-character']
  motionsWithInput: ['find-character']
  noMotionOperations: ['repeat', 'paste', 'paste-before']
