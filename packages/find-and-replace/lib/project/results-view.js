const { Range, CompositeDisposable, Disposable } = require('atom');
const ResultRowView = require('./result-row-view');
const {
  LeadingContextRow,
  TrailingContextRow,
  ResultPathRow,
  MatchRow,
  ResultRowGroup
} = require('./result-row');

const ListView = require('./list-view');
const etch = require('etch');
const binarySearch = require('binary-search')

const path = require('path');
const $ = etch.dom;

const reverseDirections = {
  left: 'right',
  right: 'left',
  up: 'down',
  down: 'up'
};

const filepathComp = (path1, path2) => path1.localeCompare(path2)

module.exports =
class ResultsView {
  constructor({model}) {
    this.model = model;
    this.pixelOverdraw = 100;

    this.resultRowGroups = Object.values(model.results).map(result =>
      new ResultRowGroup(result, this.model.getFindOptions())
    )
    this.resultRowGroups.sort((group1, group2) => filepathComp(
      group1.result.filePath, group2.result.filePath
    ))
    this.rowGroupLengths = this.resultRowGroups.map(group => group.rows.length)

    this.resultRows = [].concat(...this.resultRowGroups.map(group => group.rows))
    this.selectedRowIndex = this.resultRows.length ? 0 : -1

    this.fakeGroup = new ResultRowGroup({
      filePath: 'fake-file-path',
      matches: [{
        range: [[0, 1], [0, 2]],
        leadingContextLines: ['test-line-before'],
        trailingContextLines: ['test-line-after'],
        lineTextOffset: 1,
        lineText: 'fake-line-text',
        matchText: 'fake-match-text',
      }],
    },
    {
      leadingContextLineCount: 1,
      trailingContextLineCount: 0
    })

    etch.initialize(this);

    const resizeObserver = new ResizeObserver(this.invalidateItemHeights.bind(this));
    resizeObserver.observe(this.element);
    this.element.addEventListener('mousedown', this.handleClick.bind(this));

    this.subscriptions = new CompositeDisposable(
      atom.config.observe('editor.fontFamily', this.fontFamilyChanged.bind(this)),
      this.model.onDidAddResult(this.didAddResult.bind(this)),
      this.model.onDidSetResult(this.didSetResult.bind(this)),
      this.model.onDidRemoveResult(this.didRemoveResult.bind(this)),
      this.model.onDidClearSearchState(this.didClearSearchState.bind(this)),
      this.model.getFindOptions().onDidChangeReplacePattern(() => etch.update(this)),

      atom.commands.add(this.element, {
        'core:move-up': this.moveUp.bind(this),
        'core:move-down': this.moveDown.bind(this),
        'core:move-left': this.collapseResult.bind(this),
        'core:move-right': this.expandResult.bind(this),
        'core:page-up': this.pageUp.bind(this),
        'core:page-down': this.pageDown.bind(this),
        'core:move-to-top': this.moveToTop.bind(this),
        'core:move-to-bottom': this.moveToBottom.bind(this),
        'core:confirm': this.confirmResult.bind(this),
        'core:copy': this.copyResult.bind(this),
        'find-and-replace:copy-path': this.copyPath.bind(this)
      })
    );
  }

  update() {}

  destroy() {
    this.subscriptions.dispose();
  }

  getRowHeight(resultRow) {
    if (resultRow instanceof LeadingContextRow) {
      return this.contextRowHeight
    } else if (resultRow instanceof TrailingContextRow) {
      return this.contextRowHeight
    } else if (resultRow instanceof ResultPathRow) {
      return this.pathRowHeight
    } else if (resultRow instanceof MatchRow) {
      return this.matchRowHeight
    }
  }

