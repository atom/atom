{View} = require 'space-pen'
fs = require 'fs'
path = require 'path'
temp = require 'temp'
archive = require 'ls-archive'

module.exports =
class FileView extends View
  @content: (archivePath, entry) ->
    @div =>
      @span entry.getName(), class: 'entry file'

  initialize: (archivePath, entry) ->
    @on 'click', =>
      @closest('.archive-view').find('.entry').removeClass('selected')
      @addClass('selected')
      archive.readFile archivePath, entry.getPath(), (error, contents) ->
        if error?
          console.error("Error reading: #{entry.getPath()} from #{archivePath}", error.stack ? error)
        else
          temp.mkdir path.basename(archivePath), (error, tempDirPath) ->
            if error?
              console.error("Error creating temp directory: #{tempDirPath}")
            else
              tempFilePath = path.join(tempDirPath, entry.getName())
              fs.writeFile tempFilePath, contents, (error) ->
              if error?
                console.error("Error writing to #{tempFilePath}")
              else
                rootView.open(tempFilePath)
