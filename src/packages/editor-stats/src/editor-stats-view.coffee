ScrollView = require 'scroll-view'
d3 = require 'd3.v3'

module.exports =
class EditorStatsView extends ScrollView
  @activate: (rootView, state) ->
    @instance = new EditorStatsView(rootView)

  @content: (rootView) ->
    @div class: 'editor-stats-wrapper', tabindex: -1, =>
      @div class: 'editor-stats', outlet: 'editorStats'

  initialize: (@rootView) ->
    super

    @command 'core:cancel', @detach
    @statusBar = @rootView.find('.status-bar')
    @css 'background', @statusBar.css('background-color')

  draw: ->
    @x ?= d3.scale.ordinal().domain d3.range(@stats.hours * 60)
    @y ?= d3.scale.linear()
    w = @rootView.vertical.width()
    h = @height()
    [pt, pl, pb, pr] = [15, 10, 3, 25]

    data = d3.entries @stats.eventLog

    @x.rangeBands [0, w - pl - pr], 0.2
    @y.range [h - pt - pb, 0]

    @xaxis ?= d3.svg.axis().scale(@x).orient('top').tickFormat (d) =>
               d = new Date(@stats.startDate.getTime() + (d * 6e4))
               mins = d.getMinutes()
               mins = "0#{mins}" if mins < 9
               "#{d.getHours()}:#{mins}"
    @xaxis.tickSize(-h + pt + pb, 50)

    vis = d3.select(@editorStats.get(0)).append('svg')
      .attr('width', w)
      .attr('height', h)
    .append('g')
      .attr('transform', "translate(#{pl},#{pt})")

    vis.append('g')
      .attr('class', 'x axis')
      .call(@xaxis)
    .selectAll('g')
      .style('display', (d, i) ->
        if i % 15 == 0 || i % 5 == 0 || i == data.length - 1
          'block'
        else
          'none'
      ).classed('minor', (d, i) -> i % 5 == 0 && i % 15 != 0)

    bars = vis.selectAll('rect.bar')
      .data(data)
    .enter().append('rect')
      .attr('x', (d, i) => @x i)
      .attr('y', (d) => @y(d.value))
      .attr('width', @x.rangeBand())
      .attr('class', 'bar')

    update = =>
      newdata = d3.entries @stats.eventLog
      max  = d3.max newdata, (d) -> d.value

      @y.domain [0, max]

      bars.data(newdata).transition()
        .attr('height', (d, i) =>  h - @y(d.value) - pt - pb)
        .attr('y', (d, i) => @y(d.value))

      bars.classed('max', (d, i) -> d.value == max)

    setInterval update, 5000

  toggle: (@stats) ->
    if @hasParent()
      @detach()
    else
      @attach()

  attach: ->
    @rootView.vertical.append(@)
    @draw()

  detach: ->
    super()
    @rootView.focus()
