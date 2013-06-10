path = require 'path'
request = require 'request'
temp = require 'temp'
fsUtils = require 'fs-utils'

logError = (message, error) ->
  console.error(message, error.stack ? error)

openGistFile = (gist, file) ->
  request file.raw_url, (error, response, body) =>
    if error?
      logError("Error fetching Gist file contents", error)
      return

    temp.mkdir 'atom-', (error, tempDirPath) =>
      if error?
        logError("Error creating temp directory: #{tempDirPath}", error)
        return

      tempFilePath = path.join(tempDirPath, "gist-#{gist.id}", file.filename)
      fsUtils.writeAsync tempFilePath, body, (error) =>
        if error?
          logError("Error writing to #{tempFilePath}", error)
          return

        rootView.open(tempFilePath)

module.exports = {openGistFile}
