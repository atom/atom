{$$$} = require 'space-pen'
ScrollView = require 'scroll-view'
$ = require 'jquery'
_ = require 'underscore'

module.exports =
class EditorStatsView extends ScrollView
  time = (date) ->
    date.setTime(date.getTime() + 6e4)
    hour = date.getHours()
    minute = date.getMinutes()
    "#{hour}:#{minute}"

  @activate: (rootView, state) ->
    @instance = new EditorStatsView(rootView, state?.eventLog)

  @content: (rootView) ->
    @div class: 'editor-stats', tabindex: -1

  @serialize: ->
    @instance.serialize()

  eventlog: [],

  initialize: (@rootView, @eventLog = {}) ->
    super

    date = new Date()
    future = new Date(date.getTime() + 36e5)
    @eventlog[time(date)] = 0

    while date <= future
      @eventlog[time(date)] = 0

    @rootView.on 'keyup', @track
    @rootView.on 'mousedown', @track

  track: =>
    date = new Date
    @eventlog[time(date)] += 1
    console.log @eventlog

  toggle: ->
    if @hasParent()
      @detach()
    else
      @attach()

  attach: ->
    @rootView.append @
    @focus()

  detach: ->
    super()
    @rootView.focus()

  serialize: ->
    eventLog: @eventLog