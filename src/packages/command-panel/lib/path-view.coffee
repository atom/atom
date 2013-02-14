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
      @div outlet: 'pathDetails', class: 'path-details', =>
        @span class: 'path-name', path
        @span "(#{operations.length})", class: 'path-match-number'
      @ul outlet: 'matches', class: 'matches', =>
        for operation in operations
          @subview "operation#{operation.index}", new OperationView({operation, previewList})

  initialize: ({@previewList}) ->
    @pathDetails.on 'mousedown', => @toggle(true)
    @subscribe @previewList, 'command-panel:collapse-result', =>
      @collapse(true) if @isSelected()
    @subscribe @previewList, 'command-panel:expand-result', =>
      @expand(true) if @isSelected()
    @subscribe @previewList, 'core:confirm', =>
      if @hasClass('selected')
        @toggle(true)
        false

  isSelected: ->
    @hasClass('selected') or @find('.selected').length

  setSelected: ->
    @previewList.find('.selected').removeClass('selected')
    @addClass('selected')

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
      @matches.hide 100, =>
        @addClass 'is-collapsed'
        @setSelected() if @isSelected()
    else
      @matches.hide()
      @addClass 'is-collapsed'
      @setSelected() if @isSelected()
