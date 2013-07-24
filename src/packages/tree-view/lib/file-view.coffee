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

    repo = project.getRepo()
    if repo?
      @subscribe repo, 'status-changed', (changedPath, status) =>
        @updateStatus() if changedPath is @getPath()
      @subscribe repo, 'statuses-changed', =>
        @updateStatus()

    @updateStatus()

  updateStatus: ->
    @removeClass('ignored modified new')
    repo = project.getRepo()
    return unless repo?

    filePath = @getPath()
    if repo.isPathIgnored(filePath)
      @addClass('ignored')
    else
      status = repo.statuses[filePath]
      if repo.isStatusModified(status)
        @addClass('modified')
      else if repo.isStatusNew(status)
        @addClass('new')

  getPath: ->
    @file.path
