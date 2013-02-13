module.exports =
class VimState
  constructor: (@target) ->
    @resetState()

  motion: (type) ->
    event = @motionEvents[type]
    window.console.log "Performing motion #{type} with event #{event}"
    @target.trigger(event) for n in [1..@_count]
    @resetState()
  addCountDecimal: (n) ->
    @_count = 0 if @state != "count"
    @state = "count"
    @_count = @_count * 10 + n if n?
    @_count
  count: (n) ->
    @_count = n if n?
    @_count
  operation: (type) ->

  resetState: ->
    @state = "idle"
    @_count = 1

  operations: {}

  motionEvents:
    left: "core:move-left"
    right: "core:move-right"
    up: "core:move-up"
    down: "core:move-down"