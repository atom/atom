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

        if (isTreeSitter(grammar)) {
          const parser = document.createElement('span');
          parser.classList.add(
            'grammar-selector-parser',
            'badge',
            'badge-success'
          );
          parser.textContent = 'Tree-sitter';
          parser.setAttribute(
            'title',
            '(Recommended) A faster parser with improved syntax highlighting & code navigation support.'
          );
          div.appendChild(parser);
        }

        if (grammar.scopeName) {
          const scopeName = document.createElement('scopeName');
          scopeName.classList.add('badge', 'badge-info');
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
          atom.grammars.assignGrammar(this.editor, grammar);
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
      return;
    }

    const editor = atom.workspace.getActiveTextEditor();
    if (editor) {
      this.editor = editor;
      this.currentGrammar = this.editor.getGrammar();
      if (this.currentGrammar === atom.grammars.nullGrammar) {
        this.currentGrammar = this.autoDetect;
      }

      let grammars = atom.grammars
        .getGrammars({ includeTreeSitter: true })
        .filter(grammar => {
          return grammar !== atom.grammars.nullGrammar && grammar.name;
        });

      if (atom.config.get('grammar-selector.hideDuplicateTextMateGrammars')) {
        const blacklist = new Set();
        grammars.forEach(grammar => {
          if (isTreeSitter(grammar)) {
            blacklist.add(grammar.name);
          }
        });
        grammars = grammars.filter(
          grammar => isTreeSitter(grammar) || !blacklist.has(grammar.name)
        );
      }

      grammars.sort((a, b) => {
        if (a.scopeName === 'text.plain') {
          return -1;
        } else if (b.scopeName === 'text.plain') {
          return 1;
        } else if (a.name === b.name) {
          return compareGrammarType(a, b);
        }
        return a.name.localeCompare(b.name);
      });
      grammars.unshift(this.autoDetect);
      await this.selectListView.update({ items: grammars });
      this.attach();
    }
  }
};

function isTreeSitter(grammar) {
  return grammar.constructor.name === 'TreeSitterGrammar';
}

function compareGrammarType(a, b) {
  if (isTreeSitter(a)) {
    return -1;
  } else if (isTreeSitter(b)) {
    return 1;
  }
  return 0;
}
