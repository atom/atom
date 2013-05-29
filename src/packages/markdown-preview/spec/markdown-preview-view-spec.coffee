MarkdownPreviewView = require 'markdown-preview/lib/markdown-preview-view'
$ = require 'jquery'
{$$$} = require 'space-pen'

describe "MarkdownPreviewView", ->
  [buffer, preview] = []

  beforeEach ->
    project.setPath(project.resolve('markdown'))
    buffer = project.bufferForPath('file.markdown')
    atom.activatePackage('ruby-tmbundle', sync: true)
    preview = new MarkdownPreviewView(buffer)

  afterEach ->
    buffer.release()

  describe "on construction", ->

    it "shows a loading spinner and renders the markdown", ->
      preview.setLoading()
      expect(preview.find('.markdown-spinner')).toExist()
      expect(preview.buffer.getText()).toBe buffer.getText()

      preview.renderMarkdown()
      expect(preview.find(".emoji")).toExist()

    it "shows an error message on error", ->
      preview.setErrorHtml("Not a real file")
      expect(preview.text()).toContain "Failed"

  describe "serialization", ->
    it "reassociates with the same buffer when deserialized", ->
      newPreview = deserialize(preview.serialize())
      expect(newPreview.buffer).toBe buffer

  describe "code block tokenization", ->
    describe "when the code block's fence name has a matching grammar", ->
      it "tokenizes the code block with the grammar", ->
        expect(preview.find("pre span.entity.name.function.ruby")).toExist()

    describe "when the code block's fence name doesn't have a matching grammar", ->
      it "does not tokenize the code block", ->
        expect(preview.find("pre code:not([class])").children().length).toBe 0
        expect(preview.find("pre code.lang-kombucha").children().length).toBe 0
