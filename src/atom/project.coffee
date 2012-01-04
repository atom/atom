fs = require 'fs'

module.exports =

class Project
  constructor: (@url) ->

  getFilePaths: ->
    everythingMeasure = measure "getFilePaths"
    projectUrl = @url
    fs.async.list(@url, true).pipe (urls) ->
      filterMeasure = measure "Filter out non-files"
      urls = (url.replace(projectUrl, "") for url in urls when fs.isFile(url))
      filterMeasure.stop()
      everythingMeasure.stop()
      urls

