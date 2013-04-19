MarkdownPreviewView = require 'markdown-preview/lib/markdown-preview-view'
$ = require 'jquery'
{$$$} = require 'space-pen'

describe "MarkdownPreviewView", ->
  [buffer, preview] = []

  beforeEach ->
    project.setPath(project.resolve('markdown'))
    buffer = project.bufferForPath('file.markdown')
    preview = new MarkdownPreviewView(buffer)

  afterEach ->
    buffer.release()

  describe "on construction", ->

    it "shows a loading spinner and fetches the rendered markdown", ->
      preview.setLoading()
      expect(preview.find('.markdown-spinner')).toExist()
      expect(preview.buffer.getText()).toBe buffer.getText()

      preview.fetchRenderedMarkdown()
      expect(preview.find(".emoji")).toExist()

    it "shows an error message on error", ->
      preview.setErrorHtml("Not a real file")
      expect(preview.text()).toContain "Failed"

  describe "serialization", ->
    it "reassociates with the same buffer when deserialized", ->
      newPreview = deserialize(preview.serialize())
      expect(newPreview.buffer).toBe buffer
