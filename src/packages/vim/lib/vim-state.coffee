module.exports =
class VimState
  constructor: (@target, @vim) ->
    @resetState()
    for m,event of @motionEvents
      do (m, event) =>
        @target.command "vim:motion-#{m}", => @motion(m)
  motion: (type) ->
    event = @motionEvents[type]
    window.console.log "Performing motion #{type} with event #{event}"
    @target.trigger(event) for n in [1..@_count]
    @resetState()
  addCountDecimal: (n) ->
    @_count = 0 if @state != "count"
    @enterState "count"
    @_count = @_count * 10 + n if n?
    @stateUpdated()
    @_count
  count: (n) ->
    @_count = n if n?
    @_count
  operation: (type) ->

  resetState: ->
    @enterState "idle"
    @_count = 1
  enterState: (state) ->
    @state = state
    @vim.stateChanged(@state) if @vim? and @vim.stateChanged?
  stateUpdated: ->
    @vim.stateUpdated(@state) if @vim? and @vim.stateUpdated?
  operations: {}

  motionEvents:
    left: "core:move-left"
    right: "core:move-right"
    up: "core:move-up"
    down: "core:move-down"