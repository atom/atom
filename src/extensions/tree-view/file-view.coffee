{View, $$} = require 'space-pen'
$ = require 'jquery'

module.exports =
class FileView extends View
  @content: (file) ->
    @li file.getName(), class: 'file entry', path: file.path

  initialize: (@file) ->
