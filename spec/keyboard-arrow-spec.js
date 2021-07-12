const fs = require('fs');
const path = require('path');
const temp = require('temp').track();
const dedent = require('dedent');
const { clipboard } = require('electron');
const TextEditor = require('../src/text-editor');
const TextBuffer = require('text-buffer');
const TextMateLanguageMode = require('../src/text-mate-language-mode');
const TreeSitterLanguageMode = require('../src/tree-sitter-language-mode');

describe('TextEditor', () => {
  let buffer, editor, lineLengths , numberOfLines;

  beforeEach(async () => {
    editor = await atom.workspace.open('sample2.js');
    buffer = editor.buffer;
    editor.update({ autoIndent: false });
    lineLengths = buffer.getLines().map(line => line.length);
    numberOfLines = lineLengths.length ; 
    await atom.packages.activatePackage('language-javascript');
  });

  //console.log('editor : ' , editor) ; 
  it('generates unique ids for each editor', async () => {
    // Deserialized editors are initialized with the serialized id. We can
    // initialize an editor with what we expect to be the next id:
    const deserialized = new TextEditor({ id: editor.id + 1 });
    expect(deserialized.id).toEqual(editor.id + 1);

    // The id generator should skip the id used up by the deserialized one:
    const fresh = new TextEditor();
    expect(fresh.id).toNotEqual(deserialized.id);
  });


  



    describe('cursor', () => {
        describe('.moveLeft()', () => {
            it('moves the cursor by one column to the left', () => {
              editor.setCursorScreenPosition([1, 8]);
              editor.moveLeft();
              expect(editor.getCursorScreenPosition()).toEqual([1, 9]);
            });

            it('moves the cursor by n columns to the left', () => {
                editor.setCursorScreenPosition([1, 8]);
                editor.moveLeft(4);
                expect(editor.getCursorScreenPosition()).toEqual([1, 12]);
            });
            it('moves the cursor to the beggining of the next line when the column is at the end of the line ', () => {
                editor.setCursorScreenPosition([1, lineLengths[1]]);
                editor.moveLeft();
                expect(editor.getCursorScreenPosition()).toEqual([2, 0]);
            });

            it('moves the cursor to the beggining of the next line when the columnCount is equals to the length of the current line and the currsor is at the begginging of the current line ', () => {
                editor.setCursorScreenPosition([0, 0]);
                editor.moveLeft(lineLengths[0]+1);
                expect(editor.getCursorScreenPosition()).toEqual([1, 0]);
            });
            
            it('moves the cursor to the beggining of the third line when the columnCount is equals to the length of the current line + the length of the next line and the currsor is at the begginging of the current line ', () => {
                editor.setCursorScreenPosition([0, 0]);
                editor.moveLeft(lineLengths[0]+lineLengths[1]+2);
                expect(editor.getCursorScreenPosition()).toEqual([2, 0]);
            });
            
            it('moves the cursor to the end of the file when columnCount is more than the entire text', () => {
                editor.setCursorScreenPosition([numberOfLines-1, 0]);
                editor.moveLeft(3000);
                expect(editor.getCursorScreenPosition()).toEqual([numberOfLines-1, lineLengths[numberOfLines-1]]);
            });

            describe('when the next line is empty and the cursor at the end of the line' , ()=>{
                it('moves the cursor to the beginning of the empty line' , ()=>{
                    editor.setCursorScreenPosition([7, lineLengths[7]]);
                    editor.moveLeft() ; 
                    expect(editor.getCursorScreenPosition()).toEqual([8,0]) ; 
                }); 
                it('moves the cursor to the beginning of the empty line and column count 2 ' , ()=>{
                    editor.setCursorScreenPosition([7, lineLengths[7]]);
                    editor.moveLeft(2) ; 
                    expect(editor.getCursorScreenPosition()).toEqual([9,0]) ; 
                }); 
            }); 
            // RTL and LTR in the same line 
            describe(' in RTL and LTR line ' , ()=>{
                it('moves the cursor to the beggining of the LTR word when the current char is RTL and next char is LTR' , ()=>{
                    editor.setCursorScreenPosition([6, 9]);
                    editor.moveLeft();
                    expect(editor.getCursorScreenPosition()).toEqual([6, 10]);
                });

                it('moves the cursor to the left (column--) when the cursor is between LTR word' , ()=>{
                    editor.setCursorScreenPosition([6, 12]);
                    editor.moveLeft();
                    expect(editor.getCursorScreenPosition()).toEqual([6, 11]);
                });

                it('moves the cursor to the left (column-=3) when the cursor is between LTR word' , ()=>{
                    editor.setCursorScreenPosition([6, 15]);
                    editor.moveLeft(3);
                    expect(editor.getCursorScreenPosition()).toEqual([6, 12]);
                });

                it('moves the cursor to the end of the previous RTL word when the the cursor is on the beginning of the LTR word' , ()=>{
                    editor.setCursorScreenPosition([6, 10]);
                    editor.moveLeft();
                    expect(editor.getCursorScreenPosition()).toEqual([6, 9]);
                });
            }); 

            describe('when the currsor at the end of the file' , ()=>{
                it('remain in the same position' , ()=>{
                    editor.setCursorScreenPosition([numberOfLines-1, lineLengths[numberOfLines-1]]);
                    editor.moveLeft();
                    expect(editor.getCursorScreenPosition()).toEqual([numberOfLines-1, lineLengths[numberOfLines-1]]);
                });
            });
        });




        ///// right 

        describe('.moveRight()', () => {
            it('moves the cursor by one column to the right', () => {
              editor.setCursorScreenPosition([1, 8]);
              editor.moveRight();
              expect(editor.getCursorScreenPosition()).toEqual([1, 7]);
            });
            it('moves the cursor by n columns to the right', () => {
                editor.setCursorScreenPosition([1, 8]);
                editor.moveRight(4);
                expect(editor.getCursorScreenPosition()).toEqual([1, 4]);
            });
            describe('when the column is at the beginning of the line' , ()=>{
                it('moves to the end of the previous line ' , ()=>{
                    editor.setCursorScreenPosition([1, 0]);
                    editor.moveRight();
                    expect(editor.getCursorScreenPosition()).toEqual([0, lineLengths[0]]);
                });
            });
            describe('when the columncount equals to the length of the line and we are at the end of hte line ' , ()=>{
                it('moves to the beginning of the line' , ()=>{
                    editor.setCursorScreenPosition([1, lineLengths[1]]);
                    editor.moveRight(lineLengths[1]);
                    expect(editor.getCursorScreenPosition()).toEqual([1, 0]);
                })
            });
            
            describe('when column count current length + previous length+2 and the cursor is at the end of the line ' , ()=>{
                it('move to the end of the i-2 line ', ()=>{
                    editor.setCursorScreenPosition([3, lineLengths[3]]);
                    editor.moveRight(lineLengths[3]+lineLengths[2]+2);
                    expect(editor.getCursorScreenPosition()).toEqual([1, lineLengths[1]]);
                })
            }); 

            describe('when column count > then the previous text' , ()=>{
                it('move to the beginning of the file' , ()=>{
                    editor.setCursorScreenPosition([1,10 ]);
                    editor.moveRight(300);
                    expect(editor.getCursorScreenPosition()).toEqual([0, 0]);
                })
            })

            describe('when the previous line is empty' , ()=>{
                it('move to the empty line when we move one right' ,()=>{
                    editor.setCursorScreenPosition([9, 0]);
                    editor.moveRight();
                    expect(editor.getCursorScreenPosition()).toEqual([8, 0]);
                }); 
                it('move to the end of i-2 line when we move two right' ,()=>{
                    editor.setCursorScreenPosition([9, 0]);
                    editor.moveRight(2);
                    expect(editor.getCursorScreenPosition()).toEqual([7, lineLengths[7]]);
                }); 
            });
            // RTL and LTR in the same line 
            describe(' in RTL and LTR line ' , ()=>{
                describe('when the cursor is at the beginning of the LTR word' , ()=>{
                    it('moves the cursor to the right (column++)' , ()=>{
                        editor.setCursorScreenPosition([6, 10]);
                        editor.moveRight();
                        expect(editor.getCursorScreenPosition()).toEqual([6, 11]);
                    })
                });

                describe('when the cursor is at the end of the RTL word' , ()=>{
                    it('moves the cursor to the right (column--)' , ()=>{
                        editor.setCursorScreenPosition([6, 9]);
                        editor.moveRight();
                        expect(editor.getCursorScreenPosition()).toEqual([6, 8]);
                    })
                });

                describe('when the cursor is between LTR word' , ()=>{
                    it('moves the cursor to the right (column++)' , ()=>{
                        editor.setCursorScreenPosition([6, 12]);
                        editor.moveRight();
                        expect(editor.getCursorScreenPosition()).toEqual([6, 13]);
                    })
                });
                
                describe('when the cursor is between LTR word' , ()=>{
                    it('moves the cursor to the right (column+=3) when column count =3' , ()=>{
                        editor.setCursorScreenPosition([6, 12]);
                        editor.moveRight(3);
                        expect(editor.getCursorScreenPosition()).toEqual([6, 15]);
                    })
                });
                describe('when the cursor is between RTL word' , ()=>{
                    it('moves the cursor to the right (column--)' , ()=>{
                        editor.setCursorScreenPosition([6, 5]);
                        editor.moveRight();
                        expect(editor.getCursorScreenPosition()).toEqual([6, 4]);
                    })
                });
                describe('when the cursor is between RTL word' , ()=>{
                    it('moves the cursor to the right (column-=3) when column count=3' , ()=>{
                        editor.setCursorScreenPosition([6, 5]);
                        editor.moveRight(3);
                        expect(editor.getCursorScreenPosition()).toEqual([6, 2]);
                    })
                });

                describe('when the cursor is at the beginning of the next line' , ()=>{
                    it('moves the cursor to the end of the previous line' , ()=>{
                        editor.setCursorScreenPosition([7, 0]);
                        editor.moveRight();
                        expect(editor.getCursorScreenPosition()).toEqual([6, lineLengths[6]]);
                    });
                });
            });

        });
    });
    
});