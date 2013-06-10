module.exports =
  gistsView: null
  gistsCreator: null

  activate: ->
    rootView.command 'gists:view', => @toggleView()
    rootView.command 'gist:create', '.editor', => @createGist()

  createGist: ->
    unless @gistsCreator
      CreateGist = require './create-gist'
      @gistsCreator = new CreateGist()

    @gistsCreator.createGist()

  toggleView: ->
    unless @gistsView?
      GistsView = require './gists-view'
      @gistsView = new GistsView()

    @gistsView.toggle()
