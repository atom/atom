{View} = require 'space-pen'
$ = require 'jquery'
fsUtils = require 'fs-utils'
path = require 'path'

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
      extension = path.extname(@getPath())
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
      @subscribe git, 'status-changed', (changedPath, status) =>
        @updateStatus() if changedPath is @getPath()
      @subscribe git, 'statuses-changed', =>
        @updateStatus()

    @updateStatus()

  updateStatus: ->
    @removeClass('ignored modified new')
    return unless git?

    filePath = @getPath()
    if git.isPathIgnored(filePath)
      @addClass('ignored')
    else
      status = git.statuses[filePath]
      if git.isStatusModified(status)
        @addClass('modified')
      else if git.isStatusNew(status)
        @addClass('new')

  getPath: ->
    @file.path
