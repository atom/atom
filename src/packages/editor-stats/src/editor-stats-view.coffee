ScrollView = require 'scroll-view'
d3 = require 'd3.v3'

module.exports =
class EditorStatsView extends ScrollView
  hours = 4

  time = (date) ->
    date.setTime(date.getTime() + 6e4)
    hour = date.getHours()
    minute = date.getMinutes()
    "#{hour}:#{minute}"

  startDate = new Date
  x  = d3.scale.ordinal().domain d3.range(hours * 60)
  y  = d3.scale.linear()

  xaxis = d3.svg.axis().scale(x)
    .orient('top')
    .tickFormat (d) ->
      d = new Date(startDate.getTime() + (d * 6e4))
      mins = d.getMinutes()
      mins = "0#{mins}" if mins < 9
      "#{d.getHours()}:#{mins}"

  @activate: (rootView, state) ->
    @instance = new EditorStatsView(rootView, state?.eventLog)

  @content: (rootView) ->
    @div class: 'editor-stats', tabindex: -1

  @serialize: ->
    @instance.serialize()

  eventLog: []

  initialize: (@rootView, @eventLog = {}) ->
    super

    @command 'core:cancel', @detach
    @statusBar = @rootView.find '.status-bar'

    date = new Date(startDate)
    future = new Date(date.getTime() + (36e5 * hours))
    @eventLog[time(date)] = 0

    while date < future
      @eventLog[time(date)] = 0

    @rootView.on 'keydown', @track
    @rootView.on 'mouseup', @track

  draw: ->
    w = @statusBar.outerWidth()
    h = @.height()
    [pt, pl, pb, pr] = [15,0,0,0]

    data = d3.entries @eventLog

    x.rangeRoundBands [0, w - pl - pr], 0.2
    y.range [h, 0]
    xaxis.tickSize(-h + pt + pb, 50)

    vis = d3.select(@.get(0)).append('svg')
      .attr('width', w)
      .attr('height', h)
    .append('g')
      .attr('transform', "translate(#{pl},#{pt})")

    vis.append('g')
      .attr('class', 'x axis')
      .call(xaxis)
    .selectAll('g')
      .style('display', (d, i) ->
        if i % 15 == 0 || i % 5 == 0
          'block'
        else
          'none'
      ).classed('minor', (d, i) -> i % 5 == 0 && i % 15 != 0)

    bars = vis.selectAll('rect.bar')
      .data(data)
    .enter().append('rect')
      .attr('x', (d, i) -> x i)
      .attr('y', (d) -> y d.value)
      .attr('width', x.rangeBand())
      .attr('class', 'bar')

    update = =>
      newdata = d3.entries @eventLog
      max  = d3.max newdata, (d) -> d.value

      y.domain [0, max]

      bars.data(newdata).transition()
        .attr('height', (d, i) ->  h - y(d.value))
        .attr('y', (d, i) -> y d.value)

      bars.classed('max', (d, i) -> d.value == max)

    setInterval update, 5000

  track: =>
    date = new Date
    times = time date
    @eventLog[times] ||= 0
    @eventLog[times] += 1
    @eventLog.shift() if @eventLog.length > (hours * 60)

  toggle: ->
    if @hasParent()
      @detach()
    else
      @attach()

  attach: ->
    @.insertBefore @statusBar
    @draw()

  detach: ->
    super
    @rootView.focus()

  serialize: ->
    eventLog: @eventLog
