$ = require 'jquery'
RootView = require 'root-view'
MarkdownPreview = require 'markdown-preview'

describe "MarkdownPreview", ->
  [rootView, markdownPreview] = []

  beforeEach ->
    rootView = new RootView(require.resolve('fixtures/markdown'))
    rootView.activateExtension(MarkdownPreview)
    markdownPreview = MarkdownPreview.instance
    rootView.attachToDom()

  afterEach ->
    rootView.deactivate()

  describe "@attach", ->
    it "attaches to a .md file", ->
      rootView.open('file.md')
      editor = rootView.getActiveEditor()
      expect(rootView.find('.markdown-preview')).not.toExist()
      spyOn(markdownPreview, 'loadHtml')
      editor.trigger('markdown-preview:attach')
      expect(rootView.find('.markdown-preview')).toExist()
      expect(markdownPreview.loadHtml).toHaveBeenCalled();

    it "attaches to a .markdown file", ->
      rootView.open('file.markdown')
      editor = rootView.getActiveEditor()
      expect(rootView.find('.markdown-preview')).not.toExist()
      spyOn(markdownPreview, 'loadHtml')
      editor.trigger('markdown-preview:attach')
      expect(rootView.find('.markdown-preview')).toExist()
      expect(markdownPreview.loadHtml).toHaveBeenCalled();

    it "doesn't attach to a .js file", ->
      rootView.open('file.js')
      editor = rootView.getActiveEditor()
      expect(rootView.find('.markdown-preview')).not.toExist()
      spyOn(markdownPreview, 'loadHtml')
      editor.trigger('markdown-preview:attach')
      expect(rootView.find('.markdown-preview')).not.toExist()
      expect(markdownPreview.loadHtml).not.toHaveBeenCalled();

   describe "@detach", ->
     it "detaches from a .md file", ->
       rootView.open('file.md')
       editor = rootView.getActiveEditor()
       expect(rootView.find('.markdown-preview')).not.toExist()
       spyOn(markdownPreview, 'loadHtml')
       editor.trigger('markdown-preview:attach')
       expect(rootView.find('.markdown-preview')).toExist()
       markdownPreview.trigger('markdown-preview:detach')
       expect(rootView.find('.markdown-preview')).not.toExist()
