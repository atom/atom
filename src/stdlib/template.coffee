$ = require 'jquery'
_ = require 'underscore'
Builder = require 'template/builder'

module.exports =
class Template
  @events: 'blur change click dblclick error focus keydown 
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

  build: (attributes) ->
    @builder = new Builder
    @content(attributes)
    view = @builder.toFragment()
    @wireOutlets(view)
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

  wireOutlets: (view) ->
    view.find('[outlet]').each ->
      elt = $(this)
      outletName = elt.attr('outlet')
      view[outletName] = elt

  bindEvents: (view) ->
    for eventName in this.constructor.events
      view.find("[#{eventName}]").each ->
        elt = $(this)
        methodName = elt.attr(eventName)
        elt[eventName]((event) -> view[methodName](event, elt))

