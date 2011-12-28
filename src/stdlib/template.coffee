$ = require 'jquery'
_ = require 'underscore'
Builder = require 'template/builder'

module.exports =
class Template
  @buildTagMethod: (name) ->
    this.prototype[name] = (args...) -> @builder.tag(name, args...)

  _.each(Builder.elements.normal, (name) => @buildTagMethod(name))
  _.each(Builder.elements.void, (name) => @buildTagMethod(name))

  @build: (attributes) ->
    (new this).build(attributes)

  build: (attributes) ->
    @builder = new Builder
    @content(attributes)
    view = @builder.toFragment()
    @wireOutlets(view)
    if @viewProperties
      $.extend(view, @viewProperties)
    view.initialize?(attributes)
    view

  wireOutlets: (view) ->
    view.find('[outlet]').each ->
      elt = $(this)
      outletName = elt.attr('outlet')
      view[outletName] = elt
