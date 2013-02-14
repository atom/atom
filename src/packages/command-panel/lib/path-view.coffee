{View} = require 'space-pen'
fs = require 'fs'
OperationView = require './operation-view'
$ = require 'jquery'

module.exports =
class PathView extends View
  @content: ({path, operations} = {}) ->
    classes = ['path']
    classes.push('readme') if fs.isReadmePath(path)
    @li class: classes.join(' '), =>
      @span class: 'path-name', path
      @span "(#{operations.length})", class: 'path-match-number'
      @ul outlet: 'matches', class: 'matches', =>
        for operation in operations
          @subview "operation#{operation.index}", new OperationView({operation})

  initialize: ->
    @on 'mousedown', @onPathSelected

  onPathSelected: (event) =>
    e = $(event.target)
    e = e.parent() if e.parent().hasClass 'path'
    if e.hasClass 'path'
      @matches.toggle 100, => @toggleClass 'is-collapsed'

  expand: ->
    @matches.show()
    @removeClass 'is-collapsed'

  collapse: ->
    @matches.hide()
    @addClass 'is-collapsed'
