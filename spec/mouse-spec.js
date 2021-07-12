const { conditionPromise } = require('./async-spec-helpers');

const Random = require('../script/node_modules/random-seed');
const { getRandomBufferRange, buildRandomLines } = require('./helpers/random');
const TextEditorComponent = require('../src/text-editor-component');
const TextEditorElement = require('../src/text-editor-element');
const TextEditor = require('../src/text-editor');
const TextBuffer = require('text-buffer');
const { Point } = TextBuffer;
const fs = require('fs');
const path = require('path');
const Grim = require('grim');
const electron = require('electron');
const clipboard = electron.clipboard;

const SAMPLE_TEXT = fs.readFileSync(
  path.join(__dirname, 'fixtures', 'sample2.js'),
  'utf8'
);

document.registerElement('text-editor-component-test-element', {
  prototype: Object.create(HTMLElement.prototype, {
    attachedCallback: {
      value: function() {
        this.didAttach();
      }
    }
  })
});

const editors = [];
let verticalScrollbarWidth, horizontalScrollbarHeight;






describe('TextEditorComponent', () => {
    beforeEach(() => {
      jasmine.useRealClock();
  
      // Force scrollbars to be visible regardless of local system configuration
      const scrollbarStyle = document.createElement('style');
      scrollbarStyle.textContent =
        'atom-text-editor ::-webkit-scrollbar { -webkit-appearance: none }';
      jasmine.attachToDOM(scrollbarStyle);
  
      if (verticalScrollbarWidth == null) {
        const { component, element } = buildComponent({
          text: 'abcdefgh\n'.repeat(10),
          width: 30,
          height: 30
        });
        verticalScrollbarWidth = getVerticalScrollbarWidth(component);
        horizontalScrollbarHeight = getHorizontalScrollbarHeight(component);
        element.remove();
      }
    });
  
    afterEach(() => {
      for (const editor of editors) {
        editor.destroy();
      }
      editors.length = 0;
    });
  
    describe('mouse input', () => {
        describe('on the lines', () => {
        describe('when there is only one cursor', () => {
            it('positions the cursor on single-click or when middle-clicking', async () => {
            for (const button of [0, 1]) {
                const { component, editor } = buildComponent();
                const { lineHeight } = component.measurements;

                editor.setCursorScreenPosition([Infinity, Infinity], {
                autoscroll: false
                });
                component.didMouseDownOnContent({
                detail: 1,
                button,
                clientX: clientLeftForCharacter(component, 0, 0) - 1,
                clientY: clientTopForLine(component, 0) - 1
                });
                expect(editor.getCursorScreenPosition()).toEqual([0, 0]);

                const maxRow = editor.getLastScreenRow();
                editor.setCursorScreenPosition([Infinity, Infinity], {
                autoscroll: false
                });
                component.didMouseDownOnContent({
                detail: 1,
                button,
                clientX:
                    clientLeftForCharacter(
                    component,
                    maxRow,
                    editor.lineLengthForScreenRow(maxRow)
                    ) + 1,
                clientY: clientTopForLine(component, maxRow) + 1
                });
                expect(editor.getCursorScreenPosition()).toEqual([
                maxRow,
                editor.lineLengthForScreenRow(maxRow)
                ]);

                component.didMouseDownOnContent({
                detail: 1,
                button,
                clientX:
                    clientLeftForCharacter(
                    component,
                    0,
                    editor.lineLengthForScreenRow(0)
                    ) + 1,
                clientY: clientTopForLine(component, 0) + lineHeight / 2
                });
                expect(editor.getCursorScreenPosition()).toEqual([
                0,
                editor.lineLengthForScreenRow(0)
                ]);

                component.didMouseDownOnContent({
                detail: 1,
                button,
                clientX:
                    (clientLeftForCharacter(component, 3, 0) +
                    clientLeftForCharacter(component, 3, 1)) /
                    2,
                clientY: clientTopForLine(component, 1) + lineHeight / 2
                });
                expect(editor.getCursorScreenPosition()).toEqual([1, 0]);

                component.didMouseDownOnContent({
                detail: 1,
                button,
                clientX:
                    (clientLeftForCharacter(component, 3, 14) +
                    clientLeftForCharacter(component, 3, 15)) /
                    2,
                clientY: clientTopForLine(component, 3) + lineHeight / 2
                });
                expect(editor.getCursorScreenPosition()).toEqual([3, 14]);

                component.didMouseDownOnContent({
                detail: 1,
                button,
                clientX:
                    (clientLeftForCharacter(component, 3, 14) +
                    clientLeftForCharacter(component, 3, 15)) /
                    2 +
                    1,
                clientY: clientTopForLine(component, 3) + lineHeight / 2
                });
                expect(editor.getCursorScreenPosition()).toEqual([3, 15]);

                editor.getBuffer().setTextInRange([[3, 14], [3, 15]], '🐣');
                await component.getNextUpdatePromise();

                component.didMouseDownOnContent({
                detail: 1,
                button,
                clientX:
                    (clientLeftForCharacter(component, 3, 14) +
                    clientLeftForCharacter(component, 3, 16)) /
                    2,
                clientY: clientTopForLine(component, 3) + lineHeight / 2
                });
                expect(editor.getCursorScreenPosition()).toEqual([3, 14]);

                component.didMouseDownOnContent({
                detail: 1,
                button,
                clientX:
                    (clientLeftForCharacter(component, 3, 14) +
                    clientLeftForCharacter(component, 3, 16)) /
                    2 +
                    1,
                clientY: clientTopForLine(component, 3) + lineHeight / 2
                });
                expect(editor.getCursorScreenPosition()).toEqual([3, 16]);

                expect(editor.testAutoscrollRequests).toEqual([]);
            }
            });
        });

        

  


        });

    });
});




