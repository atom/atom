IndicoView = require './indico-view'

module.exports =
  indicoView: null

  activate: (state) ->
    @indicoView = new IndicoView(state.indicoViewState)

  deactivate: ->
    @indicoView.destroy()

  serialize: ->
    indicoViewState: @indicoView.serialize()
