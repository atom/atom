const fs = require('fs-plus')
const { CompositeDisposable } = require('atom')

let MarkdownPreviewView = null
let renderer = null

const isMarkdownPreviewView = function (object) {
  if (MarkdownPreviewView == null) {
    MarkdownPreviewView = require('./markdown-preview-view')
  }
  return object instanceof MarkdownPreviewView
}

module.exports = {
  activate () {
    this.disposables = new CompositeDisposable()
    this.commandSubscriptions = new CompositeDisposable()

    this.disposables.add(
      atom.config.observe('markdown-preview.grammars', grammars => {
        this.commandSubscriptions.dispose()
        this.commandSubscriptions = new CompositeDisposable()

        if (grammars == null) {
          grammars = []
        }

        for (const grammar of grammars.map(grammar =>
          grammar.replace(/\./g, ' ')
        )) {
          this.commandSubscriptions.add(
            atom.commands.add(`atom-text-editor[data-grammar='${grammar}']`, {
              'markdown-preview:toggle': () => this.toggle(),
              'markdown-preview:copy-html': {
                displayName: 'Markdown Preview: Copy HTML',
                didDispatch: () => this.copyHTML()
              },
              'markdown-preview:save-as-html': {
                displayName: 'Markdown Preview: Save as HTML',
                didDispatch: () => this.saveAsHTML()
              },
              'markdown-preview:toggle-break-on-single-newline': () => {
                const keyPath = 'markdown-preview.breakOnSingleNewline'
                atom.config.set(keyPath, !atom.config.get(keyPath))
              },
              'markdown-preview:toggle-github-style': () => {
                const keyPath = 'markdown-preview.useGitHubStyle'
                atom.config.set(keyPath, !atom.config.get(keyPath))
              }
            })
          )
        }
      })
    )

    const previewFile = this.previewFile.bind(this)
    for (const extension of [
      'markdown',
      'md',
      'mdown',
      'mkd',
      'mkdown',
      'ron',
      'txt'
    ]) {
      this.disposables.add(
        atom.commands.add(
          `.tree-view .file .name[data-name$=\\.${extension}]`,
          'markdown-preview:preview-file',
          previewFile
        )
      )
    }

    this.disposables.add(
      atom.workspace.addOpener(uriToOpen => {
        let [protocol, path] = uriToOpen.split('://')
        if (protocol !== 'markdown-preview') {
          return
        }

        try {
          path = decodeURI(path)
        } catch (error) {
          return
        }

        if (path.startsWith('editor/')) {
          return this.createMarkdownPreviewView({ editorId: path.substring(7) })
        } else {
          return this.createMarkdownPreviewView({ filePath: path })
        }
      })
    )
  },

  deactivate () {
    this.disposables.dispose()
    this.commandSubscriptions.dispose()
  },

  createMarkdownPreviewView (state) {
    if (state.editorId || fs.isFileSync(state.filePath)) {
      if (MarkdownPreviewView == null) {
        MarkdownPreviewView = require('./markdown-preview-view')
      }
      return new MarkdownPreviewView(state)
    }
  },

  toggle () {
    if (isMarkdownPreviewView(atom.workspace.getActivePaneItem())) {
      atom.workspace.destroyActivePaneItem()
      return
    }

    const editor = atom.workspace.getActiveTextEditor()
    if (editor == null) {
      return
    }

    const grammars = atom.config.get('markdown-preview.grammars') || []
    if (!grammars.includes(editor.getGrammar().scopeName)) {
      return
    }

    if (!this.removePreviewForEditor(editor)) {
      return this.addPreviewForEditor(editor)
    }
  },

  uriForEditor (editor) {
    return `markdown-preview://editor/${editor.id}`
  },

  removePreviewForEditor (editor) {
    const uri = this.uriForEditor(editor)
    const previewPane = atom.workspace.paneForURI(uri)
    if (previewPane != null) {
      previewPane.destroyItem(previewPane.itemForURI(uri))
      return true
    } else {
      return false
    }
  },

  addPreviewForEditor (editor) {
    const uri = this.uriForEditor(editor)
    const previousActivePane = atom.workspace.getActivePane()
    const options = { searchAllPanes: true }
    if (atom.config.get('markdown-preview.openPreviewInSplitPane')) {
      options.split = 'right'
    }

    return atom.workspace
      .open(uri, options)
      .then(function (markdownPreviewView) {
        if (isMarkdownPreviewView(markdownPreviewView)) {
          previousActivePane.activate()
        }
      })
  },

  previewFile ({ target }) {
    const filePath = target.dataset.path
    if (!filePath) {
      return
    }

    for (const editor of atom.workspace.getTextEditors()) {
      if (editor.getPath() === filePath) {
        return this.addPreviewForEditor(editor)
      }
    }

    atom.workspace.open(`markdown-preview://${encodeURI(filePath)}`, {
      searchAllPanes: true
    })
  },

  async copyHTML () {
    const editor = atom.workspace.getActiveTextEditor()
    if (editor == null) {
      return
    }

    if (renderer == null) {
      renderer = require('./renderer')
    }
    const text = editor.getSelectedText() || editor.getText()
    const html = await renderer.toHTML(
      text,
      editor.getPath(),
      editor.getGrammar()
    )

    atom.clipboard.write(html)
  },

  saveAsHTML () {
    const activePaneItem = atom.workspace.getActivePaneItem()
    if (isMarkdownPreviewView(activePaneItem)) {
      atom.workspace.getActivePane().saveItemAs(activePaneItem)
      return
    }

    const editor = atom.workspace.getActiveTextEditor()
    if (editor == null) {
      return
    }

    const grammars = atom.config.get('markdown-preview.grammars') || []
    if (!grammars.includes(editor.getGrammar().scopeName)) {
      return
    }

    const uri = this.uriForEditor(editor)
    const markdownPreviewPane = atom.workspace.paneForURI(uri)
    const markdownPreviewPaneItem =
      markdownPreviewPane != null
        ? markdownPreviewPane.itemForURI(uri)
        : undefined

    if (isMarkdownPreviewView(markdownPreviewPaneItem)) {
      return markdownPreviewPane.saveItemAs(markdownPreviewPaneItem)
    }
  }
}
