_ = require 'underscore'

class VimMotion
  constructor: (@name, @event, @count, @target) ->
    @select = false
  perform: (@operation) ->
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
    @performed = true
    @callback.apply(this, [@vim.state])
  performEvent: (event) ->
    @target.trigger(event)
  performMotion: (name) ->
    if name?
      m = new VimMotion(name, @vim.state.motionEvents[name], 1, @target)
      m.perform(this)
      return
    @motion.perform(this) if @motion?
  performSelectMotion: ->
    @motion.performSelect(this) if @motion?
  textInput: (text) ->
    @vim.editor.insertText(text)
  yank: ->
    @vim.state.yankSelection()
  paste: (options={}) ->
    @vim.state.paste(options)
  startTransaction: ->
    @vim.state.startTransaction()

module.exports =
class VimState
  constructor: (@target, @vim) ->
    @resetState()
    @recording = false
    @recordings = {}
    @pasteBuffer = {}
    @lastOperation = null
    @lastMotion = null
    @lastSearchMotion = null
    @countEntered = false
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
      return
    else if _.contains(@motionsWithRequiredCount, type)
      if !@countEntered
        if @lastMotion? && @lastMotion.name == type
        else
          @lastMotion = m
          return
    @_operation.perform(@target, m)
    @lastMotion = m if !_.contains(@motionsWithRequiredCount, type)
    @lastSearchMotion = m if _.contains(@searchMotions, type)
    @resetState()
  defaultMotion: ->
    new VimMotion('line', @motionEvents['line'], @_count, @target)
  addCountDecimal: (n) ->
    @_count = 0 if @state != "count"
    @countEntered = true
    @enterState "count"
    @_count = @_count * 10 + n if n?
    @stateUpdated()
    @_count
  count: (n) ->
    @_count = n if n?
    @countEntered = true
    @_count
  visual: (type) ->
    if type?
      @vim.visual == type
    else
      @vim.visual
  defaultOperation: ->
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
    @countEntered = false
    if @_operation?.performed
      if !_.contains(@noRepeatOperations, @_operation.name)
        @lastOperation = @_operation
      if @visual() and !_.contains(@noModeResetOperations, @_operation.name)
        @vim.exitVisualMode()
      if @recording && !@_operation.name.match(/-recording/)
        @recordings[@recording].push(@_operation)
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
      if _.contains(@searchMotions, @_operation.motion.name)
        @lastSearchMotion = @_operation.motion
        @_operation.motion.input = text
      @_operation.perform(@target, @_operation.motion)
    else
      @motion("right")
      @vim.enterCommandMode()
  startRecording: (register) ->
    @recording = register
    @recordings[register] = []
    @vim.startedRecording()
  stopRecording: ->
    @recording = false
    @vim.stoppedRecording()
  replayRecording: (register) ->
    return if @recording
    record = @recordings[register]
    if record? && record.length > 0
      for operation in record
        operation.perform(@target, operation.motion)
  startTransaction: ->
    @vim.startTransaction()
  editSession: ->
    @vim.editor.activeEditSession
  currentCursorPosition: ->
    @editSession()?.getCursorBufferPosition()
  setCursorPosition: (pos) ->
    @editSession()?.setCursorBufferPosition(pos)
  insertText: (text) ->
    @editSession()?.insertText(text)
  clearSelection: ->
    @editSession()?.clearSelections()
  expandSelection: ->
    for selection in @editSession().getSelections()
      selection.expandOverLine()
  selectedText: ->
    text = ""
    for selection in @editSession().getSelections()
      l = @editSession().buffer.getTextInRange(selection.getBufferRange())
      if selection.linewise
        text = text + l + '\n'
      else
        text = text + l
    text
  yankSelection: ->
    text = @selectedText()
    @pasteBuffer[0] = text
  paste: (options={}) ->
    text = @pasteBuffer[0]
    @insertText(text) if text && text != ''
  runCommand: (input) ->
    for c in input
      if command = @commands[c]
        @target.trigger(command)
        true
    false
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
    'up-screen': () ->
      scrollSize = Math.floor((@target.scrollView[0].clientHeight / 2) / @target.lineHeight) || 1
      @target.activeEditSession.moveCursorUp(scrollSize) for n in [1..@count]
    'down-screen': () ->
      scrollSize = Math.floor((@target.scrollView[0].clientHeight / 2) / @target.lineHeight) || 1
      @target.activeEditSession.moveCursorDown(scrollSize) for n in [1..@count]
    'center-screen': () ->
      position = @target.getCursorScreenPosition()
      scrollOffset = Math.ceil((@target.scrollTop() || 0) / @target.lineHeight) || 0
      scrollSize = Math.floor((@target.scrollView[0].clientHeight / 2) / @target.lineHeight) || 1
      position.row = Math.max(0, Math.min(scrollOffset + scrollSize, @target.getLastScreenRow()))
      position.column = 0
      @target.activeEditSession.setCursorScreenPosition(position)
    'go-to-screen-line': () ->
      position = @target.getCursorScreenPosition()
      scrollOffset = Math.ceil((@target.scrollTop() || 0) / @target.lineHeight) || 0
      position.row = Math.max(0, Math.min(scrollOffset + @count - 1, @target.getLastScreenRow()))
      position.column = 0
      @target.activeEditSession.setCursorScreenPosition(position)
    'go-to-screen-line-bottom': () ->
      position = @target.getCursorScreenPosition()
      scrollOffset = Math.ceil(((@target.scrollTop() + @target.scrollView[0].clientHeight) || 0) / @target.lineHeight) || 0
      position.row = Math.max(0, Math.min(scrollOffset, @target.getLastScreenRow()) - @count)
      position.column = 0
      @target.activeEditSession.setCursorScreenPosition(position)
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
    'repeat-last-search': () ->
      state = @operation.vim.state
      if state.lastSearchMotion?
        @operation.input = state.lastSearchMotion.input if state.lastSearchMotion.input?
        state.lastSearchMotion.perform(@operation)
  commands:
    'q': "core:close"
    'w': "editor:save"
    's': "command-panel:replace-in-file"
  operations:
    'move': ->
      @performMotion()
    'select': ->
      @performSelectMotion()
    'change': ->
      @performSelectMotion()
      @yank()
      @startTransaction()
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
      @performMotion("right")
      @paste select:false
      @performMotion("left")
    'paste-before': (state) ->
      pos = state.currentCursorPosition()
      @paste select:true
      state.setCursorPosition(pos)
    'enter-visual-normal': () ->
    'enter-visual-lines': (state) ->
      @performMotion("beginning-of-line")
      state.expandSelection()
    'start-recording': (state) ->
      state.startRecording(@input)
    'stop-recording': (state) ->
      state.stopRecording()
    'replay-recording': (state) ->
      state.replayRecording(@input)
  noRepeatOperations: ['move', 'select', 'repeat', 'start-recording', 'stop-recording']
  noModeResetOperations: ['move', 'select', 'enter-visual-normal', 'enter-visual-lines']
  operationsWithInput: ['change-character', 'start-recording', 'replay-recording']
  motionsWithInput: ['find-character']
  motionsWithRequiredCount: ['go-to-line']
  searchMotions: ['find-character']
  noMotionOperations: ['repeat', 'paste', 'paste-before', 'enter-visual-normal', 'enter-visual-lines', 'start-recording', 'stop-recording', 'replay-recording']
