$ = require 'jquery'
RootView = require 'root-view'
MarkdownPreview = require 'markdown-preview/src/markdown-preview-view'

describe "MarkdownPreview", ->
  [rootView, markdownPreview] = []

  beforeEach ->
    rootView = new RootView(require.resolve('fixtures/markdown'))
    atom.loadPackage("markdown-preview").getInstance()
    markdownPreview = MarkdownPreview.instance

  afterEach ->
    rootView.deactivate()

  describe "markdown-preview:toggle event", ->
    it "toggles on/off a preview for a .md file", ->
      rootView.open('file.md')
      editor = rootView.getActiveEditor()
      expect(rootView.find('.markdown-preview')).not.toExist()
      spyOn(markdownPreview, 'loadHtml')
      editor.trigger('markdown-preview:toggle')

      markdownPreviewView = rootView.find('.markdown-preview')?.view()
      expect(rootView.find('.markdown-preview')).toExist()
      expect(markdownPreview.loadHtml).toHaveBeenCalled();
      markdownPreviewView.trigger('markdown-preview:toggle')
      expect(rootView.find('.markdown-preview')).not.toExist()

    it "displays a preview for a .markdown file", ->
      rootView.open('file.markdown')
      editor = rootView.getActiveEditor()
      expect(rootView.find('.markdown-preview')).not.toExist()
      spyOn(markdownPreview, 'loadHtml')
      editor.trigger('markdown-preview:toggle')
      expect(rootView.find('.markdown-preview')).toExist()
      expect(markdownPreview.loadHtml).toHaveBeenCalled();

    it "does not display a preview for non-markdown file", ->
      rootView.open('file.js')
      editor = rootView.getActiveEditor()
      expect(rootView.find('.markdown-preview')).not.toExist()
      spyOn(markdownPreview, 'loadHtml')
      editor.trigger('markdown-preview:toggle')
      expect(rootView.find('.markdown-preview')).not.toExist()
      expect(markdownPreview.loadHtml).not.toHaveBeenCalled();

   describe "core:cancel event", ->
     it "removes markdown preview", ->
       rootView.open('file.md')
       editor = rootView.getActiveEditor()
       expect(rootView.find('.markdown-preview')).not.toExist()
       spyOn(markdownPreview, 'loadHtml')
       editor.trigger('markdown-preview:toggle')

       markdownPreviewView = rootView.find('.markdown-preview')?.view()
       expect(markdownPreviewView).toExist()
       markdownPreviewView.trigger('core:cancel')
       expect(rootView.find('.markdown-preview')).not.toExist()
