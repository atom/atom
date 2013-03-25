EditSession = require 'edit-session'
MarkdownPreviewView = require 'markdown-preview/lib/markdown-preview-view'

module.exports =
  activate: ->
    rootView.command 'markdown-preview:show', '.editor', => @show()
    rootView.on 'core:save', ".pane", => @show()

  show: ->
    activePane = rootView.getActivePane()
    item = activePane.activeItem

    if not item instanceof EditSession
      console.warn("Can not render markdown for #{item.getUri()}")
      return

    editSession = item
    return unless editSession.getGrammar().scopeName == "source.gfm"

    if nextPane = activePane.getNextPane()
      if preview = nextPane.itemForUri("markdown-preview:#{editSession.getPath()}")
        nextPane.showItem(preview)
        preview.fetchRenderedMarkdown()
      else
        nextPane.showItem(new MarkdownPreviewView(editSession.buffer))
    else
      activePane.splitRight(new MarkdownPreviewView(editSession.buffer))
    activePane.focus()
