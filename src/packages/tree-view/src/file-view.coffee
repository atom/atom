{View, $$} = require 'space-pen'
$ = require 'jquery'
Git = require 'git'
fs = require 'fs'

module.exports =
class FileView extends View

  @content: (file) ->
    @li class: 'file entry', =>
      @span file.getBaseName(), class: 'name', outlet: 'fileName'
      @span "", class: 'highlight'

  file: null

  initialize: (@file) ->
    path = @getPath()
    extension = fs.extension(path)
    if fs.isCompressedExtension(extension)
      @fileName.addClass('compressed-name')
    else if fs.isImageExtension(extension)
      @fileName.addClass('image-name')
    else if fs.isPdfExtension(extension)
      @fileName.addClass('pdf-name')
    else
      @fileName.addClass('text-name')

    @addClass('ignored') if new Git(path).isPathIgnored(path)

  getPath: ->
    @file.path
