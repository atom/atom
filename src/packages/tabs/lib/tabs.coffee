TabBarView = require './tab-bar-view'

module.exports =
  activate: ->
    rootView.eachPane (pane) => new TabBarView(pane)
