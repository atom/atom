{View} = require 'space-pen'
fs = require 'fs'
OperationView = require './operation-view'
$ = require 'jquery'

module.exports =
class PathView extends View
  @content: ({path, operations, previewList} = {}) ->
    classes = ['path']
    classes.push('readme') if fs.isReadmePath(path)
    @li class: classes.join(' '), =>
      @span class: 'path-name', path
      @span "(#{operations.length})", class: 'path-match-number'
      @ul outlet: 'matches', class: 'matches', =>
        for operation in operations
          @subview "operation#{operation.index}", new OperationView({operation, previewList})

  initialize: ({previewList}) ->
    @on 'mousedown', @onPathSelected
    previewList.command 'command-panel:collapse-result', =>
      @collapse(true) if @isSelected()
    previewList.command 'command-panel:expand-result', =>
      @expand(true) if @isSelected()

  isSelected: ->
    @hasClass('selected') or @find('.selected').length

  onPathSelected: (event) =>
    e = $(event.target)
    e = e.parent() if e.parent().hasClass 'path'
    @toggle(true) if e.hasClass 'path'

  toggle: (animate) ->
    if @hasClass('is-collapsed')
      @expand(animate)
    else
      @collapse(animate)

  expand: (animate=false) ->
    if animate
      @matches.show 100, => @removeClass 'is-collapsed'
    else
      @matches.show()
      @removeClass 'is-collapsed'

  collapse: (animate=false) ->
    if animate
      @matches.hide 100, => @addClass 'is-collapsed'
    else
      @matches.hide()
      @addClass 'is-collapsed'
