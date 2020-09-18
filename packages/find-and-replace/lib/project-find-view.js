const fs = require('fs-plus');
const path = require('path');
const _ = require('underscore-plus');
const { TextEditor, Disposable, CompositeDisposable } = require('atom');
const etch = require('etch');
const Util = require('./project/util');
const ResultsModel = require('./project/results-model');
const ResultsPaneView = require('./project/results-pane');
const $ = etch.dom;

module.exports =
class ProjectFindView {
  constructor(model, {findBuffer, replaceBuffer, pathsBuffer, findHistoryCycler, replaceHistoryCycler, pathsHistoryCycler}) {
    this.model = model
    this.findBuffer = findBuffer
    this.replaceBuffer = replaceBuffer
    this.pathsBuffer = pathsBuffer
    this.findHistoryCycler = findHistoryCycler;
    this.replaceHistoryCycler = replaceHistoryCycler;
    this.pathsHistoryCycler = pathsHistoryCycler;
    this.subscriptions = new CompositeDisposable()
    this.modelSupbscriptions = new CompositeDisposable()

    etch.initialize(this)

    this.handleEvents();

    this.findHistoryCycler.addEditorElement(this.findEditor.element);
    this.replaceHistoryCycler.addEditorElement(this.replaceEditor.element);
    this.pathsHistoryCycler.addEditorElement(this.pathsEditor.element);

    this.onlyRunIfChanged = true;

    this.clearMessages();
    this.updateOptionViews();
    this.updateSyntaxHighlighting();
  }

  update() {}

  render() {
    return (
      $.div({tabIndex: -1, className: 'project-find padded'},
        $.header({className: 'header'},
          $.span({ref: 'closeButton', className: 'header-item close-button pull-right'},
            $.i({className: "icon icon-x clickable"})
          ),
          $.span({ref: 'descriptionLabel', className: 'header-item description'}),
          $.span({className: 'header-item options-label pull-right'},
            $.span({}, 'Finding with Options: '),
            $.span({ref: 'optionsLabel', className: 'options'}),
            $.span({className: 'btn-group btn-toggle btn-group-options'},
              $.button({ref: 'regexOptionButton', className: 'btn option-regex'},
                $.svg({className: "icon", innerHTML: `<use xlink:href="#find-and-replace-icon-regex" />`})
              ),
              $.button({ref: 'caseOptionButton', className: 'btn option-case-sensitive'},
                $.svg({className: "icon", innerHTML: `<use xlink:href="#find-and-replace-icon-case" />`})
              ),
              $.button({ref: 'wholeWordOptionButton', className: 'btn option-whole-word'},
                $.svg({className: "icon", innerHTML:`<use xlink:href="#find-and-replace-icon-word" />`})
              )
            )
          )
        ),

        $.section({ref: 'replacmentInfoBlock', className: 'input-block'},
          $.progress({ref: 'replacementProgress', className: 'inline-block'}),
          $.span({ref: 'replacmentInfo', className: 'inline-block'}, 'Replaced 2 files of 10 files')
        ),

        $.section({className: 'input-block find-container'},
          $.div({className: 'input-block-item input-block-item--flex editor-container'},
            etch.dom(TextEditor, {
              ref: 'findEditor',
              mini: true,
              placeholderText: 'Find in project',
              buffer: this.findBuffer
            })
          ),
          $.div({className: 'input-block-item'},
            $.div({className: 'btn-group btn-group-find'},
              $.button({ref: 'findAllButton', className: 'btn'}, 'Find All')
            )
          )
        ),

        $.section({className: 'input-block replace-container'},
          $.div({className: 'input-block-item input-block-item--flex editor-container'},
            etch.dom(TextEditor, {
              ref: 'replaceEditor',
              mini: true,
              placeholderText: 'Replace in project',
              buffer: this.replaceBuffer
            })
          ),
          $.div({className: 'input-block-item'},
            $.div({className: 'btn-group btn-group-replace-all'},
              $.button({ref: 'replaceAllButton', className: 'btn disabled'}, 'Replace All')
            )
          )
        ),

        $.section({className: 'input-block paths-container'},
          $.div({className: 'input-block-item editor-container'},
            etch.dom(TextEditor, {
              ref: 'pathsEditor',
              mini: true,
              placeholderText: 'File/directory pattern: For example `src` to search in the "src" directory; `*.js` to search all JavaScript files; `!src` to exclude the "src" directory; `!*.json` to exclude all JSON files',
              buffer: this.pathsBuffer
            })
          )
        )
      )
    );
  }

