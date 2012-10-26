{View, $$} = require 'space-pen'
$ = require 'jquery'
Git = require 'git'

module.exports =
class FileView extends View
  @content: (file) ->
    @li file.getBaseName(), class: 'file entry'

  file: null

  initialize: (@file) ->
    @addClass('ignored') if Git.isPathIgnored(@file.getPath())

  getPath: ->
    @file.path
