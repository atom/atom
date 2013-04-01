fs = require 'fs-utils'
$ = require 'jquery'
ScrollView = require 'scroll-view'
{$$$} = require 'space-pen'

module.exports =
class DiffView extends ScrollView
  registerDeserializer(this)

  @deserialize: ({path}) ->
    new DiffView(project.bufferForPath(path))

  @content: ->
    @div class: 'editor diff', tabindex: -1

  initialize: (@buffer, @changes) ->
    super
    @createDiffView()
    @on 'core:move-up', => @scrollUp()
    @on 'core:move-down', => @scrollDown()

  serialize: ->
    deserializer: 'DiffView'
    path: @buffer.getPath()

  getTitle: ->
    "Diff – #{@buffer.getBaseName()}"

  createDiffView: ->
    @html("<pre>" + @changes + "</pre>")