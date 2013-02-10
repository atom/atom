module.exports =
  treeView: null

  activate: (@state) ->
    if state
      @createView().attach() if state.attached
    else if rootView.project.getPath() and not rootView.pathToOpenIsFile
      @createView().attach()

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
      @treeView = TreeView.activate(@state)
    @treeView
