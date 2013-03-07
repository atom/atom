$ = require 'jquery'
RootView = require 'root-view'
MarkdownPreviewView = require 'markdown-preview/lib/markdown-preview-view'
_ = require 'underscore'

describe "MarkdownPreviewView", ->
  beforeEach ->
    project.setPath(project.resolve('markdown'))
    window.rootView = new RootView
    window.loadPackage("markdown-preview")
    spyOn(MarkdownPreviewView.prototype, 'loadHtml')

  fdescribe "markdown-preview:show", ->
    beforeEach ->
      rootView.open("file.markdown")

    describe "when the active item is an edit session", ->
      beforeEach ->
        rootView.attachToDom()

      describe "when a preview item has not been created for the edit session's uri", ->
        describe "when there is more than one pane", ->
          it "shows a markdown preview for the current buffer on the next pane", ->
            rootView.getActivePane().splitRight()
            [pane1, pane2] = rootView.getPanes()
            pane1.focus()

            rootView.getActiveView().trigger 'markdown-preview:show'

            preview = pane2.activeItem
            expect(preview).toBeInstanceOf(MarkdownPreviewView)
            expect(preview.buffer).toBe rootView.getActivePaneItem().buffer
            expect(pane1).toMatchSelector(':has(:focus)')

        describe "when there is only one pane", ->
          it "splits the current pane to the right with a markdown preview for the current buffer", ->
            expect(rootView.getPanes()).toHaveLength 1

            rootView.getActiveView().trigger 'markdown-preview:show'

            expect(rootView.getPanes()).toHaveLength 2
            [pane1, pane2] = rootView.getPanes()

            expect(pane2.items).toHaveLength 1
            preview = pane2.activeItem
            expect(preview).toBeInstanceOf(MarkdownPreviewView)
            expect(preview.buffer).toBe rootView.getActivePaneItem().buffer
            expect(pane1).toMatchSelector(':has(:focus)')

      describe "when a preview item has already been created for the edit session's uri", ->
        it "updates and shows the existing preview item if it isn't displayed", ->
          rootView.getActiveView().trigger 'markdown-preview:show'
          [pane1, pane2] = rootView.getPanes()
          pane2.focus()
          expect(rootView.getActivePane()).toBe pane2
          preview = pane2.activeItem
          expect(preview).toBeInstanceOf(MarkdownPreviewView)
          rootView.open()
          expect(pane2.activeItem).not.toBe preview
          pane1.focus()

          rootView.getActiveView().trigger 'markdown-preview:show'
          expect(rootView.getPanes()).toHaveLength 2
          expect(pane2.getItems()).toHaveLength 2
          expect(pane2.activeItem).toBe preview
          expect(pane1).toMatchSelector(':has(:focus)')

    describe "when the active item is not an edit session ", ->
      it "logs a warning to the console saying that it isn't possible to preview the item", ->

  describe "markdown-preview:toggle event", ->
    it "toggles on/off a preview for a .md file", ->
      rootView.open('file.md')
      editor = rootView.getActiveView()
      expect(rootView.find('.markdown-preview')).not.toExist()
      editor.trigger('markdown-preview:toggle')

      markdownPreviewView = rootView.find('.markdown-preview')?.view()
      expect(rootView.find('.markdown-preview')).toExist()
      expect(markdownPreviewView.loadHtml).toHaveBeenCalled()
      markdownPreviewView.trigger('markdown-preview:toggle')
      expect(rootView.find('.markdown-preview')).not.toExist()

    it "displays a preview for a .markdown file", ->
      rootView.open('file.markdown')
      editor = rootView.getActiveView()
      expect(rootView.find('.markdown-preview')).not.toExist()
      editor.trigger('markdown-preview:toggle')
      expect(rootView.find('.markdown-preview')).toExist()
      markdownPreviewView = rootView.find('.markdown-preview')?.view()
      expect(markdownPreviewView.loadHtml).toHaveBeenCalled()

    it "displays a preview for a file with the source.gfm grammar scope", ->
      gfmGrammar = _.find syntax.grammars, (grammar) -> grammar.scopeName is 'source.gfm'
      rootView.open('file.js')
      editor = rootView.getActiveView()
      project.addGrammarOverrideForPath(editor.getPath(), gfmGrammar)
      editor.reloadGrammar()
      expect(rootView.find('.markdown-preview')).not.toExist()
      editor.trigger('markdown-preview:toggle')
      expect(rootView.find('.markdown-preview')).toExist()
      markdownPreviewView = rootView.find('.markdown-preview')?.view()
      expect(markdownPreviewView.loadHtml).toHaveBeenCalled()

    it "does not display a preview for non-markdown file", ->
      rootView.open('file.js')
      editor = rootView.getActiveView()
      expect(rootView.find('.markdown-preview')).not.toExist()
      editor.trigger('markdown-preview:toggle')
      expect(rootView.find('.markdown-preview')).not.toExist()
      expect(MarkdownPreviewView.prototype.loadHtml).not.toHaveBeenCalled()

  describe "core:cancel event", ->
   it "removes markdown preview", ->
     rootView.open('file.md')
     editor = rootView.getActiveView()
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
     editor = rootView.getActiveView()
     expect(rootView.find('.markdown-preview')).not.toExist()
     editor.trigger('markdown-preview:toggle')

     markdownPreviewView = rootView.find('.markdown-preview')
     editor.focus()
     expect(markdownPreviewView).toExist()
     expect(rootView.find('.markdown-preview')).not.toExist()

  describe "when no editor is open", ->
   it "does not attach", ->
     expect(rootView.getActiveView()).toBeFalsy()
     rootView.trigger('markdown-preview:toggle')
     expect(rootView.find('.markdown-preview')).not.toExist()
