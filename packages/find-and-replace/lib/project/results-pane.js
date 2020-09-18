const _ = require('underscore-plus');
const {CompositeDisposable} = require('atom');
const ResultsView = require('./results-view');
const ResultsModel = require('./results-model');
const {showIf, getSearchResultsMessage, escapeHtml} = require('./util');
const etch = require('etch');
const $ = etch.dom;


module.exports =
class ResultsPaneView {
  constructor() {
    this.model = ResultsPaneView.projectFindView.model;
    this.model.setActive(true);
    this.isLoading = false;
    this.searchErrors = [];
    this.searchResults = null;
    this.searchingIsSlow = false;
    this.numberOfPathsSearched = 0;
    this.searchContextLineCountBefore = 0;
    this.searchContextLineCountAfter = 0;
    this.uri = ResultsPaneView.URI;

    etch.initialize(this);

    this.onFinishedSearching(this.model.getResultsSummary());
    this.element.addEventListener('focus', this.focused.bind(this));
    this.element.addEventListener('click', event => {
      switch (event.target) {
        case this.refs.collapseAll:
          this.collapseAllResults();
          break;
        case this.refs.expandAll:
          this.expandAllResults();
          break;
        case this.refs.decrementLeadingContextLines:
          this.decrementLeadingContextLines();
          break;
        case this.refs.toggleLeadingContextLines:
          this.toggleLeadingContextLines();
          break;
        case this.refs.incrementLeadingContextLines:
          this.incrementLeadingContextLines();
          break;
        case this.refs.decrementTrailingContextLines:
          this.decrementTrailingContextLines();
          break;
        case this.refs.toggleTrailingContextLines:
          this.toggleTrailingContextLines();
          break;
        case this.refs.incrementTrailingContextLines:
          this.incrementTrailingContextLines();
        case this.refs.dontOverrideTab:
          this.dontOverrideTab();
          break;
      }
    })

    this.subscriptions = new CompositeDisposable(
      this.model.onDidStartSearching(this.onSearch.bind(this)),
      this.model.onDidFinishSearching(this.onFinishedSearching.bind(this)),
      this.model.onDidClear(this.onCleared.bind(this)),
      this.model.onDidClearReplacementState(this.onReplacementStateCleared.bind(this)),
      this.model.onDidSearchPaths(this.onPathsSearched.bind(this)),
      this.model.onDidErrorForPath(error => this.appendError(error.message)),
      atom.config.observe('find-and-replace.searchContextLineCountBefore', this.searchContextLineCountChanged.bind(this)),
      atom.config.observe('find-and-replace.searchContextLineCountAfter', this.searchContextLineCountChanged.bind(this))
    );
  }

  update() {}

  destroy() {
    this.model.setActive(false);
    this.subscriptions.dispose();
    if(this.separatePane)
      this.model = null;
  }

  render() {
    const matchCount = this.searchResults && this.searchResults.matchCount;

    return (
      $.div(
        {
          tabIndex: -1,
          className: `preview-pane pane-item ${matchCount === 0 ? 'no-results' : ''}`,
        },

        $.div({className: 'preview-header'},
          $.span({
            ref: 'previewCount',
            className: 'preview-count inline-block',
            innerHTML: this.isLoading
              ? 'Searching...'
              : (getSearchResultsMessage(this.searchResults) || 'Project search results')
          }),

          $.button(
            {
              ref: 'dontOverrideTab',
              style: {display: matchCount == 0 || this.isLoading ? 'none' : ''},
              className: 'btn'
            }, "Don't override this tab"),

          $.div(
            {
              ref: 'previewControls',
              className: 'preview-controls',
              style: {display: matchCount > 0 ? '' : 'none'}
            },

            this.searchContextLineCountBefore > 0 ?
              $.div({className: 'btn-group'},
                $.button(
                  {
                    ref: 'decrementLeadingContextLines',
                    className: 'btn' + (this.model.getFindOptions().leadingContextLineCount === 0 ? ' disabled' : '')
                  }, '-'),
                $.button(
                  {
                    ref: 'toggleLeadingContextLines',
                    className: 'btn'
                  },
                  $.svg(
                    {
                      className: 'icon',
                      innerHTML: '<use xlink:href="#find-and-replace-context-lines-before" />'
                    }
                  )
                ),
                $.button(
                  {
                    ref: 'incrementLeadingContextLines',
                    className: 'btn' + (this.model.getFindOptions().leadingContextLineCount >= this.searchContextLineCountBefore ? ' disabled' : '')
                  }, '+')
              ) : null,

            this.searchContextLineCountAfter > 0 ?
              $.div({className: 'btn-group'},
                $.button(
                  {
                    ref: 'decrementTrailingContextLines',
                    className: 'btn' + (this.model.getFindOptions().trailingContextLineCount === 0 ? ' disabled' : '')
                  }, '-'),
                $.button(
                  {
                    ref: 'toggleTrailingContextLines',
                    className: 'btn'
                  },
                  $.svg(
                    {
                      className: 'icon',
                      innerHTML: '<use xlink:href="#find-and-replace-context-lines-after" />'
                    }
                  )
                ),
                $.button(
                  {
                    ref: 'incrementTrailingContextLines',
                    className: 'btn' + (this.model.getFindOptions().trailingContextLineCount >= this.searchContextLineCountAfter ? ' disabled' : '')
                  }, '+')
              ) : null,

            $.div({className: 'btn-group'},
              $.button({ref: 'collapseAll', className: 'btn'}, 'Collapse All'),
              $.button({ref: 'expandAll', className: 'btn'}, 'Expand All')
            )
          ),

          $.div({className: 'inline-block', style: showIf(this.isLoading)},
            $.div({className: 'loading loading-spinner-tiny inline-block'}),

            $.div(
              {
                className: 'inline-block',
                style: showIf(this.isLoading && this.searchingIsSlow)
              },

              $.span({ref: 'searchedCount', className: 'searched-count'},
                this.numberOfPathsSearched.toString()
              ),
              $.span({}, ' paths searched')
            )
          )
        ),

        $.ul(
          {
            ref: 'errorList',
            className: 'error-list list-group padded',
            style: showIf(this.searchErrors.length > 0)
          },

          ...this.searchErrors.map(message =>
            $.li({className: 'text-error'}, escapeHtml(message))
          )
        ),

        etch.dom(ResultsView, {ref: 'resultsView', model: this.model}),

        $.ul(
          {
            className: 'centered background-message no-results-overlay',
            style: showIf(matchCount === 0)
          },
          $.li({}, 'No Results')
        )
      )
    );
  }