  render () {
    this.maintainPreviousScrollPosition();

    let regex = null, replacePattern = null;
    if (this.model.replacedPathCount == null) {
      regex = this.model.regex;
      replacePattern = this.model.getFindOptions().replacePattern;
    }

    return $.div(
      {
        className: 'results-view focusable-panel',
        tabIndex: '-1',
        style: this.previewStyle
      },

      $.ol(
        {
          className: 'list-tree has-collapsable-children',
          style: {visibility: 'hidden', position: 'absolute', overflow: 'hidden', left: 0, top: 0, right: 0}
        },
        $(ResultRowView, {
          ref: 'dummyResultPathRowView',
          item: {
            row: this.fakeGroup.rows[0],
            regex, replacePattern
          }
        }),
        $(ResultRowView, {
          ref: 'dummyContextRowView',
          item: {
            row: this.fakeGroup.rows[1],
            regex, replacePattern
          }
        }),
        $(ResultRowView, {
          ref: 'dummyMatchRowView',
          item: {
            row: this.fakeGroup.rows[2],
            regex, replacePattern
          }
        })
      ),

      $(ListView, {
        ref: 'listView',
        className: 'list-tree has-collapsable-children',
        itemComponent: ResultRowView,
        heightForItem: item => this.getRowHeight(item.row),
        items: this.resultRows.map((row, i) => ({
          row,
          isSelected: i === this.selectedRowIndex,
          regex,
          replacePattern
        }))
      })
    );
  }

  async invalidateItemHeights() {
    const {
      dummyResultPathRowView,
      dummyMatchRowView,
      dummyContextRowView,
    } = this.refs;

    const pathRowHeight = dummyResultPathRowView.element.offsetHeight
    const matchRowHeight = dummyMatchRowView.element.offsetHeight
    const contextRowHeight = dummyContextRowView.element.offsetHeight

    const clientHeight = this.refs.listView && this.refs.listView.element.clientHeight;

    if (matchRowHeight !== this.matchRowHeight ||
        pathRowHeight !== this.pathRowHeight ||
        contextRowHeight !== this.contextRowHeight ||
        clientHeight !== this.clientHeight) {
      this.matchRowHeight = matchRowHeight;
      this.pathRowHeight = pathRowHeight;
      this.contextRowHeight = contextRowHeight;
      this.clientHeight = clientHeight;
      await etch.update(this);
    }

    etch.update(this);
  }

  // This method should be the only one allowed to modify this.resultRows
  spliceRows(start, deleteCount, rows) {
    this.resultRows.splice(start, deleteCount, ...rows)

    if (this.selectedRowIndex >= start + deleteCount) {
      this.selectedRowIndex += rows.length - deleteCount
      this.scrollToSelectedMatch()
    } else if (this.selectedRowIndex >= start + rows.length) {
      this.selectRow(start + rows.length - 1)
    }
  }

  invalidateRowGroup(firstRowIndex, groupIndex) {
    const { leadingContextLineCount, trailingContextLineCount } = this.model.getFindOptions()
    const rowGroup = this.resultRowGroups[groupIndex]

    if (!rowGroup.data.isCollapsed) {
      rowGroup.generateRows(this.model.getFindOptions())
    }
    this.spliceRows(
      firstRowIndex, this.rowGroupLengths[groupIndex],
      rowGroup.displayedRows()
    )
    this.rowGroupLengths[groupIndex] = rowGroup.displayedRows().length
  }

  getGroupCountBefore(filePath) {
    const res = binarySearch(
      this.resultRowGroups, filePath,
      (rowGroup, needle) => filepathComp(rowGroup.result.filePath, needle)
    )
    return res < 0 ? -res - 1 : res
  }

  getRowCountBefore(groupIndex) {
    let rowCount = 0
    for (let i = 0; i < groupIndex; ++i) {
      rowCount += this.resultRowGroups[i].displayedRows().length
    }
    return rowCount
  }

  // These four methods are the only ones allowed to modify this.resultRowGroups
  didAddResult({result, filePath}) {
    const groupIndex = this.getGroupCountBefore(filePath)
    const rowGroup = new ResultRowGroup(result, this.model.getFindOptions())

    this.resultRowGroups.splice(groupIndex, 0, rowGroup)
    this.rowGroupLengths.splice(groupIndex, 0, rowGroup.rows.length)

    const rowIndex = this.getRowCountBefore(groupIndex)
    this.spliceRows(rowIndex, 0, rowGroup.displayedRows())

    if (this.selectedRowIndex === -1) {
      this.selectRow(0)
    }

    etch.update(this);
  }

  didSetResult({result, filePath}) {
    const groupIndex = this.getGroupCountBefore(filePath)
    const rowGroup = this.resultRowGroups[groupIndex]
    const rowIndex = this.getRowCountBefore(groupIndex)

    rowGroup.result = result
    this.invalidateRowGroup(rowIndex, groupIndex)

    etch.update(this);
  }

