{$$} = require 'space-pen'
SelectList = require 'select-list'
path = require 'path'
fsUtils = require 'fs-utils'
GitHub = require 'github'
keytar = require 'keytar'
_ = require 'underscore'
humanize = require 'humanize-plus'
{openGistFile} = require './gist-utils'
GistFilesView = require './gist-files-view'

module.exports =
class GistsView extends SelectList
  @viewClass: -> "#{super} gists-view overlay from-top"

  filterKey: 'filterText'

  loadGists: ->
    if @gists?
      @setArray(@gists)
      return

    @setLoading('Loading Gists\u2026')

    if token = require('keytar').getPassword('github.com', 'github')
      client = new GitHub(version: '3.0.0')
      client.authenticate({type: 'oauth', token})
      allGists = []
      done = (error, gists) =>
        if error?
          @setError("Error fetching Gists")
          console.error("Error fetching Gists", error.stack ? error)
        else
          @gists = gists
          @setArray(@gists)
      getNextPage = (error, gists) =>
        if error?
          done(error)
        else
          for gist in gists
            gist.filterText = @getFilterText(gist)
            allGists.push(gist)
          @loadingBadge.text(humanize.intcomma(allGists.length))
          if client.hasNextPage(gists)
            client.getNextPage(gists, getNextPage)
          else
            done(null, allGists)
      client.gists.getAll(per_page: 100, getNextPage)

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

  attach: ->
    super

    rootView.append(this)
    @miniEditor.focus()
    @loadGists()

  confirmed: (gist) ->
    @cancel()

    files = _.values(gist.files)
    if files.length is 1
      openGistFile(gist, files[0])
    else
      new GistFilesView(gist).toggle()
