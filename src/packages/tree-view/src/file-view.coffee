{View, $$} = require 'space-pen'
$ = require 'jquery'
Git = require 'git'
fs = require 'fs'
_ = require 'underscore'

module.exports =
class FileView extends View

  @COMPRESSED_EXTENSIONS: [
    '.zip'
    '.jar'
    '.tar'
    '.gz'
  ]

  @IMAGE_EXTENSIONS: [
    '.jpeg'
    '.jpg'
    '.gif'
    '.png'
  ]

  @PDF_EXTENSIONS: [
    '.pdf'
  ]

  @content: (file) ->
    @li class: 'file entry', =>
      @span file.getBaseName(), class: 'name', outlet: 'fileName'
      @span "", class: 'highlight'

  file: null

  initialize: (@file) ->
    path = @getPath()
    extension = fs.extension(path)
    if _.contains(FileView.COMPRESSED_EXTENSIONS, extension)
      @fileName.addClass('compressed-name')
    else if _.contains(FileView.IMAGE_EXTENSIONS, extension)
      @fileName.addClass('image-name')
    else if _.contains(FileView.PDF_EXTENSIONS, extension)
      @fileName.addClass('pdf-name')
    else
      @fileName.addClass('text-name')

    @addClass('ignored') if new Git(path).isPathIgnored(path)

  getPath: ->
    @file.path