  didRemoveResult({filePath}) {
    const groupIndex = this.getGroupCountBefore(filePath)
    const rowGroup = this.resultRowGroups[groupIndex]
    const rowIndex = this.getRowCountBefore(groupIndex)

    this.spliceRows(rowIndex, rowGroup.displayedRows().length, [])
    this.resultRowGroups.splice(groupIndex, 1)
    this.rowGroupLengths.splice(groupIndex, 1)

    etch.update(this);
  }

  didClearSearchState() {
    this.selectedRowIndex = -1
    this.resultRowGroups = []
    this.resultRows = []
    etch.update(this);
  }

  handleClick(event) {
    const clickedItem = event.target.closest('.list-item');

    if (!clickedItem) return;

    const groupIndex = this.getGroupCountBefore(clickedItem.dataset.filePath)
    const group = this.resultRowGroups[groupIndex]

    if (clickedItem.matches('.context-row, .match-row')) {
      // The third argument restricts the range to omit the path row
      const rowIndex = binarySearch(
        group.rows, clickedItem.dataset.matchLineNumber,
        ((row, lineNb) => row.data.lineNumber - lineNb),
        1
      )
      this.selectRow(this.getRowCountBefore(groupIndex) + rowIndex)
    } else {
      // If the user clicks on the left of a match, the match group is collapsed
      this.selectRow(this.getRowCountBefore(groupIndex))
    }

    // Only apply confirmResult (open editor, collapse group) on left click
    if (!event.ctrlKey && event.button === 0) {
      this.confirmResult({pending: event.detail === 1});
      event.preventDefault();
    }
    etch.update(this);
  }

  // This method should be the only one allowed to modify this.selectedRowIndex
  selectRow(i) {
    if (this.resultRows.length === 0) {
      this.selectedRowIndex = -1
      return etch.update(this)
    }

    if (i < 0) {
      this.selectedRowIndex = 0
    } else if (i >= this.resultRows.length) {
      this.selectedRowIndex = this.resultRows.length - 1
    } else {
      this.selectedRowIndex = i
    }

    const resultRow = this.resultRows[this.selectedRowIndex]

    if (resultRow instanceof LeadingContextRow) {
      this.selectedRowIndex += resultRow.rowOffset
    } else if (resultRow instanceof TrailingContextRow) {
      this.selectedRowIndex -= resultRow.rowOffset
    }

    if (i >= this.resultRows.length) {
      this.scrollToBottom()
    } else {
      this.scrollToSelectedMatch()
    }

    return etch.update(this)
  }

  selectFirstResult() {
    return this.selectRow(0)
  }

  moveToTop() {
    return this.selectRow(0)
  }

  moveToBottom() {
    return this.selectRow(this.resultRows.length)
  }

  pageUp() {
    if (this.refs.listView) {
      const {clientHeight} = this.refs.listView.element
      const position = this.positionOfSelectedResult()
      return this.selectResultAtPosition(position - clientHeight)
    }
  }

  pageDown() {
    if (this.refs.listView) {
      const {clientHeight} = this.refs.listView.element
      const position = this.positionOfSelectedResult()
      return this.selectResultAtPosition(position + clientHeight)
    }
  }

  positionOfSelectedResult() {
    let y = 0;

    for (let i = 0; i < this.selectedRowIndex; i++) {
      y += this.getRowHeight(this.resultRows[i])
    }
    return y
  }

  selectResultAtPosition(position) {
    if (this.refs.listView && this.model.getPathCount() > 0) {
      const {clientHeight} = this.refs.listView.element

      let top = 0
      for (let i = 0; i < this.resultRows.length; i++) {
        const bottom = top + this.getRowHeight(this.resultRows[i])
        if (bottom > position) {
          return this.selectRow(i)
        }
        top = bottom
      }
    }
    return this.selectRow(this.resultRows.length)
  }

  moveDown() {
    if (this.selectedRowIndex === -1) {
      return this.selectRow(0)
    }

    for (let i = this.selectedRowIndex + 1; i < this.resultRows.length; i++) {
      const row = this.resultRows[i]

      if (row instanceof ResultPathRow || row instanceof MatchRow) {
        return this.selectRow(i)
      }
    }
    return this.selectRow(this.resultRows.length)
  }

