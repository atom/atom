RootView = require 'root-view'
MarkdownPreviewView = require 'markdown-preview/lib/markdown-preview-view'
{$$} = require 'space-pen'

describe "MarkdownPreview package", ->
  beforeEach ->
    project.setPath(project.resolve('markdown'))
    window.rootView = new RootView
    window.loadPackage("markdown-preview", activateImmediately: true)
    spyOn(MarkdownPreviewView.prototype, 'fetchRenderedMarkdown')

  describe "markdown-preview:show", ->
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

          preview.fetchRenderedMarkdown.reset()
          rootView.getActiveView().trigger 'markdown-preview:show'
          expect(preview.fetchRenderedMarkdown).toHaveBeenCalled()
          expect(rootView.getPanes()).toHaveLength 2
          expect(pane2.getItems()).toHaveLength 2
          expect(pane2.activeItem).toBe preview
          expect(pane1).toMatchSelector(':has(:focus)')
