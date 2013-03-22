UIView = require './ui-view'
UIControls = require './ui-controls'

module.exports =
  activate: (state) ->
    rootView.command "ui-kit:test", => @testUIKit()
  View: UIView
  Controls: UIControls
  testUIKit: () ->
    view = new UIView(position:"dialog")
    view.runModalDialog (result) ->
      window.console.log "Exited dialog #{result}"