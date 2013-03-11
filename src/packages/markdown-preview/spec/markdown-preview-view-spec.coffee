MarkdownPreviewView = require 'markdown-preview/lib/markdown-preview-view'
$ = require 'jquery'
{$$$} = require 'space-pen'

describe "MarkdownPreviewView", ->
  [buffer, preview] = []

  beforeEach ->
    spyOn($, 'ajax')
    project.setPath(project.resolve('markdown'))
    buffer = project.bufferForPath('file.markdown')
    preview = new MarkdownPreviewView(buffer)

  afterEach ->
    buffer.release()

  describe "on construction", ->
    ajaxArgs = null

    beforeEach ->
      ajaxArgs = $.ajax.argsForCall[0][0]

    it "shows a loading spinner and fetches the rendered markdown", ->
      expect(preview.find('.markdown-spinner')).toExist()
      expect($.ajax).toHaveBeenCalled()

      expect(JSON.parse(ajaxArgs.data).text).toBe buffer.getText()

      ajaxArgs.success($$$ -> @div "WWII", class: 'private-ryan')
      expect(preview.find(".private-ryan")).toExist()

    it "shows an error message on error", ->
      ajaxArgs.error()
      expect(preview.text()).toContain "Failed"

  describe "serialization", ->
    it "reassociates with the same buffer when deserialized", ->
      newPreview = deserialize(preview.serialize())
      expect(newPreview.buffer).toBe buffer