  moveUp() {
    if (this.selectedRowIndex === -1) {
      return this.selectRow(0)
    }

    for (let i = this.selectedRowIndex - 1; i >= 0; i--) {
      const row = this.resultRows[i]

      if (row instanceof ResultPathRow || row instanceof MatchRow) {
        return this.selectRow(i)
      }
    }
    return this.selectRow(0)
  }

  selectedRow() {
    return this.resultRows[this.selectedRowIndex]
  }

  expandResult() {
    if (this.selectedRowIndex === -1) {
      return
    }

    const rowGroup = this.selectedRow().group
    const groupIndex = this.resultRowGroups.indexOf(rowGroup)
    const rowIndex = this.getRowCountBefore(groupIndex)

    if (!rowGroup.data.isCollapsed) {
      if (this.selectedRowIndex === rowIndex) {
        this.selectRow(rowIndex + 1)
      }
      return
    }

    rowGroup.data.isCollapsed = false
    this.invalidateRowGroup(rowIndex, groupIndex)
    this.selectRow(rowIndex + 1)
    return etch.update(this);
  }

  collapseResult() {
    if (this.selectedRowIndex === -1) {
      return
    }

    const rowGroup = this.selectedRow().group

    if (rowGroup.data.isCollapsed) {
      return
    }

    const groupIndex = this.resultRowGroups.indexOf(rowGroup)
    const rowIndex = this.getRowCountBefore(groupIndex)

    rowGroup.data.isCollapsed = true
    this.invalidateRowGroup(rowIndex, groupIndex)
    return etch.update(this);
  }

  // This is the method called when clicking a result or pressing enter
  async confirmResult({pending} = {}) {
    if (this.selectedRowIndex === -1) {
      return
    }

    const selectedRow = this.selectedRow()

    if (selectedRow instanceof MatchRow) {
      this.currentScrollTop = this.getScrollTop();
      const match = selectedRow.data.matches[0]
      const editor = await atom.workspace.open(selectedRow.group.result.filePath, {
        pending,
        split: reverseDirections[atom.config.get('find-and-replace.projectSearchResultsPaneSplitDirection')]
      })
      editor.unfoldBufferRow(match.range.start.selectedRow)
      editor.setSelectedBufferRange(match.range, {flash: true})
      editor.scrollToCursorPosition()
    } else if (selectedRow.group.data.isCollapsed) {
      this.expandResult()
    } else {
      this.collapseResult()
    }
  }

  copyResult() {
    if (this.selectedRowIndex === -1) {
      return
    }

    const selectedRow = this.selectedRow()
    if (selectedRow.data.matches) {
      // TODO - If row has multiple matches, copy them all, using the same
      // algorithm as `Selection.copy`; ideally, that algorithm should be
      // isolated for D.R.Y. purposes
      atom.clipboard.write(selectedRow.data.matches[0].lineText);
    }
  }

  copyPath() {
    if (this.selectedRowIndex === -1) {
      return
    }

    const {filePath} = this.selectedRow().group.result
    let [projectPath, relativePath] = atom.project.relativizePath(filePath);
    if (projectPath && atom.project.getDirectories().length > 1) {
      relativePath = path.join(path.basename(projectPath), relativePath);
    }
    atom.clipboard.write(relativePath);
  }

  expandAllResults() {
    let rowIndex = 0
    // Since the whole array is re-generated, this makes splices cheaper
    this.resultRows = []
    for (let i = 0; i < this.resultRowGroups.length; i++) {
      const group = this.resultRowGroups[i]

      group.data.isCollapsed = false
      this.invalidateRowGroup(rowIndex, i)
      rowIndex += group.displayedRows().length
    }
    this.scrollToSelectedMatch();
    return etch.update(this);
  }

  collapseAllResults() {
    let rowIndex = 0
    // Since the whole array is re-generated, this makes splices cheaper
    this.resultRows = []
    for (let i = 0; i < this.resultRowGroups.length; i++) {
      const group = this.resultRowGroups[i]

      group.data.isCollapsed = true
      this.invalidateRowGroup(rowIndex, i)
      rowIndex += group.displayedRows().length
    }
    this.scrollToSelectedMatch();
    return etch.update(this);
  }

