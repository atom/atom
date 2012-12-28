{View, $$$} = require 'space-pen'
ScrollView = require 'scroll-view'
$ = require 'jquery'
_ = require 'underscore'
d3 = require 'd3.v3'

module.exports =
class CommandLogger extends ScrollView
  @activate: (rootView, state) ->
    @instance = new CommandLogger(rootView, state?.eventLog)

  @content: (rootView) ->
    @div class: 'command-logger', tabindex: -1, =>
      @h1 class: 'category-header', outlet: 'categoryHeader'
      @div class: 'tree-map', outlet: 'treeMap'

  @serialize: ->
    @instance.serialize()

  eventLog: null

  initialize: (@rootView, @eventLog={}) ->
    super

    requireStylesheet 'command-logger.css'

    @rootView.command 'command-logger:toggle', => @toggle()
    @rootView.command 'command-logger:clear-data', => @eventLog = {}
    @command 'core:cancel', => @detach()

    registerEvent = (eventName) =>
      eventNameLog = @eventLog[eventName]
      unless eventNameLog
        eventNameLog = count: 0, name: eventName
        @eventLog[eventName] = eventNameLog
      eventNameLog.count++
      eventNameLog.lastRun = new Date().getTime()

    originalTrigger = $.fn.trigger
    $.fn.trigger = (eventName) ->
      eventName = eventName.type if eventName.type
      registerEvent(eventName) if $(this).events()[eventName]
      originalTrigger.apply(this, arguments)

  toggle: ->
    if @hasParent()
      @detach()
    else
      @attach()

  createRootChildren:  ->
    categories = {}
    for eventName, details of @eventLog
      categoryStart = eventName.indexOf(':')
      categoryName = _.humanizeEventName(eventName.substring(0, categoryStart))
      category = categories[categoryName]
      unless category
        category = name: _.humanizeEventName(categoryName), children: []
        categories[categoryName] = category
      category.children.push
        name: "#{_.humanizeEventName(eventName.substring(categoryStart + 1))} (#{details.count})"
        size: details.count
    _.toArray(categories)

  addTreeMap: ->
    root =
     name: 'All'
     children: @createRootChildren()
    node = root

    @treeMap.empty()

    w = @treeMap.width()
    h = @treeMap.height()
    x = d3.scale.linear().range([0, w])
    y = d3.scale.linear().range([0, h])
    color = d3.scale.category20()

    setCategoryHeader = (node) =>
      @categoryHeader.text("#{node.name} Commands")
    setCategoryHeader(root)

    zoom = (d) ->
      setCategoryHeader(d)
      kx = w / d.dx
      ky = h / d.dy
      x.domain([d.x, d.x + d.dx])
      y.domain([d.y, d.y + d.dy])

      t = svg.selectAll('g.node').transition()
             .duration(750)
             .attr('transform', (d) -> "translate(#{x(d.x)},#{y(d.y)})")

      t.select('rect')
       .attr('width', (d) -> kx * d.dx - 1)
       .attr('height', (d) -> ky * d.dy - 1)

      t.select('text')
       .attr('x', (d) -> kx * d.dx / 2)
       .attr('y', (d) -> ky * d.dy / 2)
       .style('opacity', (d) -> if kx * d.dx > d.w then 1 else 0)

      node = d
      d3.event.stopPropagation()

    treemap = d3.layout.treemap()
                       .round(false)
                       .size([w, h])
                       .sticky(true)
                       .value((d) -> d.size)

    svg = d3.select('.command-logger .tree-map')
            .append('div')
            .style('width', "#{w}px")
            .style('height', "#{h}px")
            .append('svg:svg')
            .attr('width', w)
            .attr('height', h)
            .append('svg:g')
            .attr('transform', 'translate(.5,.5)')

    nodes = treemap.nodes(root).filter((d) -> not d.children)

    cell = svg.selectAll('g')
              .data(nodes)
              .enter()
              .append('svg:g')
              .attr('class', 'node')
              .attr('transform', (d) -> "translate(#{d.x},#{d.y})")
              .on('click', (d) -> if node is d.parent then zoom(root) else zoom(d.parent))

    cell.append('svg:rect')
        .attr('width', (d) -> d.dx - 1)
        .attr('height', (d) -> d.dy - 1)
        .style('fill', (d) -> color(d.parent.name))

    cell.append('svg:text')
        .attr('x', (d) -> d.dx / 2)
        .attr('y', (d) -> d.dy / 2)
        .attr('dy', '.35em')
        .attr('text-anchor', 'middle')
        .text((d) -> d.name)
        .style('opacity', (d) -> d.w = this.getComputedTextLength(); if d.dx > d.w then 1 else 0)

    d3.select('.command-logger').on('click', -> zoom(root))

  attach: ->
    @rootView.append(this)
    @addTreeMap()
    @focus()

  detach: ->
    super()
    @rootView.focus()

  serialize: ->
    eventLog: @eventLog
