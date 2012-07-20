{$$$, View} = require 'space-pen'

module.exports =
class PreviewList extends View
  @content: ->
    @ol class: 'preview-list', ->

  selectedOperationIndex: 0
  operations: null

  initialize: ->

  populate: (@operations) ->
    @empty()
    @html $$$ ->
      for operation in operations
        {prefix, suffix, match} = operation.preview()
        @li =>
          @span operation.getPath(), outlet: "path", class: "path"
          @span outlet: "preview", class: "preview", =>
            @span prefix
            @span match, class: 'match'
            @span suffix

    @setSelectedOperationIndex(0)

    @show()

  setSelectedOperationIndex: (index) ->
    @children(".selected").removeClass('selected')
    console.log @children("li:eq(#{index})")
    @children("li:eq(#{index})").addClass('selected')

  #getSelectedOperation: ->
    #@operations[@selectedOperationIndex]
