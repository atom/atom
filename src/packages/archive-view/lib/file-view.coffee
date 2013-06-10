{View} = require 'space-pen'
fsUtils = require 'fs-utils'
path = require 'path'
temp = require 'temp'
archive = require 'ls-archive'

module.exports =
class FileView extends View
  @content: (archivePath, entry) ->
    @div class: 'entry', =>
      @span entry.getName(), class: 'file', outlet: 'name'

  initialize: (archivePath, entry) ->
    @name.addClass('symlink') if entry.isSymbolicLink()

    @on 'click', =>
      @closest('.archive-view').find('.selected').removeClass('selected')
      @name.addClass('selected')
      archive.readFile archivePath, entry.getPath(), (error, contents) ->
        if error?
          console.error("Error reading: #{entry.getPath()} from #{archivePath}", error.stack ? error)
        else
          temp.mkdir 'atom-', (error, tempDirPath) ->
            if error?
              console.error("Error creating temp directory: #{tempDirPath}", error.stack ? error)
            else
              tempFilePath = path.join(tempDirPath, path.basename(archivePath), entry.getName())
              fsUtils.writeAsync tempFilePath, contents, (error) ->
                if error?
                  console.error("Error writing to #{tempFilePath}", error.stack ? error)
                else
                  rootView.open(tempFilePath)
