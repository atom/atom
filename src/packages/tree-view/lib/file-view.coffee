{View} = require 'space-pen'
$ = require 'jquery'
fsUtils = require 'fs-utils'

module.exports =
class FileView extends View

  @content: ({file} = {}) ->
    @li class: 'file entry', =>
      @span class: 'highlight'
      @span file.getBaseName(), class: 'name', outlet: 'fileName'

  file: null

  initialize: ({@file, @project} = {}) ->
    if @file.symlink
      @fileName.addClass('symlink-icon')
    else
      extension = fsUtils.extension(@getPath())
      if fsUtils.isReadmePath(@getPath())
        @fileName.addClass('readme-icon')
      else if fsUtils.isCompressedExtension(extension)
        @fileName.addClass('compressed-icon')
      else if fsUtils.isImageExtension(extension)
        @fileName.addClass('image-icon')
      else if fsUtils.isPdfExtension(extension)
        @fileName.addClass('pdf-icon')
      else if fsUtils.isBinaryExtension(extension)
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
