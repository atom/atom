const fs = require('fs');
const path = require('path');
const TreeSitterGrammar = require('../src/tree-sitter-grammar');
const TreeSitterLanguageMode = require('../src/tree-sitter-language-mode');
const TreeIndenter = require('../src/tree-indenter');

const jsGrammarPath = require.resolve(
  'language-javascript/grammars/tree-sitter-javascript.cson'
);

const TAB_LENGTH = 2;

const jsScopes = {
  indent: {
    array: true,
    object: true,
    arguments: true,
    statement_block: true,
    class_body: true,
    parenthesized_expression: true,
    jsx_element: true,
    jsx_opening_element: true,
    jsx_expression: true,
    switch_body: true,
    comment: true
  },
  indentExceptFirst: {
    member_expression: true,
    assignment_expression: true,
    expression_statement: true,
    variable_declarator: true,
    lexical_declaration: true,
    binary_expression: true,
    jsx_self_closing_element: true
  },
  indentExceptFirstOrBlock: {
    if_statement: true,
    while_statement: true
  },
  types: {
    indent: {},
    outdent: {
      else: true
    }
  }
};

describe('TreeIndenter', () => {
  let editor, buffer, grammar;
  let languageMode, treeIndenter;

  beforeEach(async () => {
    editor = await atom.workspace.open('');
    buffer = editor.getBuffer();
    editor.displayLayer.reset({ foldCharacter: '…' });

    grammar = new TreeSitterGrammar(atom.grammars, jsGrammarPath, {
      parser: 'tree-sitter-javascript'
    });
  });

  /** load a file from disk and verify that our proposed indentation
  is the same as it is in the file */
  function compareFile(filename) {
    const text = fs.readFileSync(filename);
    buffer.setText(text);
    languageMode = new TreeSitterLanguageMode({ buffer, grammar });
    treeIndenter = new TreeIndenter(languageMode, jsScopes);

    for (let row = 0; row < buffer.getLineCount(); row++) {
      // get current (correct) indentation
      const line = buffer.lineForRow(row);
      const currentIndentation = languageMode.indentLevelForLine(
        line,
        TAB_LENGTH
      );

      // get suggested indentation
      const indent = treeIndenter.suggestedIndentForBufferRow(
        row,
        TAB_LENGTH,
        {}
      );

      // verify
      if (indent !== currentIndentation) {
        throw Error(
          `failure in file row ${row +
            1}: suggested ${indent} but ${currentIndentation} is correct (${line})`
        );
      } else {
        expect(indent).toEqual(currentIndentation);
      }
    }
  }

  describe('indentation', () => {
    it('indents wrongly indented lines', () => {
      buffer.setText(`if (true) {
        a = {a: [
        1,
        'something'
        ],
        b: 2}
        }`);
      const correct = [0, 1, 3, 3, 2, 2, 0];
      languageMode = new TreeSitterLanguageMode({ buffer, grammar });
      treeIndenter = new TreeIndenter(languageMode, jsScopes);

      for (let row = 0; row < buffer.getLineCount(); row++) {
        // get suggested indentation
        const indent = treeIndenter.suggestedIndentForBufferRow(
          row,
          TAB_LENGTH,
          {}
        );

        // verify
        if (indent !== correct[row]) {
          const line = buffer.lineForRow(row).trim();
          throw Error(
            `failure in row ${row}: suggested ${indent} but ${
              correct[row]
            } is correct (${line})`
          );
        } else {
          expect(indent).toEqual(correct[row]);
        }
      }
    });

    const fixtures = fs.readdirSync(
      path.join(__dirname, 'fixtures', 'indentation')
    );

    fixtures.forEach(filename => {
      it(`suggests correct indentations for ${filename}`, () => {
        compareFile(path.join(__dirname, 'fixtures', 'indentation', filename));
      });
    });
  });
});
