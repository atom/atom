$ = require 'jquery'
{$$} = require 'space-pen'
SelectList = require 'select-list'
path = require 'path'
fsUtils = require 'fs-utils'
_ = require 'underscore'
humanize = require 'humanize-plus'
keytar = require 'keytar'
{getAllGists, getStarredGists, openGistFile} = require './gist-utils'
GistFilesView = require './gist-files-view'

module.exports =
class GistsView extends SelectList
  @viewClass: -> "#{super} gists-view overlay from-top"

  filterKey: 'filterText'

  initialize: ->
    super

    @subscribe $(window), 'focus', => @gists = null
    @on 'github:signed-in', => @attach()

  loadGists: ->
    if @gists?
      @setArray(@gists)
      return

    @setLoading('Loading Gists\u2026')

    allGists = []
    gistsCallback = (error, gists, hasMorePages) =>
      if error?
        @setError("Error fetching Gists")
        console.error("Error fetching Gists", error.stack ? error)
      else
        for gist in gists
          gist.filterText = @getFilterText(gist)
          allGists.push(gist)
        @loadingBadge.text(humanize.intcomma(allGists.length))

    getAllGists (error, gists, hasMorePages) =>
      gistsCallback(error, gists, hasMorePages)
      if !error? and !hasMorePages
        getStarredGists (error, gists, hasMorePages) =>
          gistsCallback(error, gists, hasMorePages)
          if !error? and !hasMorePages
            @gists = allGists.sort (gist1, gist2) ->
              date1 = Date.parse(gist1.created_at)
              date2 = Date.parse(gist2.created_at)
              if date1 < date2
                1
              else if date1 > date2
                -1
              else
                0
            @setArray(@gists)

  getName: ({files, id}) ->
    _.keys(files ? {})[0] ? "Gist #{id}"

  getDescription: ({description, files}) ->
    if description
      description
    else
      "No description"

  getFilterText: ({description, files, id}) ->
    segments = []
    segments.push(id)
    segments.push(description) if description
    segments.push(name) for name, value of files ? {}
    segments.join(' ')

  itemForElement: (gist) ->
    name = @getName(gist)
    description = @getDescription(gist)
    $$ ->
      @li class: 'two-lines', =>
        @div name, class: 'primary-line'
        @div description, class: 'secondary-line'

  toggle: ->
    if @hasParent()
      @cancel()
    else
      @attach()

  hasToken: -> keytar.getPassword('github.com', 'github')

  attach: ->
    super

    if @hasToken()
      rootView.append(this)
      @miniEditor.focus()
      @loadGists()
    else
      rootView.trigger('github:sign-in', [this])

  confirmed: (gist) ->
    @cancel()

    files = _.values(gist.files)
    if files.length is 1
      openGistFile(gist, files[0])
    else
      new GistFilesView(gist).toggle()