  copy() {
    return new ResultsPaneView();
  }

  getTitle() {
    return 'Project Find Results';
  }

  getIconName() {
    return 'search';
  }

  getURI() {
    return this.uri;
  }

  focused() {
    this.refs.resultsView.element.focus();
  }

  appendError(message) {
    this.searchErrors.push(message)
    etch.update(this);
  }

  onSearch(searchPromise) {
    this.isLoading = true;
    this.searchingIsSlow = false;
    this.numberOfPathsSearched = 0;

    setTimeout(() => {
      this.searchingIsSlow = true;
      etch.update(this);
    }, 500);

    etch.update(this);

    let stopLoading = () => {
      this.isLoading = false;
      etch.update(this);
    };
    return searchPromise.then(stopLoading, stopLoading);
  }

  onPathsSearched(numberOfPathsSearched) {
    this.numberOfPathsSearched = numberOfPathsSearched;
    etch.update(this);
  }

  onFinishedSearching(results) {
    this.searchResults = results;
    if (results.searchErrors || results.replacementErrors) {
      this.searchErrors =
        _.pluck(results.replacementErrors, 'message')
        .concat(_.pluck(results.searchErrors, 'message'));
    } else {
      this.searchErrors = [];
    }
    etch.update(this);
  }

  onReplacementStateCleared(results) {
    this.searchResults = results;
    this.searchErrors = [];
    etch.update(this);
  }

  onCleared() {
    this.isLoading = false;
    this.searchErrors = [];
    this.searchResults = {};
    this.searchingIsSlow = false;
    this.numberOfPathsSearched = 0;
    etch.update(this);
  }

  collapseAllResults() {
    this.refs.resultsView.collapseAllResults();
    this.refs.resultsView.element.focus();
  }

  expandAllResults() {
    this.refs.resultsView.expandAllResults();
    this.refs.resultsView.element.focus();
  }

  decrementLeadingContextLines() {
    this.refs.resultsView.decrementLeadingContextLines();
    etch.update(this);
  }

  toggleLeadingContextLines() {
    this.refs.resultsView.toggleLeadingContextLines();
    etch.update(this);
  }

  incrementLeadingContextLines() {
    this.refs.resultsView.incrementLeadingContextLines();
    etch.update(this);
  }

  decrementTrailingContextLines() {
    this.refs.resultsView.decrementTrailingContextLines();
    etch.update(this);
  }

  toggleTrailingContextLines() {
    this.refs.resultsView.toggleTrailingContextLines();
    etch.update(this);
  }

  incrementTrailingContextLines() {
    this.refs.resultsView.incrementTrailingContextLines();
    etch.update(this);
  }

  searchContextLineCountChanged() {
    this.searchContextLineCountBefore = atom.config.get('find-and-replace.searchContextLineCountBefore');
    this.searchContextLineCountAfter = atom.config.get('find-and-replace.searchContextLineCountAfter');
    // update the visible line count in the find options to not exceed the maximum available lines
    let findOptionsChanged = false;
    if (this.searchContextLineCountBefore < this.model.getFindOptions().leadingContextLineCount) {
      this.model.getFindOptions().leadingContextLineCount = this.searchContextLineCountBefore;
      findOptionsChanged = true;
    }
    if (this.searchContextLineCountAfter < this.model.getFindOptions().trailingContextLineCount) {
      this.model.getFindOptions().trailingContextLineCount = this.searchContextLineCountAfter;
      findOptionsChanged = true;
    }
    etch.update(this);
    if (findOptionsChanged) {
      etch.update(this.refs.resultsView);
    }
  }

  dontOverrideTab(){
    let view = ResultsPaneView.projectFindView;
    view.handleEvents.resetInterface();
    view.model = new ResultsModel(view.model.findOptions,view.model.metricsReporter);
    this.uri = ResultsPaneView.URI + "/" + this.model.getLastFindPattern();
    this.refs.dontOverrideTab.classList.add('disabled');

    view.modelSupbscriptions.dispose();
    view.handleEvents.addModelHandlers();
    view.handleEventsForReplace.addReplaceModelHandlers();
    this.separatePane=true;
  }
}

module.exports.URI = "atom://find-and-replace/project-results";