//// helper 
// todo: check 


function buildEditor(params = {}) {
    const text = params.text != null ? params.text : SAMPLE_TEXT;
    const buffer = new TextBuffer({ text });
    const editorParams = { buffer, readOnly: params.readOnly };
    if (params.height != null) params.autoHeight = false;
    for (const paramName of [
      'mini',
      'autoHeight',
      'autoWidth',
      'lineNumberGutterVisible',
      'showLineNumbers',
      'placeholderText',
      'softWrapped',
      'scrollSensitivity'
    ]) {
      if (params[paramName] != null) editorParams[paramName] = params[paramName];
    }
    atom.grammars.autoAssignLanguageMode(buffer);
    const editor = new TextEditor(editorParams);
    editor.testAutoscrollRequests = [];
    editor.onDidRequestAutoscroll(request => {
      editor.testAutoscrollRequests.push(request);
    });
    editors.push(editor);
    return editor;
  }
  
  function buildComponent(params = {}) {
    const editor = params.editor || buildEditor(params);
    const component = new TextEditorComponent({
      model: editor,
      rowsPerTile: params.rowsPerTile,
      updatedSynchronously: params.updatedSynchronously || false,
      platform: params.platform,
      chromeVersion: params.chromeVersion
    });
    const { element } = component;
    if (!editor.getAutoHeight()) {
      element.style.height = params.height ? params.height + 'px' : '600px';
    }
    if (!editor.getAutoWidth()) {
      element.style.width = params.width ? params.width + 'px' : '800px';
    }
    if (params.attach !== false) jasmine.attachToDOM(element);
    return { component, element, editor };
  }
  
  function getEditorWidthInBaseCharacters(component) {
    return Math.round(
      component.getScrollContainerWidth() / component.getBaseCharacterWidth()
    );
  }
  
  async function setEditorHeightInLines(component, heightInLines) {
    component.element.style.height =
      component.getLineHeight() * heightInLines + 'px';
    await component.getNextUpdatePromise();
  }
  
  async function setEditorWidthInCharacters(component, widthInCharacters) {
    component.element.style.width =
      component.getGutterContainerWidth() +
      widthInCharacters * component.measurements.baseCharacterWidth +
      verticalScrollbarWidth +
      'px';
    await component.getNextUpdatePromise();
  }
  
  function verifyCursorPosition(component, cursorNode, row, column) {
    const rect = cursorNode.getBoundingClientRect();
    expect(Math.round(rect.top)).toBe(clientTopForLine(component, row));
    expect(Math.round(rect.left)).toBe(
      Math.round(clientLeftForCharacter(component, row, column))
    );
  }
  
  function clientTopForLine(component, row) {
    return lineNodeForScreenRow(component, row).getBoundingClientRect().top;
  }
  
  function clientLeftForCharacter(component, row, column) {
    const textNodes = textNodesForScreenRow(component, row);
    let textNodeStartColumn = 0;
    for (const textNode of textNodes) {
      const textNodeEndColumn = textNodeStartColumn + textNode.textContent.length;
      if (column < textNodeEndColumn) {
        const range = document.createRange();
        range.setStart(textNode, column - textNodeStartColumn);
        range.setEnd(textNode, column - textNodeStartColumn);
        return range.getBoundingClientRect().left;
      }
      textNodeStartColumn = textNodeEndColumn;
    }
  
    const lastTextNode = textNodes[textNodes.length - 1];
    const range = document.createRange();
    range.setStart(lastTextNode, 0);
    range.setEnd(lastTextNode, lastTextNode.textContent.length);
    return range.getBoundingClientRect().right;
  }
  
  function clientPositionForCharacter(component, row, column) {
    return {
      clientX: clientLeftForCharacter(component, row, column),
      clientY: clientTopForLine(component, row)
    };
  }
  
  function lineNumberNodeForScreenRow(component, row) {
    const gutterElement =
      component.refs.gutterContainer.refs.lineNumberGutter.element;
    const tileStartRow = component.tileStartRowForRow(row);
    const tileIndex = component.renderedTileStartRows.indexOf(tileStartRow);
    return gutterElement.children[tileIndex + 1].children[row - tileStartRow];
  }
  
  function lineNodeForScreenRow(component, row) {
    const renderedScreenLine = component.renderedScreenLineForRow(row);
    return component.lineComponentsByScreenLineId.get(renderedScreenLine.id)
      .element;
  }
  
  function textNodesForScreenRow(component, row) {
    const screenLine = component.renderedScreenLineForRow(row);
    return component.lineComponentsByScreenLineId.get(screenLine.id).textNodes;
  }
  
  function setScrollTop(component, scrollTop) {
    component.setScrollTop(scrollTop);
    component.scheduleUpdate();
    return component.getNextUpdatePromise();
  }
  
  function setScrollLeft(component, scrollLeft) {
    component.setScrollLeft(scrollLeft);
    component.scheduleUpdate();
    return component.getNextUpdatePromise();
  }
  
  function getHorizontalScrollbarHeight(component) {
    const element = component.refs.horizontalScrollbar.element;
    return element.offsetHeight - element.clientHeight;
  }
  
  function getVerticalScrollbarWidth(component) {
    const element = component.refs.verticalScrollbar.element;
    return element.offsetWidth - element.clientWidth;
  }
  
  function assertDocumentFocused() {
    if (!document.hasFocus()) {
      throw new Error('The document needs to be focused to run this test');
    }
  }
  
  function getElementHeight(element) {
    const topRuler = document.createElement('div');
    const bottomRuler = document.createElement('div');
    let height;
    if (document.body.contains(element)) {
      element.parentElement.insertBefore(topRuler, element);
      element.parentElement.insertBefore(bottomRuler, element.nextSibling);
      height = bottomRuler.offsetTop - topRuler.offsetTop;
    } else {
      jasmine.attachToDOM(topRuler);
      jasmine.attachToDOM(element);
      jasmine.attachToDOM(bottomRuler);
      height = bottomRuler.offsetTop - topRuler.offsetTop;
      element.remove();
    }
  
    topRuler.remove();
    bottomRuler.remove();
    return height;
  }
  
  function queryOnScreenLineNumberElements(element) {
    return Array.from(element.querySelectorAll('.line-number:not(.dummy)'));
  }
  
  function queryOnScreenLineElements(element) {
    return Array.from(
      element.querySelectorAll('.line:not(.dummy):not([data-off-screen])')
    );
  }
  