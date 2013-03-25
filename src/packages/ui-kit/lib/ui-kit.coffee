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
  prompt: (text, callback, title="Prompt") ->
    view = new UIView(position:"dialog")
    layout = new UIKit.Layout ->
      @row =>
        @column =>
          @text text
      @row =>
        @column =>
          @textField()
      @row =>
        @column align:"right", =>
          @button title:"Cancel", cancel:true, action:() -> @parentView.close(false)
          @button title:"OK", default:true, action:() -> @parentView.close(true)
    view.setTitle(title)
    view.addSubview(layout)
    view.runModalDialog (result) ->
      callback?(if result == false then result else view.find(".ui-control.text-field input").val())
    view.find(".ui-control.text-field").focus()
    view
  testUIKit: () ->
    UIKit.alert "Something terrible has happend!"
    # UIKit.prompt "Question the user should answer", (result) =>
UILayout.UI = UIKit
module.exports = UIKit