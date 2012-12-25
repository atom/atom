{View, $$} = require 'space-pen'
$ = require 'jquery'
Git = require 'git'

module.exports =
class FileView extends View
  @content: (file) ->
    @li class: 'file entry', =>
      @span file.getBaseName(), class: 'name'
      @span "", class: 'highlight'

  file: null

  initialize: (@file) ->
    @addClass('ignored') if new Git(@getPath()).isPathIgnored(@getPath())

  getPath: ->
    @file.path
