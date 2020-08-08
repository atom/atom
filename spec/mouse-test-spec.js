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

    describe('mouse input' , ()=>{
        


        describe('when there is only one cursor' , ()=>{
            describe('when the first line is clicked' , ()=>{
                it('position the cursor on the clicked char betwen two RTL in the first line', ()=>{
                    editor = setMouseAtPositionAndClick(0,4) ; 
                    expect(editor.getCursorScreenPosition()).toEqual([0, 4]);
                    
                    editor = setMouseAtPositionAndClick(0,2) ; 
                    expect(editor.getCursorScreenPosition()).toEqual([0, 2]);
                    
                    editor = setMouseAtPositionAndClick(0,10) ; 
                    expect(editor.getCursorScreenPosition()).toEqual([0, 10]);
                });
            });

            describe('when  any line is clicked' , ()=>{
                it('position the cursor on the clicked char betwen two RTL in the first line', ()=>{
                    editor = setMouseAtPositionAndClick(3,4) ; 
                    expect(editor.getCursorScreenPosition()).toEqual([3, 4]);
                    
                    editor = setMouseAtPositionAndClick(12,14) ; 
                    expect(editor.getCursorScreenPosition()).toEqual([12, 14]);
                    
                    editor = setMouseAtPositionAndClick(13,4) ; 
                    expect(editor.getCursorScreenPosition()).toEqual([13, 4]);
                    
                });

                describe('when the clicked position is after the end of the line' , ()=>{
                    it('position the cursor at the end of line' , ()=>{
                        editor = setMouseAtPositionAndClick(7,90) ; 
                        lineLength = lineLength(7)  ; 
                        expect(editor.getCursorScreenPosition()).toEqual([7, lineLength]);

                        editor = setMouseAtPositionAndClick(11,90) ; 
                        lineLength = lineLength(11)  ; 
                        expect(editor.getCursorScreenPosition()).toEqual([11, lineLength]);
                    });
                });
            });

            describe('when the clicked line is mixed RTL and LTR' , ()=>{
                describe('when the clicked char is RTL ' , ()=>{
                    describe('when the position is between RTL word' , ()=>{
                        it('position the cursor on the clicked char', ()=>{
                            editor = setMouseAtPositionAndClick(6,4) ; 
                            expect(editor.getCursorScreenPosition()).toEqual([6, 4]);
                            
                        });

                        it('position the cursor on the clicked char', ()=>{
                            editor = setMouseAtPositionAndClick(6,5) ; 
                            expect(editor.getCursorScreenPosition()).toEqual([6, 5]);
                            
                        });

                        it('position the cursor on the clicked char', ()=>{
                            editor = setMouseAtPositionAndClick(6,7) ; 
                            expect(editor.getCursorScreenPosition()).toEqual([6, 7]);
                            
                        });
                    });
                    describe('when the clicked position is befor the first char of RTL word(beginning of the line)' , ()=>{
                        it('position the cursor on the clicked char ' , ()=>{
                            editor = setMouseAtPositionAndClick(6,0) ; 
                            expect(editor.getCursorScreenPosition()).toEqual([6, 0]);
                        });
                    });
                    
                    describe('when the clicked position is after the first char of RTL word' , ()=>{
                        it('position the cursor on the clicked char ' , ()=>{
                            editor = setMouseAtPositionAndClick(6,1) ; 
                            expect(editor.getCursorScreenPosition()).toEqual([6, 1]);
                        });
                    });

                    describe('when the clicked position is after the second char of RTL word' , ()=>{
                        it('position the cursor on the clicked char ' , ()=>{
                            editor = setMouseAtPositionAndClick(6,2) ; 
                            expect(editor.getCursorScreenPosition()).toEqual([6, 2]);
                        });
                    });

                    describe('when the clicked position is after the third char of RTL word' , ()=>{
                        it('position the cursor on the clicked char  (the space problem )' , ()=>{
                            editor = setMouseAtPositionAndClick(6,3) ; 
                            expect(editor.getCursorScreenPosition()).toEqual([6, 3]);
                        });
                    });

                    describe('when the clicked position is after the fourth char of RTL word' , ()=>{
                        it('position the cursor on the clicked char ' , ()=>{
                            editor = setMouseAtPositionAndClick(6,4) ; 
                            expect(editor.getCursorScreenPosition()).toEqual([6, 4]);
                        });
                    });
                });

                describe('when the clicked char is LTR ' , ()=>{
                    describe('when the clicked position is before the first char of LTR word' , ()=>{
                        it('position the cursor on the clicked char', ()=>{
                            editor = setMouseAtPositionAndClick(6,9) ; 
                            expect(editor.getCursorScreenPosition()).toEqual([6, 9]);
                            
                        });
                    });
                    describe('when the clicked positoin is the first part of the LTE word' , ()=>{

                        describe('when the clicked position is after the first char of LTR word' , ()=>{
                            it('position the cursor on the clicked char', ()=>{
                                editor = setMouseAtPositionAndClick(6,10) ; 
                                expect(editor.getCursorScreenPosition()).toEqual([6, 10]);
                                
                            });
                        });
                        describe('when the clicked position is after the second char of LTR word' , ()=>{
                            it('position the cursor on the clicked char', ()=>{
                                editor = setMouseAtPositionAndClick(6,11) ; 
                                expect(editor.getCursorScreenPosition()).toEqual([6, 11]);
                                
                            });
                        });
                        describe('when the clicked position is after the third char of LTR word' , ()=>{
                            it('position the cursor on the clicked char', ()=>{
                                editor = setMouseAtPositionAndClick(6,12) ; 
                                expect(editor.getCursorScreenPosition()).toEqual([6, 12]);
                                
                            });
                        });

                        describe('when the clicked position is after the fourth char of LTR word' , ()=>{
                            it('position the cursor on the clicked char', ()=>{
                                editor = setMouseAtPositionAndClick(6,13) ; 
                                expect(editor.getCursorScreenPosition()).toEqual([6, 13]);
                                
                            });
                        });
                    });
                });

                describe('when the clicked position is after the end of the line' , ()=>{
                    it('position the cursor at the end of line' , ()=>{
                        editor = setMouseAtPositionAndClick(6,90) ; 
                        lineLength = lineLength(6)  ; 
                        expect(editor.getCursorScreenPosition()).toEqual([6, lineLength]);
                    });
                });
            });

            describe('when the clicked position is after entire text' , ()=>{
                it('position the cursor at the end of the file' , ()=>{
                    lineLength = lineLength(indexOftheLastLine()) ; 
                    editor = setMouseAtPositionAndClick(indexOftheLastLine(),lineLength+90) ; 
                    expect(editor.getCursorScreenPosition()).toEqual([indexOftheLastLine(), lineLength]);
                })
            });
        }); 
    }); 

}); 

function indexOftheLastLine(){
    const { component, editor } = buildComponent();
    return editor.getBuffer().getLastRow() ; 
}

function lineLength(row){
    const { component, editor } = buildComponent();

    return  editor.getBuffer().lineForRow(6).length ; 
    
}

function setMouseAtPositionAndClick(row , column){
    const { component, editor } = buildComponent();
    const { lineHeight } = component.measurements;

    editor.setCursorScreenPosition([Infinity, Infinity], {
    autoscroll: false
    });
    component.didMouseDownOnContent({
        detail: 1,
        button : 0,
        clientX: clientLeftForCharacter(component, row, column) ,
        clientY: clientTopForLine(component, row) 
    });

    return editor ; 
}




//// helper -----------------------------
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
        return range.getBoundingClientRect().left -1;
      }
      textNodeStartColumn = textNodeEndColumn;
    }
  
    const lastTextNode = textNodes[textNodes.length - 1];
    const range = document.createRange();
    range.setStart(lastTextNode, 0);
    range.setEnd(lastTextNode, lastTextNode.textContent.length);
    return range.getBoundingClientRect().left -1;
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
  