  get findEditor() { return this.refs.findEditor }
  get replaceEditor() { return this.refs.replaceEditor }
  get pathsEditor() { return this.refs.pathsEditor }

  destroy() {
    if (this.subscriptions) this.subscriptions.dispose();
    if (this.tooltipSubscriptions) this.tooltipSubscriptions.dispose();
    if (this.modelSupbscriptions) this.modelSupbscriptions.dispose();
    this.model = null;
  }

  setPanel(panel) {
    this.panel = panel;
    this.subscriptions.add(this.panel.onDidChangeVisible(visible => {
      if (visible) {
        this.didShow();
      } else {
        this.didHide();
      }
    }));
  }

  didShow() {
    atom.views.getView(atom.workspace).classList.add('find-visible');
    if (this.tooltipSubscriptions != null) { return; }

    this.updateReplaceAllButtonEnablement();
    this.tooltipSubscriptions = new CompositeDisposable(
      atom.tooltips.add(this.refs.closeButton, {
        title: 'Close Panel <span class="keystroke">Esc</span>',
        html: true
      }),

      atom.tooltips.add(this.refs.regexOptionButton, {
        title: "Use Regex",
        keyBindingCommand: 'project-find:toggle-regex-option',
        keyBindingTarget: this.findEditor.element
      }),

      atom.tooltips.add(this.refs.caseOptionButton, {
        title: "Match Case",
        keyBindingCommand: 'project-find:toggle-case-option',
        keyBindingTarget: this.findEditor.element
      }),

      atom.tooltips.add(this.refs.wholeWordOptionButton, {
        title: "Whole Word",
        keyBindingCommand: 'project-find:toggle-whole-word-option',
        keyBindingTarget: this.findEditor.element
      }),

      atom.tooltips.add(this.refs.findAllButton, {
        title: "Find All",
        keyBindingCommand: 'find-and-replace:search',
        keyBindingTarget: this.findEditor.element
      })
    );
  }

  didHide() {
    this.hideAllTooltips();
    let workspaceElement = atom.views.getView(atom.workspace);
    workspaceElement.focus();
    workspaceElement.classList.remove('find-visible');
  }

  hideAllTooltips() {
    this.tooltipSubscriptions.dispose();
    this.tooltipSubscriptions = null;
  }

