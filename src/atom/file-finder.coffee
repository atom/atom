$ = require 'jquery'
Template = require 'template'
stringScore = require 'stringscore'

module.exports =
class FileFinder extends Template
  content: ->
    @link rel: 'stylesheet', href: "#{require.resolve('file-finder.css')}?#{(new Date).getTime()}"
    @div class: 'file-finder', =>
      @ol outlet: 'urlList'
      @input outlet: 'input', input: 'populateUrlList'

  viewProperties:
    urls: null

    initialize: ({@urls}) ->
      @populateUrlList()
      @bindKey 'up', 'moveUp'
      @bindKey 'down', 'moveDown'

    populateUrlList: ->
      @urlList.empty()
      for url in @findMatches(@input.val())
        @urlList.append $("<li>#{url}</li>")

      @urlList.children('li:first').addClass 'selected'

    findSelectedLi: ->
      @urlList.children('li.selected')

    moveUp: ->
      @findSelectedLi()
        .filter(':not(:first-child)')
        .removeClass('selected')
        .prev()
        .addClass('selected')

    moveDown: ->
      @findSelectedLi()
        .filter(':not(:last-child)')
        .removeClass('selected')
        .next()
        .addClass('selected')

    findMatches: (query) ->
      return @urls unless query
      scoredUrls = ({url, score: stringScore(url, query)} for url in @urls)
      sortedUrls = scoredUrls.sort (a, b) -> a.score > b.score
      urlAndScore.url for urlAndScore in sortedUrls when urlAndScore.score > 0
