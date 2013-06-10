{$$} = require 'space-pen'
SelectList = require 'select-list'
GitHub = require 'github'
keytar = require 'keytar'
_ = require 'underscore'
humanize = require 'humanize-plus'

module.exports =
class GistsView extends SelectList
  @activate: -> new GistsView

  @viewClass: -> "#{super} gists-view overlay from-top"

  filterKey: 'filterText'

  initialize: ->
    super

    rootView.command 'gists:view', => @toggle()

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
          console.error("Error fetching gists", error.stack ? error)
        else
          @gists = gists
          @setArray(@gists)
      getNextPage = (error, gists) =>
        if error?
          done(error)
        else
          for gist in gists
            gist.filterText = "#{gist.id} #{@getDescription(gist)}"
            allGists.push(gist)
          @loadingBadge.text(humanize.intcomma(allGists.length))
          if client.hasNextPage(gists)
            client.getNextPage(gists, getNextPage)
          else
            done(null, allGists)
      client.gists.getAll(per_page: 100, getNextPage)

  getDescription: ({description, files}) ->
    if description
      description
    else
      filenames = []
      filenames.push(name) for name, value of files ? {}
      filenames.join(', ')

  itemForElement: (gist) ->
    description = @getDescription(gist)
    $$ ->
      @li class: 'two-lines', =>
        @div "Gist #{gist.id}", class: 'primary-line'
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
