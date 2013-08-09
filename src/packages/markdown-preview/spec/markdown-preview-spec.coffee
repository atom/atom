RootView = require 'root-view'
MarkdownPreviewView = require 'markdown-preview/lib/markdown-preview-view'
{$$} = require 'space-pen'

describe "MarkdownPreview package", ->
  beforeEach ->
    atom.activatePackage('gfm')
    project.setPath(project.resolve('markdown'))
    window.rootView = new RootView
    atom.activatePackage("markdown-preview", immediate: true)
    spyOn(MarkdownPreviewView.prototype, 'renderMarkdown')

  describe "markdown-preview:show", ->
    beforeEach ->
      rootView.open("file.markdown")

    describe "when the active item is an edit session", ->
      beforeEach ->
        rootView.attachToDom()

      describe "when the edit session does not use the GFM grammar", ->
        it "does not show a markdown preview", ->
          spyOn(console, 'warn')
          rootView.open()
          expect(rootView.getPanes()).toHaveLength(1)
          rootView.getActiveView().trigger 'markdown-preview:show'
          expect(rootView.getPanes()).toHaveLength(1)
          expect(console.warn).toHaveBeenCalled()

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

        describe "when a buffer is saved", ->
          it "does not show the markdown preview", ->
            [pane] = rootView.getPanes()
            pane.focus()

            MarkdownPreviewView.prototype.renderMarkdown.reset()
            pane.activeItem.buffer.trigger 'saved'
            expect(MarkdownPreviewView.prototype.renderMarkdown).not.toHaveBeenCalled()

        describe "when a buffer is reloaded", ->
          it "does not show the markdown preview", ->
            [pane] = rootView.getPanes()
            pane.focus()

            MarkdownPreviewView.prototype.renderMarkdown.reset()
            pane.activeItem.buffer.trigger 'reloaded'
            expect(MarkdownPreviewView.prototype.renderMarkdown).not.toHaveBeenCalled()

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

          preview.renderMarkdown.reset()
          rootView.getActiveView().trigger 'markdown-preview:show'
          expect(preview.renderMarkdown).toHaveBeenCalled()
          expect(rootView.getPanes()).toHaveLength 2
          expect(pane2.getItems()).toHaveLength 2
          expect(pane2.activeItem).toBe preview
          expect(pane1).toMatchSelector(':has(:focus)')

        describe "when a buffer is saved", ->
          describe "when the preview is in the same pane", ->
            it "updates the preview but does not make it active", ->
              rootView.getActiveView().trigger 'markdown-preview:show'
              [pane1, pane2] = rootView.getPanes()
              pane2.moveItemToPane(pane2.activeItem, pane1, 1)
              pane1.showItemAtIndex(1)
              pane1.showItemAtIndex(0)
              preview = pane1.itemAtIndex(1)

              preview.renderMarkdown.reset()
              pane1.activeItem.buffer.trigger 'saved'
              expect(preview.renderMarkdown).toHaveBeenCalled()
              expect(pane1.activeItem).not.toBe preview

          describe "when the preview is not in the same pane", ->
            it "updates the preview and makes it active", ->
              rootView.getActiveView().trigger 'markdown-preview:show'
              [pane1, pane2] = rootView.getPanes()
              preview = pane2.activeItem
              pane2.showItem($$ -> @div id: 'view', tabindex: -1, 'View')
              expect(pane2.activeItem).not.toBe preview
              pane1.focus()

              preview.renderMarkdown.reset()
              pane1.activeItem.buffer.trigger 'saved'
              expect(preview.renderMarkdown).toHaveBeenCalled()
              expect(pane2.activeItem).toBe preview

      describe "when a new grammar is loaded", ->
        it "reloads the view to colorize any fenced code blocks matching the newly loaded grammar", ->
          rootView.getActiveView().trigger 'markdown-preview:show'
          [pane1, pane2] = rootView.getPanes()
          preview = pane2.activeItem
          preview.renderMarkdown.reset()
          jasmine.unspy(window, 'setTimeout')

          atom.activatePackage('javascript-tmbundle', sync: true)
          waitsFor -> preview.renderMarkdown.callCount > 0
