{View} = require 'space-pen'
fs = require 'fs'
OperationView = require './operation-view'
$ = require 'jquery'

module.exports =
class PathView extends View
  @content: ({path, previewList} = {}) ->
    classes = ['path']
    classes.push('readme') if fs.isReadmePath(path)
    @li class: classes.join(' '), =>
      @div outlet: 'pathDetails', class: 'path-details', =>
        @span class: 'path-name', path
        @span outlet: 'description', class: 'path-match-number'
      @ul outlet: 'matches', class: 'matches', =>

  initialize: ({operations, @previewList}) ->
    @pathDetails.on 'mousedown', => @toggle(true)
    @subscribe @previewList, 'command-panel:collapse-result', =>
      @collapse(true) if @isSelected()
    @subscribe @previewList, 'command-panel:expand-result', =>
      @expand(true) if @isSelected()
    @subscribe @previewList, 'core:confirm', =>
      if @hasClass('selected')
        @toggle(true)
        false

    @addOperation(operation) for operation in operations

  addOperation: (operation) ->
    @matches.append new OperationView({operation, @previewList})
    @description.text("(#{@matches.find('li').length})")

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

  scrollTo: ->
    top = @previewList.scrollTop() + @offset().top - @previewList.offset().top
    bottom = top + @pathDetails.outerHeight()
    @previewList.scrollTo(top, bottom)

  collapse: (animate=false) ->
    if animate
      @matches.hide 100, =>
        @addClass 'is-collapsed'
        @setSelected() if @isSelected()
    else
      @matches.hide()
      @addClass 'is-collapsed'
      @setSelected() if @isSelected()
