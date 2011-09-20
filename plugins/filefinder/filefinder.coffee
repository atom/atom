$ = require 'jquery'
_ = require 'underscore'

{activeWindow} = require 'app'
File = require 'fs'
Pane = require 'pane'

jQuery  = $
facebox = eval File.read require.resolve 'filefinder/facebox'
require 'filefinder/stringscore'

module.exports =
class Filefinder extends Pane
  showing: false
  files: []

  html: require "filefinder/filefinder.html"

  keymap: ->
    'Command-T': @toggle
    # really wish i could put up/down keyboad shortcuts here
    # and have them activated when the filefinder is open

  initialize: ->
    $('#filefinder input').live 'keydown', @onKeydown

    css   = File.read require.resolve 'filefinder/facebox.css'
    head  = $('head')[0]
    style = document.createElement 'style'
    rules = document.createTextNode css
    style.type = 'text/css'
    style.appendChild rules
    head.appendChild style

  onKeydown: (e) =>
    keys = up: 38, down: 40, enter: 13

    if e.keyCode is keys.enter
      @openSelected()
    else if e.keyCode is keys.up
      @moveUp()
    else if e.keyCode is keys.down
      @moveDown()
    else
      @filterFiles()

  toggle: ->
    if @showing
      $.facebox.close()
    else
      @showFinder()
    @showing = not @showing

  showFinder: ->
    $.facebox @html
    @files = []
    for file in activeWindow.project.paths()
      @files.push file.replace "#{activeWindow.project.dir}/", ''
    @filterFiles()

  findMatchingFiles: (query) ->
    return [] if not query

    results = []
    for file in @files
      score = file.score query
      if score > 0
        # Basename matches count for more.
        if not query.match '/'
          if name.match '/'
            score += name.replace(/^.*\//, '').score query
          else
            score *= 2
        results.push [score, file]

    sorted = results.sort (a, b) -> b[0] - a[0]
    _.map sorted, (el) -> el[1]

  filterFiles: ->
    if query = $('#filefinder input').val()
      files = @findMatchingFiles query
    else
      files = @files
    $('#filefinder ul').empty()
    for file in files[0..10]
      $('#filefinder ul').append "<li>#{file}</li>"
    $('#filefinder input').focus()
    $('#filefinder li:first').addClass 'selected'

  openSelected: ->
    dir  = activeWindow.project.dir
    file = $('#filefinder .selected').text()
    activeWindow.open "#{dir}/#{file}"
    @toggle()

  moveUp: ->
    selected = $('#filefinder .selected')
    if selected.prev().length
      selected.prev().addClass 'selected'
      selected.removeClass 'selected'

  moveDown: ->
    selected = $('#filefinder .selected')
    if selected.next().length
      selected.next().addClass 'selected'
      selected.removeClass 'selected'