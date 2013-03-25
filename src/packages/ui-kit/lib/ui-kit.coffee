UIView = require './ui-view'
UIControls = require './ui-controls'
UILayout = require './ui-layout'

UIKit =
  activate: (state) ->
    rootView.command "ui-kit:test", => @testUIKit()
  View: UIView
  Controls: UIControls
  Layout: UILayout
  alert: (text, title="Alert") ->
    view = new UIView(position:"dialog")
    layout = new UIKit.Layout ->
      @row =>
        @column =>
          @text text
      @row =>
        @column align:"right", =>
          @button title:"OK", default:true, action:() -> @parentView.close()
    view.setTitle(title)
    view.addSubview(layout)
    view.runModalDialog (result) ->
    view
  testUIKit: () ->
    UIKit.alert("Foo")
    return
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
    view.addSubview(layout)
    view.runModalDialog (result) ->
UILayout.UI = UIKit
module.exports = UIKit