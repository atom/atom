Template = require 'template'
stringScore = require 'stringscore'

module.exports =
class FileFinder extends Template
  content: -> @div

  viewProperties:
    urls: null

    initialize: ({@urls}) ->

    findMatches: (query) ->
      scoredUrls = ({url, score: stringScore(url, query)} for url in @urls)
      sortedUrls = scoredUrls.sort (a, b) -> a.score > b.score
      urlAndScore.url for urlAndScore in sortedUrls when urlAndScore.score > 0

