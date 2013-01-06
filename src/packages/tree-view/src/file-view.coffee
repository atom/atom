{View} = require 'space-pen'
$ = require 'jquery'
Git = require 'git'
fs = require 'fs'

module.exports =
class FileView extends View

  @content: ({file} = {}) ->
    @li class: 'file entry', =>
      @span file.getBaseName(), class: 'name', outlet: 'fileName'
      @span '', class: 'highlight'

  file: null

  initialize: ({@file, @project} = {}) ->
    @subscribe $(window), 'focus', => @updateStatus()

    extension = fs.extension(@getPath())
    if fs.isCompressedExtension(extension)
      @fileName.addClass('compressed-icon')
    else if fs.isImageExtension(extension)
      @fileName.addClass('image-icon')
    else if fs.isPdfExtension(extension)
      @fileName.addClass('pdf-icon')
    else
      @fileName.addClass('text-icon')

    @updateStatus()

  updateStatus: ->
    @removeClass('ignored modified new')
    repo = @project.repo
    return unless repo?

    path = @getPath()
    if repo.isPathIgnored(path)
      @addClass('ignored')
    else if repo.isPathModified(path)
      @addClass('modified')
    else if repo.isPathNew(path)
      @addClass('new')

  getPath: ->
    @file.path
