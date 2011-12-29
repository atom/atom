_ = require 'underscore'
$ = require 'jquery'
OpenTag = require 'template/open-tag'
CloseTag = require 'template/close-tag'
Text = require 'template/text'

module.exports =
class Builder
  @elements:
    normal: 'a abbr address article aside audio b bdi bdo blockquote body button
      canvas caption cite code colgroup datalist dd del details dfn div dl dt em
      fieldset figcaption figure footer form h1 h2 h3 h4 h5 h6 head header hgroup
      html i iframe ins kbd label legend li map mark menu meter nav noscript object
      ol optgroup option output p pre progress q rp rt ruby s samp script section
      select small span strong style sub summary sup table tbody td textarea tfoot
      th thead time title tr u ul video'.split /\s+/

    void: 'area base br col command embed hr img input keygen link meta param
      source track wbr'.split /\s+/

  constructor: ->
    @reset()

  toHtml: ->
    _.map(@document, (x) -> x.toHtml()).join('')

  toFragment: ->
    fragment = $(@toHtml())
    fn(fragment) for fn in @postProcessingFns
    fragment

  tag: (name, args...) ->
    options = @extractOptions(args)

    @document.push(new OpenTag(name, options.attributes))
    if @elementIsVoid(name)
      if (options.text? or options.content?)
        throw new Error("Self-closing tag #{tag} cannot have text or content")
    else
      options.content?()
      @text(options.text) if options.text
      @document.push(new CloseTag(name))

  subview: (outletName, subview) ->
    subviewId = _.uniqueId('subview')
    @tag 'div', id: subviewId
    @postProcessingFns.push (view) ->
      view[outletName] = subview
      view.find("div##{subviewId}").replaceWith(subview)

  elementIsVoid: (name) ->
    name in @constructor.elements.void

  extractOptions: (args) ->
    options = {}
    for arg in args
      options.content = arg if _.isFunction(arg)
      options.text = arg if _.isString(arg)
      options.text = arg.toString() if _.isNumber(arg)
      options.attributes = arg if _.isObject(arg) and not _.isFunction(arg)
    options

  text: (string) ->
    @document.push(new Text(string))

  reset: ->
    @document = []
    @postProcessingFns = []

