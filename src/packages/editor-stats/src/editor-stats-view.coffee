ScrollView = require 'scroll-view'
d3 = require 'd3.v3'
_ = require 'underscore'
$ = require 'jquery'

module.exports =
class EditorStatsView extends ScrollView
  @activate: (rootView, state) ->
    @instance = new EditorStatsView(rootView)

  @content: (rootView) ->
    @div class: 'editor-stats-wrapper', tabindex: -1, =>
      @div class: 'editor-stats', outlet: 'editorStats'

  pt: 15
  pl: 10
  pb: 3
  pr: 25

  initialize: (@rootView) ->
    super

    resizer = =>
      @draw()
      @update()
    @subscribe $(window), 'resize', _.debounce(resizer, 300)

  draw: ->
    @editorStats.empty()
    @x ?= d3.scale.ordinal().domain d3.range(@stats.hours * 60)
    @y ?= d3.scale.linear()
    w = @rootView.vertical.width()
    h = @height()
    data = d3.entries @stats.eventLog
    max  = d3.max data, (d) -> d.value

    @x.rangeBands [0, w - @pl - @pr], 0.2
    @y.domain([0, max]).range [h - @pt - @pb, 0]

    @xaxis ?= d3.svg.axis().scale(@x).orient('top')
      .tickSize(-h + @pt + @pb)
      .tickFormat (d) =>
        d = new Date(@stats.startDate.getTime() + (d * 6e4))
        mins = d.getMinutes()
        mins = "0#{mins}" if mins <= 9
        "#{d.getHours()}:#{mins}"

    vis = d3.select(@editorStats.get(0)).append('svg')
      .attr('width', w)
      .attr('height', h)
    .append('g')
      .attr('transform', "translate(#{@pl},#{@pt})")

    vis.append('g')
      .attr('class', 'x axis')
      .call(@xaxis)
    .selectAll('g')
      .classed('minor', (d, i) -> i % 5 == 0 && i % 15 != 0)
      .style 'display', (d, i) ->
        if i % 15 == 0 || i % 5 == 0 || i == data.length - 1
          'block'
        else
          'none'

    @bars = vis.selectAll('rect.bar')
      .data(data)
    .enter().append('rect')
      .attr('x', (d, i) => @x i)
      .attr('height', (d, i) => h - @y(d.value) - @pt - @pb)
      .attr('y', (d) => @y(d.value))
      .attr('width', @x.rangeBand())
      .attr('class', 'bar')

    setTimeout((=> @update()), 100)
    clearInterval(@updateInterval)
    @updateInterval = setInterval((=> @update()), 5000)

  update: ->
    newData = d3.entries @stats.eventLog
    max  = d3.max newData, (d) -> d.value
    @y.domain [0, max]
    h = @height()
    @bars.data(newData).transition()
      .attr('height', (d, i) =>  h - @y(d.value) - @pt - @pb)
      .attr('y', (d, i) => @y(d.value))
    @bars.classed('max', (d, i) -> d.value == max)

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
    clearInterval(@updateInterval)
    @rootView.focus()
