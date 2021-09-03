// const log = console.debug // in dev
const log = () => {}; // in production

module.exports = class TreeIndenter {
  constructor(languageMode, scopes = undefined) {
    this.languageMode = languageMode;
    this.scopes =
      scopes ||
      languageMode.config.get('editor.scopes', {
        scope: this.languageMode.rootScopeDescriptor
      });
    log('[TreeIndenter] constructor', this.scopes);
  }

  /** tree indenter is configured for this language */
  get isConfigured() {
    return !!this.scopes;
  }

  // Given a position, walk up the syntax tree, to find the highest level
  // node that still starts here. This is to identify the column where this
  // node (e.g., an HTML closing tag) ends.
  _getHighestSyntaxNodeAtPosition(row, column = null) {
    if (column == null) {
      // Find the first character on the row that is not whitespace + 1
      column = this.languageMode.buffer.lineForRow(row).search(/\S/);
    }

    let syntaxNode;
    if (column >= 0) {
      syntaxNode = this.languageMode.getSyntaxNodeAtPosition({ row, column });
      while (
        syntaxNode &&
        syntaxNode.parent &&
        syntaxNode.parent.startPosition.row === syntaxNode.startPosition.row &&
        syntaxNode.parent.endPosition.row === syntaxNode.startPosition.row &&
        syntaxNode.parent.startPosition.column ===
          syntaxNode.startPosition.column
      ) {
        syntaxNode = syntaxNode.parent;
      }
      return syntaxNode;
    }
  }

  /** Walk up the tree. Everytime we meet a scope type, check whether we
    are coming from the first (resp. last) child. If so, we are opening
    (resp. closing) that scope, i.e., do not count it. Otherwise, add 1.

    This is the core function.

    It might make more sense to reverse the direction of this walk, i.e.,
    go from root to leaf instead.
  */
  _treeWalk(node, lastScope = null) {
    if (node == null || node.parent == null) {
      return 0;
    } else {
      let increment = 0;

      const notFirstOrLastSibling =
        node.previousSibling != null && node.nextSibling != null;

      const isScope = this.scopes.indent[node.parent.type];
      notFirstOrLastSibling && isScope && increment++;

      const isScope2 = this.scopes.indentExceptFirst[node.parent.type];
      !increment && isScope2 && node.previousSibling != null && increment++;

      const isScope3 = this.scopes.indentExceptFirstOrBlock[node.parent.type];
      !increment && isScope3 && node.previousSibling != null && increment++;

      // apply current row, single line, type-based rules, e.g., 'else' or 'private:'
      let typeDent = 0;
      this.scopes.types.indent[node.type] && typeDent++;
      this.scopes.types.outdent[node.type] && increment && typeDent--;
      increment += typeDent;

      // check whether the last (lower) indentation happened due to a scope that
      // started on the same row and ends directly before this.
      if (
        lastScope &&
        increment > 0 &&
        // previous (lower) scope was a two-sided scope, reduce if starts on
        // same row and ends right before
        // TODO: this currently only works for scopes that have a single-character
        // closing delimiter (like statement_blocks, but not HTML, for instance).
        ((node.parent.startPosition.row === lastScope.node.startPosition.row &&
          node.parent.endIndex <= lastScope.node.endIndex + 1) ||
          // or this is a special scope (like if, while) and it's ends coincide
          (isScope3 &&
            (lastScope.node.endIndex === node.endIndex ||
              node.parent.endIndex === node.endIndex)))
      ) {
        log('ignoring repeat', node.parent.type, lastScope);
        increment = 0;
      } else {
        lastScope &&
          log(
            node.parent.startPosition.row,
            lastScope.node.startPosition.row,
            node.parent.endIndex,
            lastScope.node.endIndex,
            isScope3,
            node.endIndex
          );
      }

      log('treewalk', {
        node,
        notFirstOrLastSibling,
        type: node.parent.type,
        increment
      });
      const newLastScope =
        isScope || isScope2 ? { node: node.parent } : lastScope;
      return this._treeWalk(node.parent, newLastScope) + increment;
    }
  }

  suggestedIndentForBufferRow(row, tabLength, options) {
    // get current indentation for row
    const line = this.languageMode.buffer.lineForRow(row);
    const currentIndentation = this.languageMode.indentLevelForLine(
      line,
      tabLength
    );

    const syntaxNode = this._getHighestSyntaxNodeAtPosition(row);
    if (!syntaxNode) {
      const previousRow = Math.max(row - 1, 0);
      const previousIndentation = this.languageMode.indentLevelForLine(
        this.languageMode.indentLevelForLine(previousRow),
        tabLength
      );
      return previousIndentation;
    }
    let indentation = this._treeWalk(syntaxNode);

    // Special case for comments
    if (
      (syntaxNode.type === 'comment' || syntaxNode.type === 'description') &&
      syntaxNode.startPosition.row < row &&
      syntaxNode.endPosition.row > row
    ) {
      indentation += 1;
    }

    if (options && options.preserveLeadingWhitespace) {
      indentation -= currentIndentation;
    }

    return indentation;
  }
};
