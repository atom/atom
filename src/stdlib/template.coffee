$ = require 'jquery'
_ = require 'underscore'
Builder = require 'template/builder'

module.exports =
class Template
  @events: 'blur change click dblclick error focus input keydown
    keypress keyup load mousedown mousemove mouseout mouseover
    mouseup resize scroll select submit unload'.split /\s+/

  @buildTagMethod: (name) ->
    this.prototype[name] = (args...) -> @builder.tag(name, args...)

  @buildTagMethod(name) for name in Builder.elements.normal
  @buildTagMethod(name) for name in Builder.elements.void

  @build: (attributes) ->
    (new this).build(attributes)

  @toHtml: (attributes) ->
    (new this).toHtml(attributes)

  build: (attributes={}) ->
    @builder = new Builder
    @content(attributes)
    view = @builder.toFragment()
    @bindEvents(view)
    if @viewProperties
      $.extend(view, @viewProperties)
    view.initialize?(attributes)
    view

  toHtml: (attributes) ->
    @builder = new Builder
    @content(attributes)
    @builder.toHtml()

  subview: (args...) ->
    @builder.subview.apply(@builder, args)

  bindEvents: (view) ->
    for eventName in this.constructor.events
      selector = "[#{eventName}]"
      elements = view.find(selector).add(view.filter(selector))

      elements.each ->
        elt = $(this)
        methodName = elt.attr(eventName)
        elt.on eventName, (event) -> view[methodName](event, elt)

