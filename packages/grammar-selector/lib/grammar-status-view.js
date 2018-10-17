const {Disposable} = require('atom')

module.exports =
class GrammarStatusView {
  constructor (statusBar) {
    this.statusBar = statusBar
    this.element = document.createElement('grammar-selector-status')
    this.element.classList.add('grammar-status', 'inline-block')
    this.grammarLink = document.createElement('a')
    this.grammarLink.classList.add('inline-block')
    this.element.appendChild(this.grammarLink)

    this.activeItemSubscription = atom.workspace.observeActiveTextEditor(this.subscribeToActiveTextEditor.bind(this))

    this.configSubscription = atom.config.observe('grammar-selector.showOnRightSideOfStatusBar', this.attach.bind(this))
    const clickHandler = (event) => {
      event.preventDefault()
      atom.commands.dispatch(atom.views.getView(atom.workspace.getActiveTextEditor()), 'grammar-selector:show')
    }
    this.element.addEventListener('click', clickHandler)
    this.clickSubscription = new Disposable(() => { this.element.removeEventListener('click', clickHandler) })
  }

  attach () {
    if (this.tile) {
      this.tile.destroy()
    }

    this.tile = atom.config.get('grammar-selector.showOnRightSideOfStatusBar')
      ? this.statusBar.addRightTile({item: this.element, priority: 10})
      : this.statusBar.addLeftTile({item: this.element, priority: 10})
  }

  destroy () {
    if (this.activeItemSubscription) {
      this.activeItemSubscription.dispose()
    }

    if (this.grammarSubscription) {
      this.grammarSubscription.dispose()
    }

    if (this.clickSubscription) {
      this.clickSubscription.dispose()
    }

    if (this.configSubscription) {
      this.configSubscription.dispose()
    }

    if (this.tile) {
      this.tile.destroy()
    }

    if (this.tooltip) {
      this.tooltip.dispose()
    }
  }

  subscribeToActiveTextEditor () {
    if (this.grammarSubscription) {
      this.grammarSubscription.dispose()
      this.grammarSubscription = null
    }

    const editor = atom.workspace.getActiveTextEditor()
    if (editor) {
      this.grammarSubscription = editor.onDidChangeGrammar(this.updateGrammarText.bind(this))
    }
    this.updateGrammarText()
  }

  updateGrammarText () {
    atom.views.updateDocument(() => {
      const editor = atom.workspace.getActiveTextEditor()
      const grammar = editor ? editor.getGrammar() : null

      if (this.tooltip) {
        this.tooltip.dispose()
        this.tooltip = null
      }

      if (grammar) {
        let grammarName = null
        if (grammar === atom.grammars.nullGrammar) {
          grammarName = 'Plain Text'
        } else {
          grammarName = grammar.name || grammar.scopeName
        }

        this.grammarLink.textContent = grammarName
        this.grammarLink.dataset.grammar = grammarName
        this.element.style.display = ''

        this.tooltip = atom.tooltips.add(this.element, {title: `File uses the ${grammarName} grammar`})
      } else {
        this.element.style.display = 'none'
      }
    })
  }
}