  handleEvents() {
    this.subscriptions.add(atom.commands.add('atom-workspace', {
      'find-and-replace:use-selection-as-find-pattern': () => this.setSelectionAsFindPattern(),
      'find-and-replace:use-selection-as-replace-pattern': () => this.setSelectionAsReplacePattern()
    }));

    this.subscriptions.add(atom.commands.add(this.element, {
      'find-and-replace:focus-next': () => this.focusNextElement(1),
      'find-and-replace:focus-previous': () => this.focusNextElement(-1),
      'core:confirm': () => this.confirm(),
      'core:close': () => this.panel && this.panel.hide(),
      'core:cancel': () => this.panel && this.panel.hide(),
      'project-find:confirm': () => this.confirm(),
      'project-find:toggle-regex-option': () => this.toggleRegexOption(),
      'project-find:toggle-case-option': () => this.toggleCaseOption(),
      'project-find:toggle-whole-word-option': () => this.toggleWholeWordOption(),
      'project-find:replace-all': () => this.replaceAll()
    }));

    let updateInterfaceForSearching = () => {
      this.setInfoMessage('Searching...');
    };

    let updateInterfaceForResults = results => {
      if (results.matchCount === 0 && results.findPattern === '') {
        this.clearMessages();
      } else {
        this.generateResultsMessage(results);
      }
      this.updateReplaceAllButtonEnablement(results);
    };

    const resetInterface = () => {
      this.clearMessages();
      this.updateReplaceAllButtonEnablement(null);
    };
    this.handleEvents.resetInterface = resetInterface;

    let afterSearch = () => {
      if (atom.config.get('find-and-replace.closeFindPanelAfterSearch')) {
        this.panel && this.panel.hide();
      }
    }

    let searchFinished = results => {
      afterSearch();
      updateInterfaceForResults(results);
    };

    const addModelHandlers = () => {
      this.modelSupbscriptions.add(this.model.onDidClear(resetInterface));
      this.modelSupbscriptions.add(this.model.onDidClearReplacementState(updateInterfaceForResults));
      this.modelSupbscriptions.add(this.model.onDidStartSearching(updateInterfaceForSearching));
      this.modelSupbscriptions.add(this.model.onDidNoopSearch(afterSearch));
      this.modelSupbscriptions.add(this.model.onDidFinishSearching(searchFinished));
      this.modelSupbscriptions.add(this.model.getFindOptions().onDidChange(this.updateOptionViews.bind(this)));
      this.modelSupbscriptions.add(this.model.getFindOptions().onDidChangeUseRegex(this.updateSyntaxHighlighting.bind(this)));
    }
    this.handleEvents.addModelHandlers=addModelHandlers;
    addModelHandlers();

    this.element.addEventListener('focus', () => this.findEditor.element.focus());
    this.refs.closeButton.addEventListener('click', () => this.panel && this.panel.hide());
    this.refs.regexOptionButton.addEventListener('click', () => this.toggleRegexOption());
    this.refs.caseOptionButton.addEventListener('click', () => this.toggleCaseOption());
    this.refs.wholeWordOptionButton.addEventListener('click', () => this.toggleWholeWordOption());
    this.refs.replaceAllButton.addEventListener('click', () => this.replaceAll());
    this.refs.findAllButton.addEventListener('click', () => this.search());

    const focusCallback = () => this.onlyRunIfChanged = false;
    window.addEventListener('focus', focusCallback);
    this.subscriptions.add(new Disposable(() => window.removeEventListener('focus', focusCallback)))

    this.findEditor.getBuffer().onDidChange(() => {
      this.updateReplaceAllButtonEnablement(this.model.getResultsSummary());
    });
    this.handleEventsForReplace();
  }

  handleEventsForReplace() {
    this.replaceEditor.getBuffer().onDidChange(() => this.model.clearReplacementState());
    this.replaceEditor.onDidStopChanging(() => this.model.getFindOptions().set({replacePattern: this.replaceEditor.getText()}));
    this.replacementsMade = 0;
    const addReplaceModelHandlers = () => {
      this.modelSupbscriptions.add(this.model.onDidStartReplacing(promise => {
        this.replacementsMade = 0;
        this.refs.replacmentInfoBlock.style.display = '';
        this.refs.replacementProgress.removeAttribute('value');
      }));

      this.modelSupbscriptions.add(this.model.onDidReplacePath(result => {
        this.replacementsMade++;
        this.refs.replacementProgress.value = this.replacementsMade / this.model.getPathCount();
        this.refs.replacmentInfo.textContent = `Replaced ${this.replacementsMade} of ${_.pluralize(this.model.getPathCount(), 'file')}`;
      }));

      this.modelSupbscriptions.add(this.model.onDidFinishReplacing(result => this.onFinishedReplacing(result)));
    }
    this.handleEventsForReplace.addReplaceModelHandlers=addReplaceModelHandlers;
    addReplaceModelHandlers();
  }

  focusNextElement(direction) {
    const elements = [
      this.findEditor.element,
      this.replaceEditor.element,
      this.pathsEditor.element
    ];

    let focusedIndex = elements.findIndex(el => el.hasFocus()) + direction;
    if (focusedIndex >= elements.length) focusedIndex = 0;
    if (focusedIndex < 0) focusedIndex = elements.length - 1;

    elements[focusedIndex].focus();
    elements[focusedIndex].getModel().selectAll();
  }

  focusFindElement() {
    const activeEditor = atom.workspace.getCenter().getActiveTextEditor();
    let selectedText = activeEditor && activeEditor.getSelectedText()
    if (selectedText && selectedText.indexOf('\n') < 0) {
      if (this.model.getFindOptions().useRegex) {
        selectedText = Util.escapeRegex(selectedText);
      }
      this.findEditor.setText(selectedText);
    }
    this.findEditor.getElement().focus();
    this.findEditor.selectAll();
  }

