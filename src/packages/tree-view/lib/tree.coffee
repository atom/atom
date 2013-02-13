module.exports =
  treeView: null

  activate: (@state) ->
    @createView() if @state.attached
    rootView.command 'tree-view:toggle', => @createView().toggle()
    rootView.command 'tree-view:reveal-active-file', => @createView().revealActiveFile()

  deactivate: ->
    @treeView?.deactivate()
    @treeView = null

  serialize: ->
    if @treeView?
      @treeView.serialize()
    else
      @state

  createView: ->
    unless @treeView?
      TreeView = require 'tree-view/lib/tree-view'
      @treeView = new TreeView(@state)
    @treeView
