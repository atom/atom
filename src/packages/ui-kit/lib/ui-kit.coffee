UIView = require './ui-view'
UIControls = require './ui-controls'
UILayout = require './ui-layout'

UIKit =
  activate: (state) ->
    rootView.command "ui-kit:test", => @testUIKit()
  View: UIView
  Controls: UIControls
  Layout: UILayout
  testUIKit: () ->
    view = new UIView(position:"dialog")
    layout = new UIKit.Layout ->
      @row =>
        @column =>
          @text "Enter something here:"
        @column =>
          @textField()
      @row =>
        @column align:"right", =>
          @button(title:"Save")
    view.setTitle("Dialog Test")
    view.addSubview(layout.content)
    view.runModalDialog (result) ->
UILayout.UI = UIKit
module.exports = UIKit