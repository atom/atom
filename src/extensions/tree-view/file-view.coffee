{View, $$} = require 'space-pen'
$ = require 'jquery'

module.exports =
class FileView extends View
  @content: (file) ->
    @li file.getBaseName(), class: 'file entry'

  file: null

  initialize: (@file) ->

  getPath: ->
    @file.path
