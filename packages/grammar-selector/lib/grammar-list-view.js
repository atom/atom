const SelectListView = require('atom-select-list');

module.exports = class GrammarListView {
  constructor() {
    this.autoDetect = { name: 'Auto Detect' };
    this.selectListView = new SelectListView({
      itemsClassList: ['mark-active'],
      items: [],
      filterKeyForItem: grammar => grammar.name,
      elementForItem: grammar => {
        const grammarName = grammar.name || grammar.scopeName;
        const element = document.createElement('li');
        if (grammar === this.currentGrammar) {
          element.classList.add('active');
        }
        element.textContent = grammarName;
        element.dataset.grammar = grammarName;

        const div = document.createElement('div');
        div.classList.add('pull-right');
        if (grammar.scopeName) {
          const scopeName = document.createElement('scopeName');
          scopeName.classList.add('key-binding'); // It will be styled the same as the keybindings in the command palette
          scopeName.textContent = grammar.scopeName;
          div.appendChild(scopeName);
          element.appendChild(div);
        }

        return element;
      },
      didConfirmSelection: grammar => {
        this.cancel();
        if (grammar === this.autoDetect) {
          atom.textEditors.clearGrammarOverride(this.editor);
        } else {
          atom.textEditors.setGrammarOverride(this.editor, grammar.scopeName);
        }
      },
      didCancelSelection: () => {
        this.cancel();
      }
    });
    this.selectListView.element.classList.add('grammar-selector');
  }

  destroy() {
    this.cancel();
    return this.selectListView.destroy();
  }

  cancel() {
    if (this.panel != null) {
      this.panel.destroy();
    }
    this.panel = null;
    this.currentGrammar = null;
    if (this.previouslyFocusedElement) {
      this.previouslyFocusedElement.focus();
      this.previouslyFocusedElement = null;
    }
  }

  attach() {
    this.previouslyFocusedElement = document.activeElement;
    if (this.panel == null) {
      this.panel = atom.workspace.addModalPanel({ item: this.selectListView });
    }
    this.selectListView.focus();
    this.selectListView.reset();
  }

  async toggle() {
    if (this.panel != null) {
      this.cancel();
    } else if (atom.workspace.getActiveTextEditor()) {
      this.editor = atom.workspace.getActiveTextEditor();
      this.currentGrammar = this.editor.getGrammar();
      if (this.currentGrammar === atom.grammars.nullGrammar) {
        this.currentGrammar = this.autoDetect;
      }

      const grammars = atom.grammars.getGrammars().filter(grammar => {
        return grammar !== atom.grammars.nullGrammar && grammar.name;
      });
      grammars.sort((a, b) => {
        if (a.scopeName === 'text.plain') {
          return -1;
        } else if (b.scopeName === 'text.plain') {
          return 1;
        } else if (a.name) {
          return a.name.localeCompare(b.name);
        } else if (a.scopeName) {
          return a.scopeName.localeCompare(b.scopeName);
        } else {
          return 1;
        }
      });
      grammars.unshift(this.autoDetect);
      await this.selectListView.update({ items: grammars });
      this.attach();
    }
  }
};
