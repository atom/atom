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
    if fs.isReadmePath(@getPath())
      @fileName.addClass('readme-icon')
    else if fs.isCompressedExtension(extension)
      @fileName.addClass('compressed-icon')
    else if fs.isImageExtension(extension)
      @fileName.addClass('image-icon')
    else if fs.isPdfExtension(extension)
      @fileName.addClass('pdf-icon')
    else if fs.isBinaryExtension(extension)
      @fileName.addClass('binary-icon')
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
    else
      status = repo.getPathStatus(path)
      if repo.isStatusModified(status)
        @addClass('modified')
      else if repo.isStatusNew(status)
        @addClass('new')

  getPath: ->
    @file.path