  confirm() {
    if (this.findEditor.getText().length === 0) {
      this.model.clear();
      return;
    }

    this.findHistoryCycler.store();
    this.replaceHistoryCycler.store();
    this.pathsHistoryCycler.store();

    let searchPromise = this.search({onlyRunIfChanged: this.onlyRunIfChanged});
    this.onlyRunIfChanged = true;
    return searchPromise;
  }

  async search(options) {
    // We always want to set the options passed in, even if we dont end up doing the search
    if (options == null) { options = {}; }
    this.model.getFindOptions().set(options);

    let findPattern = this.findEditor.getText();
    let pathsPattern = this.pathsEditor.getText();
    let replacePattern = this.replaceEditor.getText();

    let {onlyRunIfActive, onlyRunIfChanged} = options;
    if ((onlyRunIfActive && !this.model.active) || !findPattern) return Promise.resolve();

    await this.showResultPane()

    try {
      return await this.model.search(findPattern, pathsPattern, replacePattern, options);
    } catch (e) {
      this.setErrorMessage(e.message);
    }
  }

  replaceAll() {
    if (!this.model.matchCount) {
      atom.beep();
      return;
    }

    const findPattern = this.model.getLastFindPattern();
    const currentPattern = this.findEditor.getText();
    if (findPattern && findPattern !== currentPattern) {
      atom.confirm({
        message: `The searched pattern '${findPattern}' was changed to '${currentPattern}'`,
        detailedMessage: `Please run the search with the new pattern '${currentPattern}' before running a replace-all`,
        buttons: ['OK']
      });
      return;
    }

    return this.showResultPane().then(async () => {
      const pathsPattern = this.pathsEditor.getText();
      const replacePattern = this.replaceEditor.getText();

      const message = `This will replace '${findPattern}' with '${replacePattern}' ${_.pluralize(this.model.matchCount, 'time')} in ${_.pluralize(this.model.pathCount, 'file')}`;
      const { response } = await atom.confirm({
        message: 'Are you sure you want to replace all?',
        detailedMessage: message,
        buttons: ['OK', 'Cancel']
      });

      if (response === 0) {
        this.clearMessages();
        return this.model.replace(pathsPattern, replacePattern, this.model.getPaths());
      }
    });
  }

  directoryPathForElement(element) {
    const directoryElement = element.closest('.directory');
    if (directoryElement) {
      const pathElement = directoryElement.querySelector('[data-path]')
      return pathElement && pathElement.dataset.path;
    } else {
      const activeEditor = atom.workspace.getCenter().getActiveTextEditor();
      if (activeEditor) {
        const editorPath = activeEditor.getPath()
        if (editorPath) {
          return path.dirname(editorPath);
        }
      }
    }
  }

  findInCurrentlySelectedDirectory(selectedElement) {
    const absolutePath = this.directoryPathForElement(selectedElement);
    if (absolutePath) {
      let [rootPath, relativePath] = atom.project.relativizePath(absolutePath);
      if (rootPath && atom.project.getDirectories().length > 1) {
        relativePath = path.join(path.basename(rootPath), relativePath);
      }
      this.pathsEditor.setText(relativePath);
      this.findEditor.getElement().focus();
      this.findEditor.selectAll();
    }
  }

  showResultPane() {
    let options = {searchAllPanes: true};
    let openDirection = atom.config.get('find-and-replace.projectSearchResultsPaneSplitDirection');
    if (openDirection !== 'none') { options.split = openDirection; }
    return atom.workspace.open(ResultsPaneView.URI, options);
  }

  onFinishedReplacing(results) {
    if (!results.replacedPathCount) atom.beep();
    this.refs.replacmentInfoBlock.style.display = 'none';
  }

  generateResultsMessage(results) {
    let message = Util.getSearchResultsMessage(results);
    if (results.replacedPathCount != null) { message = Util.getReplacementResultsMessage(results); }
    this.setInfoMessage(message);
  }

  clearMessages() {
    this.element.classList.remove('has-results', 'has-no-results');
    this.setInfoMessage('Find in Project');
    this.refs.replacmentInfoBlock.style.display = 'none';
  }

  setInfoMessage(infoMessage) {
    this.refs.descriptionLabel.innerHTML = infoMessage;
    this.refs.descriptionLabel.classList.remove('text-error');
  }

