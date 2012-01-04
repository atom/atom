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
    maxResults: null

    initialize: ({@urls, @selected}) ->
      @maxResults = 10

      @populateUrlList()
      @bindKey 'up', 'moveUp'
      @bindKey 'down', 'moveDown'
      @bindKey 'enter', 'select'

    populateUrlList: ->
      @urlList.empty()
      for url in @findMatches(@input.val())
        @urlList.append $("<li>#{url}</li>")

      @urlList.children('li:first').addClass 'selected'

    findSelectedLi: ->
      @urlList.children('li.selected')

    select: ->
      filePath = @findSelectedLi().text()
      @selected(filePath) if filePath and @selected

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
      if not query
        urls = @urls
      else
        scoredUrls = ({url, score: stringScore(url, query)} for url in @urls)
        scoredUrls.sort (a, b) -> a.score > b.score
        urls = (urlAndScore.url for urlAndScore in scoredUrls when urlAndScore.score > 0)

      urls.slice 0, @maxResults
