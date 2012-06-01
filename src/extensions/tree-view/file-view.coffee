{View, $$} = require 'space-pen'
$ = require 'jquery'

module.exports =
class FileView extends View
  @content: (file) ->
    @li file.getName(), class: 'file entry'

  file: null

  initialize: (@file) ->

  getPath: ->
    @file.path
