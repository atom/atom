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

    if git?
      @subscribe git, 'status-changed', (path, status) =>
        @updateStatus() if path is @getPath()
      @subscribe git, 'statuses-changed', =>
        @updateStatus()

    @updateStatus()

  updateStatus: ->
    @removeClass('ignored modified new')
    return unless git?

    path = @getPath()
    if git.isPathIgnored(path)
      @addClass('ignored')
    else
      status = git.statuses[path]
      if git.isStatusModified(status)
        @addClass('modified')
      else if git.isStatusNew(status)
        @addClass('new')

  getPath: ->
    @file.path