  decrementLeadingContextLines() {
    if (this.model.getFindOptions().leadingContextLineCount > 0) {
      this.model.getFindOptions().leadingContextLineCount--;
      return this.contextLinesChanged();
    }
  }

  toggleLeadingContextLines() {
    if (this.model.getFindOptions().leadingContextLineCount > 0) {
      this.model.getFindOptions().leadingContextLineCount = 0;
      return this.contextLinesChanged();
    } else {
      const searchContextLineCountBefore = atom.config.get('find-and-replace.searchContextLineCountBefore');
      if (this.model.getFindOptions().leadingContextLineCount < searchContextLineCountBefore) {
        this.model.getFindOptions().leadingContextLineCount = searchContextLineCountBefore;
        return this.contextLinesChanged();
      }
    }
  }

  incrementLeadingContextLines() {
    const searchContextLineCountBefore = atom.config.get('find-and-replace.searchContextLineCountBefore');
    if (this.model.getFindOptions().leadingContextLineCount < searchContextLineCountBefore) {
      this.model.getFindOptions().leadingContextLineCount++;
      return this.contextLinesChanged();
    }
  }

  decrementTrailingContextLines() {
    if (this.model.getFindOptions().trailingContextLineCount > 0) {
      this.model.getFindOptions().trailingContextLineCount--;
      return this.contextLinesChanged();
    }
  }

  toggleTrailingContextLines() {
    if (this.model.getFindOptions().trailingContextLineCount > 0) {
      this.model.getFindOptions().trailingContextLineCount = 0;
      return this.contextLinesChanged();
    } else {
      const searchContextLineCountAfter = atom.config.get('find-and-replace.searchContextLineCountAfter');
      if (this.model.getFindOptions().trailingContextLineCount < searchContextLineCountAfter) {
        this.model.getFindOptions().trailingContextLineCount = searchContextLineCountAfter;
        return this.contextLinesChanged();
      }
    }
  }

  incrementTrailingContextLines() {
    const searchContextLineCountAfter = atom.config.get('find-and-replace.searchContextLineCountAfter');
    if (this.model.getFindOptions().trailingContextLineCount < searchContextLineCountAfter) {
      this.model.getFindOptions().trailingContextLineCount++;
      return this.contextLinesChanged();
    }
  }

  async contextLinesChanged() {
    let rowIndex = 0
    // Since the whole array is re-generated, this makes splices cheaper
    this.resultRows = []
    for (let i = 0; i < this.resultRowGroups.length; i++) {
      const group = this.resultRowGroups[i]

      this.invalidateRowGroup(rowIndex, i)
      rowIndex += group.displayedRows().length
    }
    await etch.update(this);
    this.scrollToSelectedMatch();
  }

  scrollToSelectedMatch() {
    if (this.selectedRowIndex === -1) {
      return
    }
    if (this.refs.listView) {
      const top = this.positionOfSelectedResult();
      const bottom = top + this.getRowHeight(this.selectedRow());

      if (bottom > this.getScrollTop() + this.refs.listView.element.clientHeight) {
        this.setScrollTop(bottom - this.refs.listView.element.clientHeight);
      } else if (top < this.getScrollTop()) {
        this.setScrollTop(top);
      }
    }
  }

  scrollToBottom() {
    this.setScrollTop(this.getScrollHeight());
  }

  scrollToTop() {
    this.setScrollTop(0);
  }

  setScrollTop (scrollTop) {
    if (this.refs.listView) {
      this.refs.listView.element.scrollTop = scrollTop;
      this.refs.listView.element.dispatchEvent(new UIEvent('scroll'))
    }
  }

  getScrollTop () {
    return this.refs.listView ? this.refs.listView.element.scrollTop : 0;
  }

  getScrollHeight () {
    return this.refs.listView ? this.refs.listView.element.scrollHeight : 0;
  }

  maintainPreviousScrollPosition() {
    if(this.selectedRowIndex === -1 || !this.currentScrollTop) {
      return;
    }

    this.setScrollTop(this.currentScrollTop);
  }

  fontFamilyChanged(fontFamily) {
    this.previewStyle = {fontFamily};
    etch.update(this);
  }
};
