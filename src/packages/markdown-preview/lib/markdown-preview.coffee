EditSession = require 'edit-session'
MarkdownPreviewView = require './markdown-preview-view'

module.exports =
  activate: ->
    rootView.command 'markdown-preview:show', '.editor', => @show()

  show: ->
    activePane = rootView.getActivePane()
    editSession = activePane.activeItem

    isEditSession = editSession instanceof EditSession
    hasMarkdownGrammar = editSession.getGrammar().scopeName == "source.gfm"
    if not isEditSession or not hasMarkdownGrammar
      console.warn("Can not render markdown for '#{editSession.getUri() ? 'untitled'}'")
      return

    if nextPane = activePane.getNextPane()
      if preview = nextPane.itemForUri("markdown-preview:#{editSession.getPath()}")
        nextPane.showItem(preview)
        preview.fetchRenderedMarkdown()
      else
        nextPane.showItem(new MarkdownPreviewView(editSession.buffer))
    else
      activePane.splitRight(new MarkdownPreviewView(editSession.buffer))
    activePane.focus()
