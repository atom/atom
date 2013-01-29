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

  d3 = require 'd3.v3'
  x  = d3.scale.ordinal().domain d3.range(60)
  y  = d3.scale.linear()

  @activate: (rootView, state) ->
    @instance = new EditorStatsView(rootView, state?.eventLog)

  @content: (rootView) ->
    @div class: 'editor-stats', tabindex: -1

  @serialize: ->
    @instance.serialize()

  eventlog: [],

  initialize: (@rootView, @eventLog = {}) ->
    super

    @command 'core:cancel', @detach

    date = new Date()
    future = new Date(date.getTime() + 36e5)
    @eventlog[time(date)] = 0

    while date <= future
      @eventlog[time(date)] = 0

    @rootView.on 'keydown', @track
    @rootView.on 'mouseup', @track

  draw: ->
    w = @.width()
    h = @.height()
    [pt, pl, pb, pr] = [0,0,0,0]

    data = d3.entries @eventlog
    max  = d3.max data, (d) -> d.value

    x.rangeRoundBands [0, w - pl - pr], 0.1
    y.domain([0, max]).range [h, 0]

    vis = d3.select(@.get(0)).append('svg')
      .attr('width', w)
      .attr('height', h)
    .append('g')
      .attr('transform', "translate(#{pl},#{pt})")

    bars = vis.selectAll('rect.bar')
      .data(data)
    .enter().append('rect')
      .attr('x', (d, i) => x i)
      .attr('y', (d) -> y d.value)
      .attr('height', (d) -> h - y(d.value))
      .attr('width', x.rangeBand())

    update = =>
      newdata = d3.entries @eventlog
      max  = d3.max newdata, (d) -> d.value

      x.rangeRoundBands [0, w - pl - pr], 0.1
      y.domain([0, max]).range [h, 0]

      bars.data(newdata).transition()
        .attr('height', (d, i) ->  h - y(d.value))
        .attr('y', (d, i) -> y(d.value))

    setInterval update, 5000

  track: =>
    date = new Date
    times = time date
    @eventlog[times] ||= 0
    @eventlog[times] += 1

    @eventlog.shift() if @eventlog.length > 59

  toggle: ->
    if @hasParent()
      @detach()
    else
      @attach()

  attach: ->
    @rootView.append @
    @focus()
    @draw()

  detach: =>
    super()
    @rootView.focus()

  serialize: ->
    eventLog: @eventLog