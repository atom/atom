$ = require 'jquery'
RootView = require 'root-view'
MarkdownPreview = require 'markdown-preview/lib/markdown-preview-view'
_ = require 'underscore'

describe "MarkdownPreview", ->
  beforeEach ->
    project.setPath(project.resolve('markdown'))
    rootView = new RootView(project.getPath())
    window.loadPackage("markdown-preview")
    spyOn(MarkdownPreview.prototype, 'loadHtml')

  afterEach ->
    rootView.deactivate()

  describe "markdown-preview:toggle event", ->
    it "toggles on/off a preview for a .md file", ->
      rootView.open('file.md')
      editor = rootView.getActiveEditor()
      expect(rootView.find('.markdown-preview')).not.toExist()
      editor.trigger('markdown-preview:toggle')

      markdownPreviewView = rootView.find('.markdown-preview')?.view()
      expect(rootView.find('.markdown-preview')).toExist()
      expect(markdownPreviewView.loadHtml).toHaveBeenCalled()
      markdownPreviewView.trigger('markdown-preview:toggle')
      expect(rootView.find('.markdown-preview')).not.toExist()

    it "displays a preview for a .markdown file", ->
      rootView.open('file.markdown')
      editor = rootView.getActiveEditor()
      expect(rootView.find('.markdown-preview')).not.toExist()
      editor.trigger('markdown-preview:toggle')
      expect(rootView.find('.markdown-preview')).toExist()
      markdownPreviewView = rootView.find('.markdown-preview')?.view()
      expect(markdownPreviewView.loadHtml).toHaveBeenCalled()

    it "displays a preview for a file with the source.gfm grammar scope", ->
      gfmGrammar = _.find syntax.grammars, (grammar) -> grammar.scopeName is 'source.gfm'
      rootView.open('file.js')
      editor = rootView.getActiveEditor()
      project.addGrammarOverrideForPath(editor.getPath(), gfmGrammar)
      editor.reloadGrammar()
      expect(rootView.find('.markdown-preview')).not.toExist()
      editor.trigger('markdown-preview:toggle')
      expect(rootView.find('.markdown-preview')).toExist()
      markdownPreviewView = rootView.find('.markdown-preview')?.view()
      expect(markdownPreviewView.loadHtml).toHaveBeenCalled()

    it "does not display a preview for non-markdown file", ->
      rootView.open('file.js')
      editor = rootView.getActiveEditor()
      expect(rootView.find('.markdown-preview')).not.toExist()
      editor.trigger('markdown-preview:toggle')
      expect(rootView.find('.markdown-preview')).not.toExist()
      expect(MarkdownPreview.prototype.loadHtml).not.toHaveBeenCalled()

   describe "core:cancel event", ->
     it "removes markdown preview", ->
       rootView.open('file.md')
       editor = rootView.getActiveEditor()
       expect(rootView.find('.markdown-preview')).not.toExist()
       editor.trigger('markdown-preview:toggle')

       markdownPreviewView = rootView.find('.markdown-preview')?.view()
       expect(markdownPreviewView).toExist()
       markdownPreviewView.trigger('core:cancel')
       expect(rootView.find('.markdown-preview')).not.toExist()

   describe "when the editor receives focus", ->
     it "removes the markdown preview view", ->
       rootView.attachToDom()
       rootView.open('file.md')
       editor = rootView.getActiveEditor()
       expect(rootView.find('.markdown-preview')).not.toExist()
       editor.trigger('markdown-preview:toggle')

       markdownPreviewView = rootView.find('.markdown-preview')
       editor.focus()
       expect(markdownPreviewView).toExist()
       expect(rootView.find('.markdown-preview')).not.toExist()

   describe "when no editor is open", ->
     it "does not attach", ->
       expect(rootView.getActiveEditor()).toBeFalsy()
       rootView.trigger('markdown-preview:toggle')
       expect(rootView.find('.markdown-preview')).not.toExist()
