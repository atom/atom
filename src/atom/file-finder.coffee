$ = require 'jquery'
{View} = require 'space-pen'
stringScore = require 'stringscore'

module.exports =
class FileFinder extends View
  @content: ->
    @div class: 'file-finder', =>
      @link rel: 'stylesheet', href: "#{require.resolve('file-finder.css')}?#{(new Date).getTime()}"
      @ol outlet: 'urlList'
      @input outlet: 'input', input: 'populateUrlList'

  urls: null
  maxResults: null

  initialize: ({@urls, @selected}) ->
    @maxResults = 10

    @populateUrlList()
    atom.bindKeys ".file-finder",
      'up': 'move-up'
      'down': 'move-down'
      'enter': 'select'

    @on 'move-up', => @moveUp()
    @on 'move-down', => @moveDown()
    @on 'select', => @select()

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
    @remove()

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
      scoredUrls.sort (a, b) ->
        if a.score > b.score then -1
        else if a.score < b.score then 1
        else 0
      window.x = scoredUrls

      urls = (urlAndScore.url for urlAndScore in scoredUrls when urlAndScore.score > 0)

    urls.slice 0, @maxResults
