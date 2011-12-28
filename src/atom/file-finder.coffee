$ = require 'jquery'
Template = require 'template'
stringScore = require 'stringscore'

module.exports =
class FileFinder extends Template
  content: ->
    @div class: 'file-finder', =>
      @ol outlet: 'urlList'
      @input outlet: 'input', keyup: 'populateUrlList'

  viewProperties:
    urls: null

    initialize: ({@urls}) ->

    populateUrlList: ->
      @urlList.empty()
      for url in @findMatches(@input.val())
        @urlList.append $("<li>#{url}</li>")

    findMatches: (query) ->
      scoredUrls = ({url, score: stringScore(url, query)} for url in @urls)
      sortedUrls = scoredUrls.sort (a, b) -> a.score > b.score
      urlAndScore.url for urlAndScore in sortedUrls when urlAndScore.score > 0