  setErrorMessage(errorMessage) {
    this.refs.descriptionLabel.innerHTML = errorMessage;
    this.refs.descriptionLabel.classList.add('text-error');
  }

  updateReplaceAllButtonEnablement(results) {
    const canReplace = results &&
      results.matchCount &&
      results.findPattern == this.findEditor.getText();
    if (canReplace && !this.refs.replaceAllButton.classList.contains('disabled')) return;

    if (this.replaceTooltipSubscriptions) this.replaceTooltipSubscriptions.dispose();
    this.replaceTooltipSubscriptions = new CompositeDisposable;

    if (canReplace) {
      this.refs.replaceAllButton.classList.remove('disabled');
      this.replaceTooltipSubscriptions.add(atom.tooltips.add(this.refs.replaceAllButton, {
        title: "Replace All",
        keyBindingCommand: 'project-find:replace-all',
        keyBindingTarget: this.replaceEditor.element
      }));
    } else {
      this.refs.replaceAllButton.classList.add('disabled');
      this.replaceTooltipSubscriptions.add(atom.tooltips.add(this.refs.replaceAllButton, {
        title: "Replace All [run a search to enable]"}
      ));
    }
  }

  setSelectionAsFindPattern() {
    const editor = atom.workspace.getCenter().getActivePaneItem();
    if (editor && editor.getSelectedText) {
      let pattern = editor.getSelectedText() || editor.getWordUnderCursor();
      if (this.model.getFindOptions().useRegex) {
        pattern = Util.escapeRegex(pattern);
      }
      if (pattern) {
        this.findEditor.setText(pattern);
        this.findEditor.getElement().focus();
        this.findEditor.selectAll();
      }
    }
  }

  setSelectionAsReplacePattern() {
    const editor = atom.workspace.getCenter().getActivePaneItem();
    if (editor && editor.getSelectedText) {
      let pattern = editor.getSelectedText() || editor.getWordUnderCursor();
      if (this.model.getFindOptions().useRegex) {
        pattern = Util.escapeRegex(pattern);
      }
      if (pattern) {
        this.replaceEditor.setText(pattern);
        this.replaceEditor.getElement().focus();
        this.replaceEditor.selectAll();
      }
    }
  }

  updateOptionViews() {
    this.updateOptionButtons();
    this.updateOptionsLabel();
  }

  updateSyntaxHighlighting() {
    if (this.model.getFindOptions().useRegex) {
      this.findEditor.setGrammar(atom.grammars.grammarForScopeName('source.js.regexp'));
      return this.replaceEditor.setGrammar(atom.grammars.grammarForScopeName('source.js.regexp.replacement'));
    } else {
      this.findEditor.setGrammar(atom.grammars.nullGrammar);
      return this.replaceEditor.setGrammar(atom.grammars.nullGrammar);
    }
  }

  updateOptionsLabel() {
    const label = [];

    if (this.model.getFindOptions().useRegex) {
      label.push('Regex');
    }

    if (this.model.getFindOptions().caseSensitive) {
      label.push('Case Sensitive');
    } else {
      label.push('Case Insensitive');
    }

    if (this.model.getFindOptions().wholeWord) {
      label.push('Whole Word');
    }

    this.refs.optionsLabel.textContent = label.join(', ');
  }

  updateOptionButtons() {
    this.setOptionButtonState(this.refs.regexOptionButton, this.model.getFindOptions().useRegex);
    this.setOptionButtonState(this.refs.caseOptionButton, this.model.getFindOptions().caseSensitive);
    this.setOptionButtonState(this.refs.wholeWordOptionButton, this.model.getFindOptions().wholeWord);
  }

  setOptionButtonState(optionButton, selected) {
    if (selected) {
      optionButton.classList.add('selected');
    } else {
      optionButton.classList.remove('selected');
    }
  }

  toggleRegexOption() {
    this.search({onlyRunIfActive: true, useRegex: !this.model.getFindOptions().useRegex});
  }

  toggleCaseOption() {
    this.search({onlyRunIfActive: true, caseSensitive: !this.model.getFindOptions().caseSensitive});
  }

  toggleWholeWordOption() {
    this.search({onlyRunIfActive: true, wholeWord: !this.model.getFindOptions().wholeWord});
  }
};
