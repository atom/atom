##PackageName##View = require '##package-name##/lib/##package-name##-view'

module.exports =
  ##packageName##View: null

  activate: (state) ->
    @##packageName##View = new ##PackageName##View(state.##packageName##ViewState)

  deactivate: ->
    @##packageName##View.destroy()

  serialize: ->
    ##packageName##ViewState: @##packageName##View.serialize()
