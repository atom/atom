const getIconServices = require('../get-icon-services');
const { Range } = require('atom');
const {
  LeadingContextRow,
  TrailingContextRow,
  ResultPathRow,
  MatchRow,
  ResultRowGroup
} = require('./result-row');
const {showIf} = require('./util');

const _ = require('underscore-plus');
const path = require('path');
const assert = require('assert');
const etch = require('etch');
const $ = etch.dom;

class ResultPathRowView {
  constructor({groupData, isSelected}) {
    const props = {groupData, isSelected};
    this.props = Object.assign({}, props);

    etch.initialize(this);
    getIconServices().updateIcon(this, groupData.filePath);
  }

  destroy() {
    return etch.destroy(this)
  }

  update({groupData, isSelected}) {
    const props = {groupData, isSelected};

    if (!_.isEqual(props, this.props)) {
      this.props = Object.assign({}, props);
      etch.update(this);
    }
  }

  writeAfterUpdate() {
    getIconServices().updateIcon(this, this.props.groupData.filePath);
  }

  render() {
    let relativePath = this.props.groupData.filePath;
    if (atom.project) {
      let rootPath;
      [rootPath, relativePath] = atom.project.relativizePath(this.props.groupData.filePath);
      if (rootPath && atom.project.getDirectories().length > 1) {
        relativePath = path.join(path.basename(rootPath), relativePath);
      }
    }
    const groupData = this.props.groupData;
    return (
      $.li(
        {
          className: [
            // This triggers the CSS displaying the "expand / collapse" arrows
            // See `styles/lists.less` in the atom-ui repository for details
            'list-nested-item',
            groupData.isCollapsed ? 'collapsed' : '',
            this.props.isSelected ? 'selected' : ''
          ].join(' ').trim(),
          key: groupData.filePath
        },
        $.div(
          {
            className: 'list-item path-row',
            dataset: { filePath: groupData.filePath }
          },
          $.span({
            dataset: {name: path.basename(groupData.filePath)},
            ref: 'icon',
            className: 'icon'
          }),
          $.span({className: 'path-name bright'}, relativePath),
          $.span(
            {ref: 'description', className: 'path-match-number'},
            `(${groupData.matchCount} match${groupData.matchCount === 1 ? '' : 'es'})`
          )
        )
      )
    )
  }
};

class MatchRowView {
  constructor({rowData, groupData, isSelected, replacePattern, regex}) {
    const props = {rowData, groupData, isSelected, replacePattern, regex};
    const previewData = {matches: rowData.matches, replacePattern, regex};

    this.props = Object.assign({}, props);
    this.previewData = previewData;
    this.previewNode = this.generatePreviewNode(previewData);

    etch.initialize(this);
  }

  update({rowData, groupData, isSelected, replacePattern, regex}) {
    const props = {rowData, groupData, isSelected, replacePattern, regex};
    const previewData = {matches: rowData.matches, replacePattern, regex};

    if (!_.isEqual(props, this.props)) {
      if (!_.isEqual(previewData, this.previewData)) {
        this.previewData = previewData;
        this.previewNode = this.generatePreviewNode(previewData);
      }
      this.props = Object.assign({}, props);
      etch.update(this);
    }
  }

  generatePreviewNode({matches, replacePattern, regex}) {
    const subnodes = [];

    let prevMatchEnd = matches[0].lineTextOffset;
    for (const match of matches) {
      const range = Range.fromObject(match.range);
      const prefixStart = Math.max(0, prevMatchEnd - match.lineTextOffset);
      const matchStart = range.start.column - match.lineTextOffset;

      // TODO - Handle case where (prevMatchEnd < match.lineTextOffset)
      // The solution probably needs Workspace.scan to be reworked to account
      // for multiple matches lines first

      const prefix = match.lineText.slice(prefixStart, matchStart);

      let replacementText = ''
      if (replacePattern && regex) {
        replacementText = match.matchText.replace(regex, replacePattern);
      } else if (replacePattern) {
        replacementText = replacePattern;
      }

      subnodes.push(
        $.span({}, prefix),
        $.span(
          {
            className:
              `match ${replacementText ? 'highlight-error' : 'highlight-info'}`
          },
          match.matchText
        ),
        $.span(
          {
            className: 'replacement highlight-success',
            style: showIf(replacementText)
          },
          replacementText
        )
      );
      prevMatchEnd = range.end.column;
    }

    const lastMatch = matches[matches.length - 1];
    const suffix = lastMatch.lineText.slice(
      prevMatchEnd - lastMatch.lineTextOffset
    );

    return $.span(
      {className: 'preview'},
      ...subnodes,
      $.span({}, suffix)
    );
  }

  render() {
    return (
      $.li(
        {
          className: [
            'list-item',
            'match-row',
            this.props.isSelected ? 'selected' : '',
            this.props.rowData.separator ? 'separator' : ''
          ].join(' ').trim(),
          dataset: {
            filePath: this.props.groupData.filePath,
            matchLineNumber: this.props.rowData.lineNumber,
          }
        },
        $.span(
          {className: 'line-number text-subtle'},
          this.props.rowData.lineNumber + 1
        ),
        this.previewNode
      )
    );
  }
};

class ContextRowView {
  constructor({rowData, groupData, isSelected}) {
    const props = {rowData, groupData, isSelected};
    this.props = Object.assign({}, props);

    etch.initialize(this);
  }

  destroy() {
    return etch.destroy(this)
  }

  update({rowData, groupData, isSelected}) {
    const props = {rowData, groupData, isSelected};

    if (!_.isEqual(props, this.props)) {
      this.props = Object.assign({}, props);
      etch.update(this);
    }
  }

  render() {
    return (
      $.li(
        {
          className: [
            'list-item',
            'context-row',
            this.props.rowData.separator ? 'separator' : ''
          ].join(' ').trim(),
          dataset: {
            filePath: this.props.groupData.filePath,
            matchLineNumber: this.props.rowData.matchLineNumber
          },
        },
        $.span({className: 'line-number text-subtle'}, this.props.rowData.lineNumber + 1),
        $.span({className: 'preview'}, $.span({}, this.props.rowData.line))
      )
    )
  }
}

function getRowViewType(row) {
  if (row instanceof ResultPathRow) {
    return ResultPathRowView;
  }
  if (row instanceof MatchRow) {
    return MatchRowView;
  }
  if (row instanceof LeadingContextRow) {
    return ContextRowView;
  }
  if (row instanceof TrailingContextRow) {
    return ContextRowView;
  }
  assert(false);
}

module.exports =
class ResultRowView {
  constructor({item}) {
    const props = {
      rowData: Object.assign({}, item.row.data),
      groupData: Object.assign({}, item.row.group.data),
      isSelected: item.isSelected,
      replacePattern: item.replacePattern,
      regex: item.regex
    };
    this.props = props;
    this.rowViewType = getRowViewType(item.row);

    etch.initialize(this);
  }

  destroy() {
    return etch.destroy(this);
  }

  update({item}) {
    const props = {
      rowData: Object.assign({}, item.row.data),
      groupData: Object.assign({}, item.row.group.data),
      isSelected: item.isSelected,
      replacePattern: item.replacePattern,
      regex: item.regex
    }
    this.props = props;
    this.rowViewType = getRowViewType(item.row);
    etch.update(this);
  }

  render() {
    return $(this.rowViewType, this.props);
  }
};
