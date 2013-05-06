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

    {previewPane, previewItem} = @getExistingPreview(editSession)
    if previewItem?
      previewPane.showItem(previewItem)
      previewItem.renderMarkdown()
    else if nextPane = activePane.getNextPane()
      nextPane.showItem(new MarkdownPreviewView(editSession.buffer))
    else
      activePane.splitRight(new MarkdownPreviewView(editSession.buffer))
    activePane.focus()

  getExistingPreview: (editSession) ->
    uri = "markdown-preview:#{editSession.getPath()}"
    for previewPane in rootView.getPanes()
      previewItem = previewPane.itemForUri(uri)
      return {previewPane, previewItem} if previewItem?
    {}
