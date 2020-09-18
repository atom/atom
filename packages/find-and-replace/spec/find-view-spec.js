// /** @babel */
//
// const path = require("path");
//
// describe("FindView", () => {
//   let workspaceElement, editorView, editor, findView, activationPromise;
//
//   function getFindAtomPanel() {
//     return workspaceElement.querySelector(".find-and-replace").parentNode;
//   }
//
//   function getResultDecorations(editor, clazz) {
//     const result = [];
//     const decorations = editor.decorationsStateForScreenRowRange(0, editor.getLineCount())
//     for (let id in decorations) {
//       const decoration = decorations[id]
//       if (decoration.properties.class === clazz) {
//         result.push(decoration);
//       }
//     }
//     return result;
//   }
//
//   beforeEach(async () => {
//     spyOn(atom, "beep");
//     workspaceElement = atom.views.getView(atom.workspace);
//     workspaceElement.style.height = '800px'
//     atom.project.setPaths([path.join(__dirname, "fixtures")]);
//
//     await atom.workspace.open("sample.js");
//
//     jasmine.attachToDOM(workspaceElement);
//     editor = atom.workspace.getCenter().getActiveTextEditor();
//     editorView = editor.element;
//
//     activationPromise = atom.packages.activatePackage("find-and-replace").then(function({mainModule}) {
//       mainModule.createViews();
//       ({findView} = mainModule);
//     });
//   });
//
//   describe("when find-and-replace:show is triggered", () => {
//     it("attaches FindView to the root view", async () => {
//       atom.commands.dispatch(editorView, "find-and-replace:show");
//       await activationPromise;
//
//       expect(workspaceElement.querySelector(".find-and-replace")).toBeDefined();
//     });
//
//     it("populates the findEditor with selection when there is a selection", async () => {
//       editor.setSelectedBufferRange([[2, 8], [2, 13]]);
//
//       atom.commands.dispatch(editorView, "find-and-replace:show");
//       await activationPromise;
//
//       expect(getFindAtomPanel()).toBeVisible();
//       expect(findView.findEditor.getText()).toBe("items");
//
//       findView.findEditor.setText("");
//       editor.setSelectedBufferRange([[2, 14], [2, 20]]);
//       atom.commands.dispatch(editorView, "find-and-replace:show");
//       expect(getFindAtomPanel()).toBeVisible();
//       expect(findView.findEditor.getText()).toBe("length");
//     });
//
//     it("does not change the findEditor text when there is no selection", async () => {
//       editor.setSelectedBufferRange([[2, 8], [2, 8]]);
//
//       atom.commands.dispatch(editorView, "find-and-replace:show");
//       await activationPromise;
//
//       findView.findEditor.setText("kitten");
//       atom.commands.dispatch(editorView, "find-and-replace:show");
//       expect(findView.findEditor.getText()).toBe("kitten");
//     });
//
//     it("does not change the findEditor text when there is a multiline selection", async () => {
//       editor.setSelectedBufferRange([[2, 8], [3, 12]]);
//
//       atom.commands.dispatch(editorView, "find-and-replace:show");
//       await activationPromise;
//
//       expect(getFindAtomPanel()).toBeVisible();
//       expect(findView.findEditor.getText()).toBe("");
//     });
//
//     it("honors config settings for find options", async () => {
//       atom.config.set("find-and-replace.useRegex", true);
//       atom.config.set("find-and-replace.caseSensitive", true);
//       atom.config.set("find-and-replace.inCurrentSelection", true);
//
//       atom.commands.dispatch(editorView, "find-and-replace:show");
//       await activationPromise;
//
//       expect(findView.refs.caseOptionButton).toHaveClass("selected");
//       expect(findView.refs.regexOptionButton).toHaveClass("selected");
//       expect(findView.refs.selectionOptionButton).toHaveClass("selected");
//     });
//
//     it("places selected text into the find editor and escapes it when Regex is enabled", async () => {
//       atom.config.set("find-and-replace.useRegex", true);
//       editor.setSelectedBufferRange([[6, 6], [6, 65]]);
//
//       atom.commands.dispatch(editorView, "find-and-replace:show");
//       await activationPromise;
//
//       expect(findView.findEditor.getText()).toBe(
//         "current < pivot \\? left\\.push\\(current\\) : right\\.push\\(current\\);"
//       );
//     });
//
//     it('selects the text to find when the panel is re-shown', async () => {
//       atom.commands.dispatch(editorView, "find-and-replace:show");
//       await activationPromise;
//
//       const stringToSearch = "not found";
//       const findEditor = findView.findEditor;
//
//       findEditor.setText(stringToSearch);
//
//       atom.commands.dispatch(findEditor.element, "core:confirm");
//       atom.commands.dispatch(document.activeElement, "core:cancel");
//       atom.commands.dispatch(editorView, "find-and-replace:show");
//
//       expect(findEditor.getSelectedBufferRange()).toEqual([[0, 0], [0, stringToSearch.length]]);
//
//       const selectionElement = findEditor.getElement().querySelector('.highlight.selection .selection');
//
//       expect(selectionElement.getBoundingClientRect().width).toBeGreaterThan(0);
//     });
//   });
//
//   describe("when find-and-replace:toggle is triggered", () => {
//     it("toggles the visibility of the FindView", async () => {
//       atom.commands.dispatch(workspaceElement, "find-and-replace:toggle");
//       await activationPromise;
//
//       expect(getFindAtomPanel()).toBeVisible();
//       atom.commands.dispatch(workspaceElement, "find-and-replace:toggle");
//       expect(getFindAtomPanel()).not.toBeVisible();
//     });
//   });
//
//   describe("when the find-view is focused and window:focus-next-pane is triggered", () => {
//     it("attaches FindView to the root view", async () => {
//       atom.commands.dispatch(editorView, "find-and-replace:show");
//       await activationPromise;
//
//       expect(workspaceElement.querySelector(".find-and-replace")).toHaveFocus();
//       atom.commands.dispatch(findView.findEditor.element, "window:focus-next-pane");
//       expect(workspaceElement.querySelector(".find-and-replace")).not.toHaveFocus();
//     });
//   });
//
//   describe("find-and-replace:show-replace", () => {
//     it("focuses the replace editor", async () => {
//       atom.commands.dispatch(editorView, "find-and-replace:show-replace");
//       await activationPromise;
//
//       expect(findView.replaceEditor.element).toHaveFocus();
//     });
//
//     it("places the current selection in the replace editor", async () => {
//       editor.setSelectedBufferRange([[0, 16], [0, 27]]);
//
//       atom.commands.dispatch(editorView, "find-and-replace:show-replace");
//       await activationPromise;
//
//       expect(findView.replaceEditor.getText()).toBe("function ()");
//     });
//
//     it("does not escape the text when the regex option is enabled", async () => {
//       editor.setSelectedBufferRange([[0, 16], [0, 27]]);
//
//       atom.commands.dispatch(editorView, "find-and-replace:show");
//       atom.commands.dispatch(editorView, "find-and-replace:toggle-regex-option");
//       atom.commands.dispatch(editorView, "find-and-replace:show-replace");
//       await activationPromise;
//
//       expect(findView.replaceEditor.getText()).toBe("function ()");
//     });
//   });
//
//   describe("when find-and-replace:clear-history is triggered", () => {
//     it("clears the find and replace histories", async () => {
//       atom.commands.dispatch(editorView, "find-and-replace:show");
//       await activationPromise;
//
//       findView.findEditor.setText("items");
//       findView.replaceEditor.setText("cat");
//       findView.replaceAll();
//       findView.findEditor.setText("sort");
//       findView.replaceEditor.setText("dog");
//       findView.replaceNext();
//       atom.commands.dispatch(editorView, "find-and-replace:clear-history");
//       atom.commands.dispatch(findView.findEditor.element, "core:move-up");
//       expect(findView.findEditor.getText()).toBe("");
//
//       atom.commands.dispatch(findView.replaceEditor.element, "core:move-up");
//       expect(findView.replaceEditor.getText()).toBe("");
//     });
//   });
//
//   describe("core:cancel", () => {
//     beforeEach(async () => {
//       atom.commands.dispatch(editorView, "find-and-replace:show");
//       await activationPromise;
//
//       findView.findEditor.setText("items");
//       atom.commands.dispatch(findView.findEditor.element, "core:confirm");
//       findView.element.focus();
//     });
//
//     describe("when core:cancel is triggered on the find view", () => {
//       it("detaches from the workspace view", () => {
//         atom.commands.dispatch(document.activeElement, "core:cancel");
//         expect(getFindAtomPanel()).not.toBeVisible();
//       });
//
//       it("removes highlighted matches", () => {
//         expect(workspaceElement).toHaveClass("find-visible");
//         atom.commands.dispatch(document.activeElement, "core:cancel");
//         expect(workspaceElement).not.toHaveClass("find-visible");
//       });
//     });
//
//     describe("when core:cancel is triggered on an empty pane", () => {
//       it("hides the find panel", () => {
//         const paneElement = atom.views.getView(atom.workspace.getCenter().getActivePane());
//         paneElement.focus();
//         atom.commands.dispatch(paneElement, "core:cancel");
//         expect(getFindAtomPanel()).not.toBeVisible();
//       });
//     });
//
//     describe("when core:cancel is triggered on an editor", () => {
//       it("detaches from the workspace view", async () => {
//         atom.workspace.open();
//         atom.commands.dispatch(editorView, "core:cancel");
//         expect(getFindAtomPanel()).not.toBeVisible();
//       });
//     });
//
//     describe("when core:cancel is triggered on a mini editor", () => {
//       it("leaves the find view attached", () => {
//         const miniEditor = document.createElement("atom-text-editor");
//         miniEditor.setAttribute("mini", "");
//
//         atom.workspace.addTopPanel({
//           item: miniEditor
//         });
//
//         miniEditor.focus();
//         atom.commands.dispatch(miniEditor, "core:cancel");
//         expect(getFindAtomPanel()).toBeVisible();
//       });
//     });
//   });
//
//   describe("serialization", () => {
//     it("serializes find and replace history", async () => {
//       atom.commands.dispatch(editorView, "find-and-replace:show");
//       await activationPromise;
//
//       findView.findEditor.setText("items");
//       findView.replaceEditor.setText("cat");
//       findView.replaceAll();
//       findView.findEditor.setText("sort");
//       findView.replaceEditor.setText("dog");
//       findView.replaceNext();
//       findView.findEditor.setText("shift");
//       findView.replaceEditor.setText("ok");
//       findView.findNext(false);
//
//       await atom.packages.deactivatePackage("find-and-replace");
//       activationPromise = atom.packages.activatePackage("find-and-replace").then(function({mainModule}) {
//         mainModule.createViews();
//         ({findView} = mainModule);
//       });
//       atom.commands.dispatch(editorView, "find-and-replace:show");
//       await activationPromise;
//
//       atom.commands.dispatch(findView.findEditor.element, "core:move-up");
//       expect(findView.findEditor.getText()).toBe("shift");
//       atom.commands.dispatch(findView.findEditor.element, "core:move-up");
//       expect(findView.findEditor.getText()).toBe("sort");
//       atom.commands.dispatch(findView.findEditor.element, "core:move-up");
//       expect(findView.findEditor.getText()).toBe("items");
//       atom.commands.dispatch(findView.replaceEditor.element, "core:move-up");
//       expect(findView.replaceEditor.getText()).toBe("dog");
//       atom.commands.dispatch(findView.replaceEditor.element, "core:move-up");
//       expect(findView.replaceEditor.getText()).toBe("cat");
//     });
//
//     it("serializes find options ", async () => {
//       atom.commands.dispatch(editorView, "find-and-replace:show");
//       await activationPromise;
//
//       expect(findView.refs.caseOptionButton).not.toHaveClass("selected");
//       expect(findView.refs.regexOptionButton).not.toHaveClass("selected");
//       expect(findView.refs.selectionOptionButton).not.toHaveClass("selected");
//       expect(findView.refs.wholeWordOptionButton).not.toHaveClass("selected");
//
//       findView.refs.caseOptionButton.click();
//       findView.refs.regexOptionButton.click();
//       findView.refs.selectionOptionButton.click();
//       findView.refs.wholeWordOptionButton.click();
//       expect(findView.refs.caseOptionButton).toHaveClass("selected");
//       expect(findView.refs.regexOptionButton).toHaveClass("selected");
//       expect(findView.refs.selectionOptionButton).toHaveClass("selected");
//       expect(findView.refs.wholeWordOptionButton).toHaveClass("selected");
//
//       await atom.packages.deactivatePackage("find-and-replace");
//       activationPromise = atom.packages.activatePackage("find-and-replace").then(function({mainModule}) {
//         mainModule.createViews();
//         ({findView} = mainModule);
//       });
//       atom.commands.dispatch(editorView, "find-and-replace:show");
//       await activationPromise;
//
//       expect(findView.refs.caseOptionButton).toHaveClass("selected");
//       expect(findView.refs.regexOptionButton).toHaveClass("selected");
//       expect(findView.refs.selectionOptionButton).toHaveClass("selected");
//       expect(findView.refs.wholeWordOptionButton).toHaveClass("selected");
//     });
//   });
//
//   describe("finding", () => {
//     beforeEach(async () => {
//       atom.config.set("find-and-replace.focusEditorAfterSearch", false);
//       editor.setCursorBufferPosition([2, 0]);
//
//       atom.commands.dispatch(editorView, "find-and-replace:show");
//       await activationPromise;
//
//       findView.findEditor.setText("items");
//       atom.commands.dispatch(findView.findEditor.element, "core:confirm");
//     });
//
//     describe("when find-and-replace:confirm is triggered", () => {
//       it("runs a search", () => {
//         findView.findEditor.setText("notinthefile");
//         atom.commands.dispatch(findView.findEditor.element, "find-and-replace:confirm");
//         expect(getResultDecorations(editor, "find-result")).toHaveLength(0);
//
//         findView.findEditor.setText("items");
//         atom.commands.dispatch(findView.findEditor.element, "find-and-replace:confirm");
//         expect(getResultDecorations(editor, "find-result")).toHaveLength(5);
//       });
//     });
//
//     describe("when no results are found", () => {
//       it("adds a .has-no-results class", () => {
//         findView.findEditor.setText("notinthefile");
//         atom.commands.dispatch(findView.findEditor.element, "find-and-replace:confirm");
//         expect(findView.element).toHaveClass("has-no-results");
//       });
//     });
//
//     describe("when results are found", () => {
//       it("adds a .has-results class", () => {
//         findView.findEditor.setText("items");
//         atom.commands.dispatch(findView.findEditor.element, "find-and-replace:confirm");
//         expect(findView.element).toHaveClass("has-results");
//       });
//     });
//
//     describe("when the find string contains an escaped char", () => {
//       beforeEach(() => {
//         editor.setText("\t\n\\t\\\\");
//         editor.setCursorBufferPosition([0, 0]);
//       });
//
//       describe("when regex search is enabled", () => {
//         beforeEach(() => {
//           atom.commands.dispatch(findView.findEditor.element, "find-and-replace:toggle-regex-option");
//         });
//
//         it("finds a backslash", () => {
//           findView.findEditor.setText("\\\\");
//           atom.commands.dispatch(findView.findEditor.element, "core:confirm");
//           expect(editor.getSelectedBufferRange()).toEqual([[1, 0], [1, 1]]);
//         });
//
//         it("finds a newline", () => {
//           findView.findEditor.setText("\\n");
//           atom.commands.dispatch(findView.findEditor.element, "core:confirm");
//           expect(editor.getSelectedBufferRange()).toEqual([[0, 1], [1, 0]]);
//         });
//
//         it("finds a tab character", () => {
//           findView.findEditor.setText("\\t");
//           atom.commands.dispatch(findView.findEditor.element, "core:confirm");
//           expect(editor.getSelectedBufferRange()).toEqual([[0, 0], [0, 1]]);
//         });
//       });
//
//       describe("when regex search is disabled", () => {
//         it("finds the literal backslash t", () => {
//           findView.findEditor.setText("\\t");
//           atom.commands.dispatch(findView.findEditor.element, "core:confirm");
//           expect(editor.getSelectedBufferRange()).toEqual([[1, 0], [1, 2]]);
//         });
//
//         it("finds a backslash", () => {
//           findView.findEditor.setText("\\");
//           atom.commands.dispatch(findView.findEditor.element, "core:confirm");
//           expect(editor.getSelectedBufferRange()).toEqual([[1, 0], [1, 1]]);
//         });
//
//         it("finds two backslashes", () => {
//           findView.findEditor.setText('\\\\');
//           atom.commands.dispatch(findView.findEditor.element, "core:confirm");
//           expect(editor.getSelectedBufferRange()).toEqual([[1, 2], [1, 4]]);
//         });
//
//         it("doesn't find when escaped", () => {
//           findView.findEditor.setText("\\\\t");
//           atom.commands.dispatch(findView.findEditor.element, "core:confirm");
//           expect(editor.getSelectedBufferRange()).toEqual([[0, 0], [0, 0]]);
//         });
//       });
//     });
//
//     describe("when focusEditorAfterSearch is set", () => {
//       beforeEach(() => {
//         atom.config.set("find-and-replace.focusEditorAfterSearch", true);
//         atom.commands.dispatch(findView.findEditor.element, "core:confirm");
//       });
//
//       it("selects the first match following the cursor and correctly focuses the editor", () => {
//         expect(findView.refs.resultCounter.textContent).toEqual("3 of 6");
//         expect(editor.getSelectedBufferRange()).toEqual([[2, 34], [2, 39]]);
//         expect(editorView).toHaveFocus();
//       });
//     });
//
//     describe("when whole-word search is enabled", () => {
//       beforeEach(() => {
//         editor.setText("-----\nswhole-wordy\nwhole-word\nword\nwhole-swords");
//         editor.setCursorBufferPosition([0, 0]);
//         atom.commands.dispatch(findView.findEditor.element, "find-and-replace:toggle-whole-word-option");
//       });
//
//       it("finds the whole words", () => {
//         findView.findEditor.setText("word");
//         atom.commands.dispatch(findView.findEditor.element, "core:confirm");
//         expect(editor.getSelectedBufferRange()).toEqual([[2, 6], [2, 10]]);
//       });
//
//       it("doesn't highlight the search inside words", () => {
//         findView.findEditor.setText("word");
//         atom.commands.dispatch(findView.findEditor.element, "core:confirm");
//         expect(getResultDecorations(editor, "find-result")).toHaveLength(1);
//         expect(getResultDecorations(editor, "current-result")).toHaveLength(1);
//       });
//     });
//
//     it("doesn't change the selection, beeps if there are no matches and keeps focus on the find view", () => {
//       editor.setCursorBufferPosition([2, 0]);
//       findView.findEditor.setText("notinthefilebro");
//       findView.findEditor.element.focus();
//       atom.commands.dispatch(findView.findEditor.element, "core:confirm");
//       expect(editor.getCursorBufferPosition()).toEqual([2, 0]);
//       expect(atom.beep).toHaveBeenCalled();
//       expect(findView.element).toHaveFocus();
//       expect(findView.refs.descriptionLabel.textContent).toEqual("No results found for 'notinthefilebro'");
//     });
//
//     describe("updating the replace button enablement", () => {
//       it("enables the replace buttons when are search results", () => {
//         findView.findEditor.setText("item");
//         atom.commands.dispatch(findView.findEditor.element, "core:confirm");
//         expect(findView.refs.replaceAllButton).not.toHaveClass("disabled");
//         expect(findView.refs.replaceNextButton).not.toHaveClass("disabled");
//
//         const disposable = findView.replaceTooltipSubscriptions;
//         spyOn(disposable, "dispose");
//         findView.findEditor.setText("it");
//         atom.commands.dispatch(findView.findEditor.element, "core:confirm");
//         expect(findView.refs.replaceAllButton).not.toHaveClass("disabled");
//         expect(findView.refs.replaceNextButton).not.toHaveClass("disabled");
//         expect(disposable.dispose).not.toHaveBeenCalled();
//
//         findView.findEditor.setText("nopenotinthefile");
//         atom.commands.dispatch(findView.findEditor.element, "core:confirm");
//         expect(findView.refs.replaceAllButton).toHaveClass("disabled");
//         expect(findView.refs.replaceNextButton).toHaveClass("disabled");
//         expect(disposable.dispose).toHaveBeenCalled();
//
//         findView.findEditor.setText("i");
//         atom.commands.dispatch(findView.findEditor.element, "core:confirm");
//         expect(findView.refs.replaceAllButton).not.toHaveClass("disabled");
//         expect(findView.refs.replaceNextButton).not.toHaveClass("disabled");
//
//         findView.findEditor.setText("");
//         atom.commands.dispatch(findView.findEditor.element, "core:confirm");
//         expect(findView.refs.replaceAllButton).toHaveClass("disabled");
//         expect(findView.refs.replaceNextButton).toHaveClass("disabled");
//       });
//     });
//
//     describe("updating the descriptionLabel", () => {
//       it("properly updates the info message", () => {
//         findView.findEditor.setText("item");
//         atom.commands.dispatch(findView.findEditor.element, "core:confirm");
//         expect(findView.refs.descriptionLabel.textContent).toEqual("6 results found for 'item'");
//
//         findView.findEditor.setText("notinthefilenope");
//         atom.commands.dispatch(findView.findEditor.element, "core:confirm");
//         expect(findView.refs.descriptionLabel.textContent).toEqual("No results found for 'notinthefilenope'");
//
//         findView.findEditor.setText("item");
//         atom.commands.dispatch(findView.findEditor.element, "core:confirm");
//         expect(findView.refs.descriptionLabel.textContent).toEqual("6 results found for 'item'");
//
//         findView.findEditor.setText("");
//         atom.commands.dispatch(findView.findEditor.element, "core:confirm");
//         expect(findView.refs.descriptionLabel.textContent).toContain("Find in Current Buffer");
//       });
//
//       describe("when there is an error", () => {
//         describe("when the regex search string is invalid", () => {
//           beforeEach(() => {
//             atom.commands.dispatch(findView.findEditor.element, "find-and-replace:toggle-regex-option");
//             findView.findEditor.setText("i[t");
//             atom.commands.dispatch(findView.findEditor.element, "core:confirm");
//           });
//
//           it("displays the error", () => {
//             expect(findView.refs.descriptionLabel).toHaveClass("text-error");
//             expect(findView.refs.descriptionLabel.textContent).toContain("Invalid regular expression");
//           });
//
//           it("will be reset when there is no longer an error", () => {
//             expect(findView.refs.descriptionLabel).toHaveClass("text-error");
//
//             findView.findEditor.setText("");
//             atom.commands.dispatch(findView.findEditor.element, "core:confirm");
//             expect(findView.refs.descriptionLabel).not.toHaveClass("text-error");
//             expect(findView.refs.descriptionLabel.textContent).toContain("Find in Current Buffer");
//
//             findView.findEditor.setText("item");
//             atom.commands.dispatch(findView.findEditor.element, "core:confirm");
//             expect(findView.refs.descriptionLabel).not.toHaveClass("text-error");
//             expect(findView.refs.descriptionLabel.textContent).toContain("6 results");
//           });
//         });
//
//         describe("when the search string is too large", () => {
//           beforeEach(() => {
//             findView.findEditor.setText("x".repeat(50000));
//             atom.commands.dispatch(findView.findEditor.element, "core:confirm");
//           });
//
//           it("displays the error", () => {
//             expect(findView.refs.descriptionLabel).toHaveClass("text-error");
//             expect(findView.refs.descriptionLabel.textContent).toBe("regular expression is too large");
//           });
//
//           it("will be reset when there is no longer an error", () => {
//             findView.findEditor.setText("");
//             atom.commands.dispatch(findView.findEditor.element, "core:confirm");
//             expect(findView.refs.descriptionLabel).not.toHaveClass("text-error");
//             expect(findView.refs.descriptionLabel.textContent).toContain("Find in Current Buffer");
//
//             findView.findEditor.setText("item");
//             atom.commands.dispatch(findView.findEditor.element, "core:confirm");
//             expect(findView.refs.descriptionLabel).not.toHaveClass("text-error");
//             expect(findView.refs.descriptionLabel.textContent).toContain("6 results");
//           });
//         });
//       });
//     });
//
//     it("selects the first match following the cursor", () => {
//       expect(findView.refs.resultCounter.textContent).toEqual("2 of 6");
//       expect(editor.getSelectedBufferRange()).toEqual([[2, 8], [2, 13]]);
//
//       atom.commands.dispatch(findView.findEditor.element, "core:confirm");
//       expect(findView.refs.resultCounter.textContent).toEqual("3 of 6");
//       expect(editor.getSelectedBufferRange()).toEqual([[2, 34], [2, 39]]);
//       expect(findView.findEditor.element).toHaveFocus();
//     });
//
//     it("selects the next match when the next match button is pressed", () => {
//       findView.refs.nextButton.click();
//       expect(findView.refs.resultCounter.textContent).toEqual("3 of 6");
//       expect(editor.getSelectedBufferRange()).toEqual([[2, 34], [2, 39]]);
//     });
//
//     it("selects the previous match when the next match button is pressed while holding shift", () => {
//       findView.refs.nextButton.dispatchEvent(new MouseEvent("click", {
//         shiftKey: true
//       }));
//
//       expect(findView.refs.resultCounter.textContent).toEqual("1 of 6");
//       expect(editor.getSelectedBufferRange()).toEqual([[1, 22], [1, 27]]);
//     });
//
//     it("selects the next match when the 'find-and-replace:find-next' event is triggered and correctly focuses the editor", () => {
//       expect(findView.element).toHaveFocus();
//       atom.commands.dispatch(editorView, "find-and-replace:find-next");
//       expect(findView.refs.resultCounter.textContent).toEqual("3 of 6");
//       expect(editor.getSelectedBufferRange()).toEqual([[2, 34], [2, 39]]);
//       expect(editorView).toHaveFocus();
//     });
//
//     it("selects the previous match before the cursor when the 'find-and-replace:show-previous' event is triggered", () => {
//       expect(findView.refs.resultCounter.textContent).toEqual("2 of 6");
//       expect(editor.getSelectedBufferRange()).toEqual([[2, 8], [2, 13]]);
//       atom.commands.dispatch(findView.findEditor.element, "find-and-replace:show-previous");
//       expect(findView.refs.resultCounter.textContent).toEqual("1 of 6");
//       expect(editor.getSelectedBufferRange()).toEqual([[1, 22], [1, 27]]);
//       expect(findView.findEditor.element).toHaveFocus();
//     });
//
//     describe("when the match is folded", () => {
//       it("unfolds the match", () => {
//         editor.foldAll();
//         atom.commands.dispatch(findView.findEditor.element, "core:confirm");
//         expect(editor.getSelectedBufferRange()).toEqual([[2, 34], [2, 39]]);
//         expect(editor.isFoldedAtBufferRow(2)).toBe(false);
//         expect(editor.getCursorBufferPosition()).toEqual([2, 39]);
//       })
//     })
//
//     it("will re-run search if 'find-and-replace:find-next' is triggered after changing the findEditor's text", () => {
//       findView.findEditor.setText("sort");
//       atom.commands.dispatch(findView.findEditor.element, "find-and-replace:find-next");
//       expect(findView.refs.resultCounter.textContent).toEqual("3 of 5");
//       expect(editor.getSelectedBufferRange()).toEqual([[8, 11], [8, 15]]);
//     });
//
//     it("'find-and-replace:find-next' adds to the findEditor's history", () => {
//       findView.findEditor.setText("sort");
//       atom.commands.dispatch(findView.findEditor.element, "find-and-replace:find-next");
//       expect(findView.refs.resultCounter.textContent).toEqual("3 of 5");
//
//       findView.findEditor.setText("nope");
//       atom.commands.dispatch(findView.findEditor.element, "core:move-up");
//       expect(findView.findEditor.getText()).toEqual("sort");
//     });
//
//     it("selects the previous match when the 'find-and-replace:find-previous' event is triggered and correctly focuses the editor", () => {
//       expect(findView.element).toHaveFocus();
//
//       atom.commands.dispatch(editorView, "find-and-replace:find-previous");
//       expect(findView.refs.resultCounter.textContent).toEqual("1 of 6");
//       expect(editor.getSelectedBufferRange()).toEqual([[1, 27], [1, 22]]);
//       expect(editorView).toHaveFocus();
//     });
//
//     it("will re-run search if 'find-and-replace:find-previous' is triggered after changing the findEditor's text", () => {
//       findView.findEditor.setText("sort");
//       atom.commands.dispatch(findView.findEditor.element, "find-and-replace:find-previous");
//       expect(findView.refs.resultCounter.textContent).toEqual("2 of 5");
//       expect(editor.getSelectedBufferRange()).toEqual([[1, 6], [1, 10]]);
//     });
//
//     it("selects all matches when 'find-and-replace:find-all' is triggered and correctly focuses the editor", () => {
//       expect(findView.element).toHaveFocus();
//       atom.commands.dispatch(findView.findEditor.element, "find-and-replace:find-all");
//
//       expect(editor.getSelectedBufferRanges()).toEqual([
//         [[1, 27], [1, 22]],
//         [[2, 8], [2, 13]],
//         [[2, 34], [2, 39]],
//         [[3, 16], [3, 21]],
//         [[4, 10], [4, 15]],
//         [[5, 16], [5, 21]]
//       ]);
//       expect(editorView).toHaveFocus();
//     });
//
//     it("will re-run search if 'find-and-replace:find-all' is triggered after changing the findEditor's text", () => {
//       findView.findEditor.setText("sort");
//       atom.commands.dispatch(findView.findEditor.element, "find-and-replace:find-all");
//
//       expect(editor.getSelectedBufferRanges()).toEqual([
//         [[0, 9], [0, 13]],
//         [[1, 6], [1, 10]],
//         [[8, 11], [8, 15]],
//         [[8, 43], [8, 47]],
//         [[11, 9], [11, 13]]
//       ]);
//     });
//
//     it("replaces results counter with number of results found when user moves the cursor", () => {
//       editor.moveDown();
//       expect(findView.refs.resultCounter.textContent).toBe("6 found");
//     });
//
//     it("replaces results counter x of y text when user selects a marked range", () => {
//       editor.moveDown();
//       editor.setSelectedBufferRange([[2, 34], [2, 39]]);
//       expect(findView.refs.resultCounter.textContent).toEqual("3 of 6");
//     });
//
//     it("shows an icon when search wraps around and the editor scrolls", () => {
//       editorView.style.height = "80px";
//
//       editorView.component.measureDimensions();
//       expect(editor.getLastVisibleScreenRow()).toBe(3);
//       expect(findView.refs.resultCounter.textContent).toEqual("2 of 6");
//       expect(findView.wrapIcon).not.toBeVisible();
//
//       atom.commands.dispatch(editorView, "find-and-replace:find-previous");
//       expect(findView.refs.resultCounter.textContent).toEqual("1 of 6");
//       expect(editor.getLastVisibleScreenRow()).toBe(3);
//       expect(findView.wrapIcon).not.toBeVisible();
//
//       atom.commands.dispatch(editorView, "find-and-replace:find-previous");
//       expect(findView.refs.resultCounter.textContent).toEqual("6 of 6");
//       expect(editor.getLastVisibleScreenRow()).toBe(7);
//       expect(findView.wrapIcon).toBeVisible();
//       expect(findView.wrapIcon).toHaveClass("icon-move-down");
//
//       atom.commands.dispatch(editorView, "find-and-replace:find-next");
//       expect(findView.refs.resultCounter.textContent).toEqual("1 of 6");
//       expect(editor.getLastVisibleScreenRow()).toBe(3);
//       expect(findView.wrapIcon).toBeVisible();
//       expect(findView.wrapIcon).toHaveClass("icon-move-up");
//     });
//
//     it("does not show the wrap icon when the editor does not scroll", () => {
//       editorView.style.height = "400px";
//       editor.update({autoHeight: false})
//
//       editorView.component.measureDimensions();
//       expect(editor.getVisibleRowRange()).toEqual([0, 12]);
//
//       atom.commands.dispatch(editorView, "find-and-replace:find-previous");
//       expect(findView.refs.resultCounter.textContent).toEqual("1 of 6");
//
//       atom.commands.dispatch(editorView, "find-and-replace:find-previous");
//       expect(findView.refs.resultCounter.textContent).toEqual("6 of 6");
//       expect(editor.getVisibleRowRange()).toEqual([0, 12]);
//       expect(findView.wrapIcon).not.toBeVisible();
//
//       atom.commands.dispatch(editorView, "find-and-replace:find-next");
//       expect(findView.refs.resultCounter.textContent).toEqual("1 of 6");
//       expect(editor.getVisibleRowRange()).toEqual([0, 12]);
//       expect(findView.wrapIcon).not.toBeVisible();
//     });
//
//     it("allows searching for dashes in combination with non-ascii characters (regression)", () => {
//       editor.setText("123-Âbc");
//       findView.findEditor.setText("3-â");
//       atom.commands.dispatch(findView.findEditor.element, "find-and-replace:find-next");
//       expect(findView.refs.descriptionLabel).not.toHaveClass("text-error");
//       expect(editor.getSelectedBufferRange()).toEqual([[0, 2], [0, 5]]);
//     });
//
//     describe("when find-and-replace:use-selection-as-find-pattern is triggered", () => {
//       it("places the selected text into the find editor", () => {
//         editor.setSelectedBufferRange([[1, 6], [1, 10]]);
//         atom.commands.dispatch(workspaceElement, "find-and-replace:use-selection-as-find-pattern");
//         expect(findView.findEditor.getText()).toBe("sort");
//         expect(editor.getSelectedBufferRange()).toEqual([[1, 6], [1, 10]]);
//
//         atom.commands.dispatch(workspaceElement, "find-and-replace:find-next");
//         expect(editor.getSelectedBufferRange()).toEqual([[8, 11], [8, 15]]);
//
//         atom.workspace.destroyActivePane();
//         atom.commands.dispatch(workspaceElement, "find-and-replace:use-selection-as-find-pattern");
//         expect(findView.findEditor.getText()).toBe("sort");
//       });
//
//       it("places the word under the cursor into the find editor", () => {
//         editor.setSelectedBufferRange([[1, 8], [1, 8]]);
//         atom.commands.dispatch(workspaceElement, "find-and-replace:use-selection-as-find-pattern");
//         expect(findView.findEditor.getText()).toBe("sort");
//         expect(editor.getSelectedBufferRange()).toEqual([[1, 8], [1, 8]]);
//
//         atom.commands.dispatch(workspaceElement, "find-and-replace:find-next");
//         expect(editor.getSelectedBufferRange()).toEqual([[8, 11], [8, 15]]);
//       });
//
//       it("places the previously selected text into the find editor if no selection", () => {
//         editor.setSelectedBufferRange([[1, 6], [1, 10]]);
//         atom.commands.dispatch(workspaceElement, "find-and-replace:use-selection-as-find-pattern");
//         expect(findView.findEditor.getText()).toBe("sort");
//
//         editor.setSelectedBufferRange([[1, 1], [1, 1]]);
//         atom.commands.dispatch(workspaceElement, "find-and-replace:use-selection-as-find-pattern");
//         expect(findView.findEditor.getText()).toBe("sort");
//       });
//
//       it("places selected text into the find editor and escapes it when Regex is enabled", () => {
//         atom.commands.dispatch(findView.findEditor.element, "find-and-replace:toggle-regex-option");
//         editor.setSelectedBufferRange([[6, 6], [6, 65]]);
//         atom.commands.dispatch(workspaceElement, "find-and-replace:use-selection-as-find-pattern");
//
//         expect(findView.findEditor.getText()).toBe(
//           "current < pivot \\? left\\.push\\(current\\) : right\\.push\\(current\\);"
//         );
//       });
//
//       it("searches for the amount of results", () => {
//         spyOn(findView, 'liveSearch') // ignore live search - we're interested in the explicit search call
//
//         editor.setSelectedBufferRange([[1, 8], [1, 8]]);
//         atom.commands.dispatch(workspaceElement, "find-and-replace:use-selection-as-find-pattern");
//         expect(findView.refs.resultCounter.textContent).toEqual("5 found");
//       })
//     });
//
//     describe("when find-and-replace:use-selection-as-replace-pattern is triggered", () => {
//       it("places the selected text into the replace editor", () => {
//         editor.setSelectedBufferRange([[3, 8], [3, 13]]);
//         atom.commands.dispatch(workspaceElement, 'find-and-replace:use-selection-as-replace-pattern');
//         expect(findView.replaceEditor.getText()).toBe('pivot');
//         expect(editor.getSelectedBufferRange()).toEqual([[3, 8], [3, 13]]);
//
//         findView.findEditor.setText('sort');
//         atom.commands.dispatch(workspaceElement, 'find-and-replace:find-next');
//         expect(editor.getSelectedBufferRange()).toEqual([[8, 11], [8, 15]]);
//         expect(editor.getTextInBufferRange(editor.getSelectedBufferRange())).toEqual('sort');
//         atom.commands.dispatch(workspaceElement, 'find-and-replace:replace-next');
//         expect(editor.getTextInBufferRange([[8, 11], [8, 16]])).toEqual('pivot');
//         expect(editor.getSelectedBufferRange()).toEqual([[8, 44], [8, 48]]);
//         expect(editor.getTextInBufferRange(editor.getSelectedBufferRange())).toEqual('sort');
//       });
//
//       it("places the word under the cursor into the replace editor", () => {
//         editor.setSelectedBufferRange([[3, 8], [3, 8]]);
//         atom.commands.dispatch(workspaceElement, 'find-and-replace:use-selection-as-replace-pattern');
//         expect(findView.replaceEditor.getText()).toBe('pivot');
//         expect(editor.getSelectedBufferRange()).toEqual([[3, 8], [3, 8]]);
//
//         findView.findEditor.setText('sort');
//         atom.commands.dispatch(workspaceElement, 'find-and-replace:find-next');
//         expect(editor.getSelectedBufferRange()).toEqual([[8, 11], [8, 15]]);
//         expect(editor.getTextInBufferRange(editor.getSelectedBufferRange())).toEqual('sort');
//         atom.commands.dispatch(workspaceElement, 'find-and-replace:replace-next');
//         expect(editor.getTextInBufferRange([[8, 11], [8, 16]])).toEqual('pivot');
//         expect(editor.getSelectedBufferRange()).toEqual([[8, 44], [8, 48]]);
//         expect(editor.getTextInBufferRange(editor.getSelectedBufferRange())).toEqual('sort');
//       });
//
//       it("places the previously selected text into the replace editor if no selection", () => {
//         editor.setSelectedBufferRange([[1, 6], [1, 10]]);
//         atom.commands.dispatch(workspaceElement, 'find-and-replace:use-selection-as-replace-pattern');
//         expect(findView.replaceEditor.getText()).toBe('sort');
//
//         editor.setSelectedBufferRange([[1, 1], [1, 1]]);
//         atom.commands.dispatch(workspaceElement, 'find-and-replace:use-selection-as-replace-pattern');
//         expect(findView.replaceEditor.getText()).toBe('sort');
//       });
//
//       it("places selected text into the replace editor and escapes it when Regex is enabled", () => {
//         atom.commands.dispatch(findView.replaceEditor.element, 'find-and-replace:toggle-regex-option');
//         editor.setSelectedBufferRange([[6, 6], [6, 65]]);
//         atom.commands.dispatch(workspaceElement, 'find-and-replace:use-selection-as-replace-pattern');
//         expect(findView.replaceEditor.getText()).toBe('current < pivot \\? left\\.push\\(current\\) : right\\.push\\(current\\);');
//       });
//     });
//
//     describe("when find-and-replace:find-next-selected is triggered", () => {
//       it("places the selected text into the find editor and finds the next occurrence", () => {
//         editor.setSelectedBufferRange([[0, 9], [0, 13]]);
//         atom.commands.dispatch(workspaceElement, "find-and-replace:find-next-selected");
//         expect(findView.findEditor.getText()).toBe("sort");
//         expect(editor.getSelectedBufferRange()).toEqual([[1, 6], [1, 10]]);
//       });
//
//       it("places the word under the cursor into the find editor and finds the next occurrence", () => {
//         editor.setSelectedBufferRange([[1, 8], [1, 8]]);
//         atom.commands.dispatch(workspaceElement, "find-and-replace:find-next-selected");
//         expect(findView.findEditor.getText()).toBe("sort");
//         expect(editor.getSelectedBufferRange()).toEqual([[8, 11], [8, 15]]);
//       });
//     });
//
//     describe("when find-and-replace:find-previous-selected is triggered", () => {
//       it("places the selected text into the find editor and finds the previous occurrence ", () => {
//         editor.setSelectedBufferRange([[0, 9], [0, 13]]);
//         atom.commands.dispatch(workspaceElement, "find-and-replace:find-previous-selected");
//         expect(findView.findEditor.getText()).toBe("sort");
//         expect(editor.getSelectedBufferRange()).toEqual([[11, 9], [11, 13]]);
//       });
//
//       it("places the word under the cursor into the find editor and finds the previous occurrence", () => {
//         editor.setSelectedBufferRange([[8, 13], [8, 13]]);
//         atom.commands.dispatch(workspaceElement, "find-and-replace:find-previous-selected");
//         expect(findView.findEditor.getText()).toBe("sort");
//         expect(editor.getSelectedBufferRange()).toEqual([[1, 6], [1, 10]]);
//       });
//     });
//
//     it("does not highlight the found text when the find view is hidden", () => {
//       atom.commands.dispatch(findView.findEditor.element, "core:cancel");
//       atom.commands.dispatch(findView.findEditor.element, "find-and-replace:find-next");
//     });
//
//     describe("when the active pane item changes", () => {
//       beforeEach(() => {
//         editor.setSelectedBufferRange([[0, 0], [0, 0]]);
//       });
//
//       describe("when a new editor is activated", () => {
//         it("reruns the search on the new editor", async () => {
//           await atom.workspace.open("sample.coffee");
//           editor = atom.workspace.getCenter().getActivePaneItem();
//           expect(findView.refs.resultCounter.textContent).toEqual("7 found");
//           expect(editor.getSelectedBufferRange()).toEqual([[0, 0], [0, 0]]);
//         });
//
//         it("initially highlights the found text in the new editor", async () => {
//           expect(getResultDecorations(editor, "find-result")).toHaveLength(6);
//
//           await atom.workspace.open("sample.coffee");
//           expect(getResultDecorations(editor, "find-result")).toHaveLength(0);
//
//           const newEditor = atom.workspace.getCenter().getActiveTextEditor();
//           expect(getResultDecorations(newEditor, "find-result")).toHaveLength(7);
//         });
//
//         it("highlights the found text in the new editor when find next is triggered", async () => {
//           await atom.workspace.open("sample.coffee");
//
//           atom.commands.dispatch(findView.findEditor.element, "find-and-replace:find-next");
//           const newEditor = atom.workspace.getCenter().getActiveTextEditor();
//           expect(getResultDecorations(newEditor, "find-result")).toHaveLength(6);
//           expect(getResultDecorations(newEditor, "current-result")).toHaveLength(1);
//         });
//       });
//
//       describe("when all active pane items are closed", () => {
//         it("updates the result count", () => {
//           atom.commands.dispatch(editorView, "core:close");
//           expect(findView.refs.resultCounter.textContent).toEqual("no results");
//         });
//       });
//
//       describe("when the active pane item is not an editor", () => {
//         let openerDisposable;
//
//         beforeEach(() => {
//           openerDisposable = atom.workspace.addOpener(function(pathToOpen, options) {
//             return document.createElement("div");
//           });
//         });
//
//         afterEach(() => {
//           openerDisposable.dispose();
//         });
//
//         it("updates the result view", async () => {
//           await atom.workspace.open("another");
//           expect(findView.refs.resultCounter.textContent).toEqual("no results");
//         });
//       });
//
//       describe("when the active pane is in a dock", () => {
//         it("does nothing", async () => {
//           const dock = atom.workspace.getLeftDock()
//           dock.show()
//           dock.getActivePane().activateItem(document.createElement('div'))
//           dock.getActivePane().activate()
//           expect(findView.refs.resultCounter.textContent).not.toEqual("no results");
//         });
//       });
//
//       describe("when a new editor is activated on a different pane", () => {
//         it("initially highlights all the sample.js results", () => {
//           expect(getResultDecorations(editor, "find-result")).toHaveLength(6);
//         });
//
//         it("reruns the search on the new editor", async () => {
//           let newEditor
//           if (atom.workspace.createItemForURI) {
//             newEditor = await atom.workspace.createItemForURI("sample.coffee");
//           } else {
//             newEditor = await atom.workspace.open("sample.coffee", {activateItem: false})
//           }
//
//           newEditor = atom.workspace.paneForItem(editor).splitRight({
//             items: [newEditor]
//           }).getActiveItem();
//
//           expect(getResultDecorations(newEditor, "find-result")).toHaveLength(7);
//           expect(findView.refs.resultCounter.textContent).toEqual("7 found");
//           expect(newEditor.getSelectedBufferRange()).toEqual([[0, 0], [0, 0]]);
//
//           atom.commands.dispatch(findView.findEditor.element, "find-and-replace:find-next");
//           expect(findView.refs.resultCounter.textContent).toEqual("1 of 7");
//           expect(newEditor.getSelectedBufferRange()).toEqual([[1, 9], [1, 14]]);
//         });
//
//         it("highlights the found text in the new editor (and removes the highlights from the other)", async () => {
//           const newEditor = await atom.workspace.open("sample.coffee")
//           expect(getResultDecorations(editor, "find-result")).toHaveLength(0);
//           expect(getResultDecorations(newEditor, "find-result")).toHaveLength(7);
//         });
//
//         it("will still highlight results after the split pane has been destroyed", async () => {
//           const newEditor = await atom.workspace.open("sample.coffee")
//           const originalPane = atom.workspace.paneForItem(editor);
//           const splitPane = atom.workspace.paneForItem(editor).splitRight();
//           originalPane.moveItemToPane(newEditor, splitPane, 0);
//           expect(getResultDecorations(newEditor, "find-result")).toHaveLength(7);
//
//           atom.commands.dispatch(editor.element, "core:close");
//           editorView.focus();
//           expect(atom.workspace.getCenter().getActiveTextEditor()).toBe(editor);
//           expect(getResultDecorations(editor, "find-result")).toHaveLength(6);
//         });
//       });
//     });
//
//     describe("when the buffer contents change", () => {
//       it("re-runs the search", () => {
//         editor.setSelectedBufferRange([[1, 26], [1, 27]]);
//         editor.insertText("");
//         window.advanceClock(1000);
//         expect(findView.refs.resultCounter.textContent).toEqual("5 found");
//
//         editor.insertText("s");
//         window.advanceClock(1000);
//         expect(findView.refs.resultCounter.textContent).toEqual("6 found");
//       });
//
//       it("does not beep if no matches were found", () => {
//         editor.setCursorBufferPosition([2, 0]);
//         findView.findEditor.setText("notinthefilebro");
//         atom.commands.dispatch(findView.findEditor.element, "core:confirm");
//         atom.beep.reset();
//         editor.insertText("blah blah");
//         expect(atom.beep).not.toHaveBeenCalled();
//       });
//     });
//
//     describe("when in current selection is toggled", () => {
//       beforeEach(() => {
//         editor.setSelectedBufferRange([[2, 0], [4, 0]]);
//       });
//
//       it("toggles find within a selection via an event and only finds matches within the selection", () => {
//         findView.findEditor.setText("items");
//         atom.commands.dispatch(findView.findEditor.element, "find-and-replace:toggle-selection-option");
//         expect(editor.getSelectedBufferRange()).toEqual([[2, 0], [4, 0]]);
//         expect(findView.refs.resultCounter.textContent).toEqual("3 found");
//       });
//
//       it("toggles find within a selection via button and only finds matches within the selection", () => {
//         findView.findEditor.setText("items");
//         findView.refs.selectionOptionButton.click();
//         expect(editor.getSelectedBufferRange()).toEqual([[2, 0], [4, 0]]);
//         expect(findView.refs.resultCounter.textContent).toEqual("3 found");
//       });
//
//       describe("when there is no selection", () => {
//         beforeEach(() => {
//           editor.setSelectedBufferRange([[0, 0], [0, 0]]);
//         });
//
//         it("toggles find within a selection via an event", () => {
//           findView.findEditor.setText("items");
//           atom.commands.dispatch(findView.findEditor.element, "find-and-replace:toggle-selection-option");
//           expect(editor.getSelectedBufferRange()).toEqual([[1, 22], [1, 27]]);
//           expect(findView.refs.resultCounter.textContent).toEqual("1 of 6");
//         });
//       });
//     });
//
//     describe("when regex is toggled", () => {
//       it("toggles regex via an event and finds text matching the pattern", () => {
//         editor.setCursorBufferPosition([2, 0]);
//         atom.commands.dispatch(findView.findEditor.element, "find-and-replace:toggle-regex-option");
//         findView.findEditor.setText("i[t]em+s");
//         expect(editor.getSelectedBufferRange()).toEqual([[2, 8], [2, 13]]);
//       });
//
//       it("toggles regex via a button and finds text matching the pattern", () => {
//         editor.setCursorBufferPosition([2, 0]);
//         findView.refs.regexOptionButton.click();
//         findView.findEditor.setText("i[t]em+s");
//         expect(editor.getSelectedBufferRange()).toEqual([[2, 8], [2, 13]]);
//       });
//
//       it("re-runs the search using the new find text when toggled", () => {
//         editor.setCursorBufferPosition([1, 0]);
//         findView.findEditor.setText("s(o)rt");
//         atom.commands.dispatch(findView.findEditor.element, "find-and-replace:toggle-regex-option");
//         expect(editor.getSelectedBufferRange()).toEqual([[1, 6], [1, 10]]);
//       });
//
//       describe("when an invalid regex is entered", () => {
//         it("displays an error", () => {
//           editor.setCursorBufferPosition([2, 0]);
//           atom.commands.dispatch(findView.findEditor.element, "find-and-replace:toggle-regex-option");
//           findView.findEditor.setText("i[t");
//           atom.commands.dispatch(findView.findEditor.element, "core:confirm");
//           expect(findView.refs.descriptionLabel).toHaveClass("text-error");
//         });
//       });
//
//       describe("when there are existing selections", () => {
//         it("does not jump to the next match when any selections match the pattern", () => {
//           findView.model.setFindOptions({
//             useRegex: false
//           });
//
//           findView.findEditor.setText("items.length");
//           editor.setSelectedBufferRange([[2, 8], [2, 20]]);
//           findView.refs.regexOptionButton.click();
//           expect(editor.getSelectedBufferRange()).toEqual([[2, 8], [2, 20]]);
//
//           findView.refs.regexOptionButton.click();
//           expect(editor.getSelectedBufferRange()).toEqual([[2, 8], [2, 20]]);
//         });
//
//         it("jumps to the next match when no selections match the pattern", () => {
//           findView.model.setFindOptions({
//             useRegex: false
//           });
//
//           findView.findEditor.setText("pivot ?");
//           editor.setSelectedBufferRange([[6, 16], [6, 23]]);
//           findView.refs.regexOptionButton.click();
//           expect(editor.getSelectedBufferRange()).toEqual([[8, 29], [8, 34]]);
//
//           findView.refs.regexOptionButton.click();
//           expect(editor.getSelectedBufferRange()).toEqual([[6, 16], [6, 23]]);
//         });
//       });
//
//       it("matches astral-plane unicode characters with .", () => {
//         if (!editor.getBuffer().hasAstral) {
//           console.log('Skipping astral-plane test case')
//           return
//         }
//
//         editor.setText("\n\nbefore😄after\n\n");
//         atom.commands.dispatch(findView.findEditor.element, "find-and-replace:toggle-regex-option");
//         findView.findEditor.setText("before.after");
//         atom.commands.dispatch(findView.findEditor.element, "core:confirm");
//         expect(editor.getSelectedBufferRange()).toEqual([[2, 0], [2, 13]])
//       });
//     });
//
//     describe("when whole-word is toggled", () => {
//       it("toggles whole-word via an event and finds text matching the pattern", () => {
//         editor.setCursorBufferPosition([0, 0]);
//         findView.findEditor.setText("sort");
//         atom.commands.dispatch(findView.findEditor.element, "core:confirm");
//         expect(editor.getSelectedBufferRange()).toEqual([[0, 9], [0, 13]]);
//
//         atom.commands.dispatch(findView.findEditor.element, "find-and-replace:toggle-whole-word-option");
//         expect(editor.getSelectedBufferRange()).toEqual([[1, 6], [1, 10]]);
//       });
//
//       it("toggles whole-word via a button and finds text matching the pattern", () => {
//         editor.setCursorBufferPosition([0, 0]);
//         findView.findEditor.setText("sort");
//         atom.commands.dispatch(findView.findEditor.element, "core:confirm");
//         expect(editor.getSelectedBufferRange()).toEqual([[0, 9], [0, 13]]);
//
//         findView.refs.wholeWordOptionButton.click();
//         expect(editor.getSelectedBufferRange()).toEqual([[1, 6], [1, 10]]);
//       });
//
//       it("re-runs the search using the new find text when toggled", () => {
//         editor.setCursorBufferPosition([8, 0]);
//         findView.findEditor.setText("apply");
//         atom.commands.dispatch(findView.findEditor.element, "find-and-replace:toggle-whole-word-option");
//         expect(editor.getSelectedBufferRange()).toEqual([[11, 20], [11, 25]]);
//       });
//
//       describe("when there are existing selections", () => {
//         it("does not jump to the next match when any selections match the pattern", () => {
//           findView.model.setFindOptions({
//             wholeWord: false
//           });
//
//           findView.findEditor.setText("sort");
//           editor.setSelectedBufferRange([[1, 6], [1, 10]]);
//           findView.refs.wholeWordOptionButton.click();
//           expect(editor.getSelectedBufferRange()).toEqual([[1, 6], [1, 10]]);
//
//           findView.refs.wholeWordOptionButton.click();
//           expect(editor.getSelectedBufferRange()).toEqual([[1, 6], [1, 10]]);
//         });
//
//         it("jumps to the next match when no selections match the pattern", () => {
//           findView.model.setFindOptions({
//             wholeWord: false
//           });
//
//           findView.findEditor.setText("sort");
//           editor.setSelectedBufferRange([[0, 9], [0, 13]]);
//           findView.refs.wholeWordOptionButton.click();
//           expect(editor.getSelectedBufferRange()).toEqual([[1, 6], [1, 10]]);
//
//           editor.setSelectedBufferRange([[0, 0], [0, 5]]);
//           findView.refs.wholeWordOptionButton.click();
//           expect(editor.getSelectedBufferRange()).toEqual([[0, 9], [0, 13]]);
//         });
//       });
//     });
//
//     describe("when case sensitivity is toggled", () => {
//       beforeEach(() => {
//         editor.setText("-----\nwords\nWORDs\n");
//         editor.setCursorBufferPosition([0, 0]);
//       });
//
//       it("toggles case sensitivity via an event and finds text matching the pattern", () => {
//         findView.findEditor.setText("WORDs");
//         atom.commands.dispatch(findView.findEditor.element, "core:confirm");
//         expect(editor.getSelectedBufferRange()).toEqual([[1, 0], [1, 5]]);
//
//         editor.setCursorBufferPosition([0, 0]);
//         atom.commands.dispatch(findView.findEditor.element, "find-and-replace:toggle-case-option");
//         expect(editor.getSelectedBufferRange()).toEqual([[2, 0], [2, 5]]);
//       });
//
//       it("toggles case sensitivity via a button and finds text matching the pattern", () => {
//         findView.findEditor.setText("WORDs");
//         atom.commands.dispatch(findView.findEditor.element, "core:confirm");
//         expect(editor.getSelectedBufferRange()).toEqual([[1, 0], [1, 5]]);
//
//         editor.setCursorBufferPosition([0, 0]);
//         findView.refs.caseOptionButton.click();
//         expect(editor.getSelectedBufferRange()).toEqual([[2, 0], [2, 5]]);
//       });
//
//       describe("when there are existing selections", () => {
//         it("does not jump to the next match when any selections match the pattern", () => {
//           findView.model.setFindOptions({
//             caseSensitive: false
//           });
//
//           findView.findEditor.setText("WORDs");
//           editor.setSelectedBufferRange([[2, 0], [2, 5]]);
//           findView.refs.caseOptionButton.click();
//           expect(editor.getSelectedBufferRange()).toEqual([[2, 0], [2, 5]]);
//
//           findView.refs.caseOptionButton.click();
//           expect(editor.getSelectedBufferRange()).toEqual([[2, 0], [2, 5]]);
//         });
//
//         it("jumps to the next match when no selections match the pattern", () => {
//           findView.model.setFindOptions({
//             caseSensitive: false
//           });
//
//           findView.findEditor.setText("WORDs");
//           editor.setSelectedBufferRange([[1, 0], [1, 5]]);
//           findView.refs.caseOptionButton.click();
//           expect(editor.getSelectedBufferRange()).toEqual([[2, 0], [2, 5]]);
//
//           editor.setSelectedBufferRange([[0, 0], [0, 5]]);
//           findView.refs.caseOptionButton.click();
//           expect(editor.getSelectedBufferRange()).toEqual([[1, 0], [1, 5]]);
//         });
//       });
//
//       it("finds unicode characters with case folding", () => {
//         if (!editor.getBuffer().hasAstral) {
//           console.log('Skipping unicode test case')
//           return
//         }
//
//         editor.setText("---\n> április\n---\n")
//         findView.findEditor.setText("Április")
//         atom.commands.dispatch(findView.findEditor.element, "core:confirm")
//         expect(editor.getSelectedBufferRange()).toEqual([[1, 2], [1, 9]])
//       });
//     });
//
//     describe("highlighting search results", () => {
//       function getResultDecoration(clazz) {
//         return getResultDecorations(editor, clazz)[0];
//       }
//
//       it("only highlights matches", () => {
//         expect(getResultDecorations(editor, "find-result")).toHaveLength(5);
//         findView.findEditor.setText("notinthefilebro");
//         atom.commands.dispatch(findView.findEditor.element, "core:confirm");
//         expect(getResultDecorations(editor, "find-result")).toHaveLength(0);
//       });
//
//       it("adds a class to the current match indicating it is the current match", () => {
//         const firstResultMarker = getResultDecoration("current-result");
//         expect(getResultDecorations(editor, "find-result")).toHaveLength(5);
//
//         atom.commands.dispatch(findView.findEditor.element, "core:confirm");
//         atom.commands.dispatch(findView.findEditor.element, "core:confirm");
//         const nextResultMarker = getResultDecoration("current-result");
//         expect(nextResultMarker).not.toEqual(firstResultMarker);
//
//         atom.commands.dispatch(findView.findEditor.element, "find-and-replace:find-previous");
//         atom.commands.dispatch(findView.findEditor.element, "find-and-replace:find-previous");
//         const originalResultMarker = getResultDecoration("current-result");
//         expect(originalResultMarker).toEqual(firstResultMarker);
//       });
//
//       it("adds a class to the result when the current selection equals the result's range", () => {
//         const originalResultMarker = getResultDecoration("current-result");
//         expect(originalResultMarker).toBeDefined();
//
//         editor.setSelectedBufferRange([[5, 16], [5, 20]]);
//         expect(getResultDecoration("current-result")).toBeUndefined();
//
//         editor.setSelectedBufferRange([[5, 16], [5, 21]]);
//         const newResultMarker = getResultDecoration("current-result");
//         expect(newResultMarker).toBeDefined();
//         expect(newResultMarker).not.toBe(originalResultMarker);
//       });
//     });
//
//     describe("when user types in the find editor", () => {
//       function advance() {
//         advanceClock(findView.findEditor.getBuffer().stoppedChangingDelay + 1);
//       }
//
//       beforeEach(() => {
//         findView.findEditor.element.focus();
//       });
//
//       it("scrolls to the first match if the settings scrollToResultOnLiveSearch is true", () => {
//         editorView.style.height = "3px";
//         editor.update({autoHeight: false})
//
//         editorView.component.measureDimensions();
//         editor.moveToTop();
//         atom.config.set("find-and-replace.scrollToResultOnLiveSearch", true);
//         findView.findEditor.setText("Array");
//         advance();
//         expect(editorView.getScrollTop()).toBeGreaterThan(0);
//         expect(editor.getSelectedBufferRange()).toEqual([[11, 14], [11, 19]]);
//         expect(findView.findEditor.element).toHaveFocus();
//       });
//
//       it("doesn't scroll to the first match if the settings scrollToResultOnLiveSearch is false", () => {
//         editorView.style.height = "3px";
//         editor.update({autoHeight: false})
//
//         editorView.component.measureDimensions();
//         editor.moveToTop();
//         atom.config.set("find-and-replace.scrollToResultOnLiveSearch", false);
//         findView.findEditor.setText("Array");
//         advance();
//         expect(editorView.getScrollTop()).toBe(0);
//         expect(editor.getSelectedBufferRange()).toEqual([]);
//         expect(findView.findEditor.element).toHaveFocus();
//       });
//
//       it("updates the search results", () => {
//         expect(findView.refs.descriptionLabel.textContent).toContain("6 results");
//
//         findView.findEditor.setText(
//           "why do I need these 2 lines? The editor does not trigger contents-modified without them"
//         );
//
//         advance();
//         findView.findEditor.setText("");
//         advance();
//         expect(findView.refs.descriptionLabel.textContent).toContain("Find in Current Buffer");
//         expect(findView.element).toHaveFocus();
//
//         findView.findEditor.setText("sort");
//         advance();
//         expect(findView.refs.descriptionLabel.textContent).toContain("5 results");
//         expect(findView.element).toHaveFocus();
//
//         findView.findEditor.setText("items");
//         advance();
//         expect(findView.refs.descriptionLabel.textContent).toContain("6 results");
//         expect(findView.element).toHaveFocus();
//       });
//
//       it("respects the `liveSearchMinimumCharacters` setting", () => {
//         expect(findView.refs.descriptionLabel.textContent).toContain("6 results");
//         atom.config.set("find-and-replace.liveSearchMinimumCharacters", 3);
//
//         findView.findEditor.setText(
//           "why do I need these 2 lines? The editor does not trigger contents-modified without them"
//         );
//
//         advance();
//         findView.findEditor.setText("");
//         advance();
//         expect(findView.refs.descriptionLabel.textContent).toContain("Find in Current Buffer");
//         expect(findView.element).toHaveFocus();
//
//         findView.findEditor.setText("ite");
//         advance();
//         expect(findView.refs.descriptionLabel.textContent).toContain("6 results");
//         expect(findView.element).toHaveFocus();
//
//         findView.findEditor.setText("i");
//         advance();
//         expect(findView.refs.descriptionLabel.textContent).toContain("6 results");
//         expect(findView.element).toHaveFocus();
//
//         findView.findEditor.setText("");
//         advance();
//         expect(findView.refs.descriptionLabel.textContent).toContain("Find in Current Buffer");
//         expect(findView.element).toHaveFocus();
//
//         atom.config.set("find-and-replace.liveSearchMinimumCharacters", 0);
//         findView.findEditor.setText("i");
//         advance();
//         expect(findView.refs.descriptionLabel.textContent).toContain("20 results");
//         expect(findView.element).toHaveFocus();
//       });
//
//       it("doesn't live search on a regex that matches empty string", () => {
//         expect(findView.refs.descriptionLabel.textContent).toContain("6 results");
//
//         atom.commands.dispatch(findView.findEditor.element, "find-and-replace:toggle-regex-option");
//         findView.findEditor.setText("asdf|");
//         advance();
//         expect(findView.refs.descriptionLabel.textContent).toContain("6 results");
//       });
//
//       it("doesn't live search on a invalid regex", () => {
//         expect(findView.refs.descriptionLabel.textContent).toContain("6 results");
//
//         atom.commands.dispatch(findView.findEditor.element, "find-and-replace:toggle-regex-option");
//         findView.findEditor.setText("\\(.*)");
//         advance();
//         expect(findView.refs.descriptionLabel).toHaveClass("text-error");
//         expect(findView.refs.descriptionLabel.textContent).toContain("Invalid regular expression");
//       });
//     });
//
//     describe("when another find is called", () => {
//       it("clears existing markers for another search", () => {
//         findView.findEditor.setText("notinthefile");
//         atom.commands.dispatch(findView.findEditor.element, "core:confirm");
//         expect(getResultDecorations(editor, "find-result")).toHaveLength(0);
//       });
//
//       it("clears existing markers for an empty search", () => {
//         findView.findEditor.setText("");
//         atom.commands.dispatch(findView.findEditor.element, "core:confirm");
//         expect(getResultDecorations(editor, "find-result")).toHaveLength(0);
//       });
//     });
//   });
//
//   it("doesn't throw an exception when toggling the regex option with an invalid pattern before performing any other search (regression)", async () => {
//     atom.commands.dispatch(editorView, 'find-and-replace:show');
//     await activationPromise;
//
//     findView.findEditor.setText('(');
//     atom.commands.dispatch(findView.findEditor.element, 'find-and-replace:toggle-regex-option');
//
//     editor.insertText('hi');
//     advanceClock(editor.getBuffer().stoppedChangingDelay);
//   });
//
//   describe("replacing", () => {
//     beforeEach(async () => {
//       editor.setCursorBufferPosition([2, 0]);
//       atom.commands.dispatch(editorView, "find-and-replace:show-replace");
//
//       await activationPromise;
//
//       findView.findEditor.setText("items");
//       findView.replaceEditor.setText("cats");
//     });
//
//     describe("when the find string is empty", () => {
//       it("beeps", () => {
//         findView.findEditor.setText("");
//         atom.commands.dispatch(findView.replaceEditor.element, "core:confirm");
//         expect(atom.beep).toHaveBeenCalled();
//       });
//     });
//
//     describe("when the replacement string contains an escaped char", () => {
//       describe("when the regex option is chosen", () => {
//         beforeEach(() => {
//           atom.commands.dispatch(findView.findEditor.element, "find-and-replace:toggle-regex-option");
//         });
//
//         it("inserts newlines and tabs", () => {
//           findView.replaceEditor.setText("\\n\\t");
//           atom.commands.dispatch(findView.replaceEditor.element, "core:confirm");
//           expect(editor.getText()).toMatch(/\n\t/);
//         });
//
//         it("doesn't insert a escaped char if there are multiple backslashes in front of the char", () => {
//           findView.replaceEditor.setText("\\\\t\\\t");
//           atom.commands.dispatch(findView.replaceEditor.element, "core:confirm");
//           expect(editor.getText()).toMatch(/\\t\\\t/);
//         });
//       });
//
//       describe("when in normal mode", () => {
//         it("inserts backslash n and t", () => {
//           findView.replaceEditor.setText("\\t\\n");
//           atom.commands.dispatch(findView.replaceEditor.element, "core:confirm");
//           expect(editor.getText()).toMatch(/\\t\\n/);
//         });
//
//         it("inserts carriage returns", () => {
//           const textWithCarriageReturns = editor.getText().replace(/\n/g, "\r");
//           editor.setText(textWithCarriageReturns);
//           findView.replaceEditor.setText("\\t\\r");
//           atom.commands.dispatch(findView.replaceEditor.element, "core:confirm");
//           expect(editor.getText()).toMatch(/\\t\\r/);
//         });
//       });
//     });
//
//     describe("replace next", () => {
//       describe("when core:confirm is triggered", () => {
//         it("replaces the match after the cursor and selects the next match", () => {
//           atom.commands.dispatch(findView.replaceEditor.element, "core:confirm");
//           expect(findView.refs.resultCounter.textContent).toEqual("2 of 5");
//           expect(editor.lineTextForBufferRow(2)).toBe("    if (cats.length <= 1) return items;");
//           expect(editor.getSelectedBufferRange()).toEqual([[2, 33], [2, 38]]);
//         });
//
//         it("replaceEditor maintains focus after core:confirm is run", () => {
//           findView.replaceEditor.element.focus();
//           atom.commands.dispatch(findView.replaceEditor.element, "core:confirm");
//           expect(findView.replaceEditor.element).toHaveFocus();
//         });
//
//         it("replaces the _current_ match and selects the next match", () => {
//           atom.commands.dispatch(findView.findEditor.element, "core:confirm");
//           editor.setSelectedBufferRange([[2, 8], [2, 13]]);
//           expect(findView.refs.resultCounter.textContent).toEqual("2 of 6");
//
//           atom.commands.dispatch(findView.replaceEditor.element, "core:confirm");
//           expect(findView.refs.resultCounter.textContent).toEqual("2 of 5");
//           expect(editor.lineTextForBufferRow(2)).toBe("    if (cats.length <= 1) return items;");
//           expect(editor.getSelectedBufferRange()).toEqual([[2, 33], [2, 38]]);
//
//           atom.commands.dispatch(findView.replaceEditor.element, "core:confirm");
//           expect(findView.refs.resultCounter.textContent).toEqual("2 of 4");
//           expect(editor.lineTextForBufferRow(2)).toBe("    if (cats.length <= 1) return cats;");
//           expect(editor.getSelectedBufferRange()).toEqual([[3, 16], [3, 21]]);
//         });
//
//         it("replaces the _current_ match and selects the next match", () => {
//           editor.setText(
//             "Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s"
//           );
//
//           editor.setSelectedBufferRange([[0, 0], [0, 5]]);
//           findView.findEditor.setText("Lorem");
//           findView.replaceEditor.setText("replacement");
//           atom.commands.dispatch(findView.replaceEditor.element, "core:confirm");
//
//           expect(editor.lineTextForBufferRow(0)).toBe(
//             "replacement Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s"
//           );
//
//           expect(editor.getSelectedBufferRange()).toEqual([[0, 81], [0, 86]]);
//         });
//       });
//
//       describe("when the replace next button is pressed", () => {
//         it("replaces the match after the cursor and selects the next match", () => {
//           findView.refs.replaceNextButton.click();
//           expect(findView.refs.resultCounter.textContent).toEqual("2 of 5");
//           expect(editor.lineTextForBufferRow(2)).toBe("    if (cats.length <= 1) return items;");
//           expect(editor.getSelectedBufferRange()).toEqual([[2, 33], [2, 38]]);
//           expect(findView.replaceEditor.element).toHaveFocus();
//         });
//       });
//
//       describe("when the 'find-and-replace:replace-next' event is triggered", () => {
//         it("replaces the match after the cursor and selects the next match", () => {
//           atom.commands.dispatch(editorView, "find-and-replace:replace-next");
//           expect(findView.refs.resultCounter.textContent).toEqual("2 of 5");
//           expect(editor.lineTextForBufferRow(2)).toBe("    if (cats.length <= 1) return items;");
//           expect(editor.getSelectedBufferRange()).toEqual([[2, 33], [2, 38]]);
//         });
//       });
//     });
//
//     describe("replace previous", () => {
//       describe("when command is triggered", () => {
//         it("replaces the match after the cursor and selects the previous match", () => {
//           atom.commands.dispatch(findView.findEditor.element, "core:confirm");
//           atom.commands.dispatch(findView.element, "find-and-replace:replace-previous");
//           expect(findView.refs.resultCounter.textContent).toEqual("1 of 5");
//           expect(editor.lineTextForBufferRow(2)).toBe("    if (cats.length <= 1) return items;");
//           expect(editor.getSelectedBufferRange()).toEqual([[1, 22], [1, 27]]);
//         });
//       });
//     });
//
//     describe("replace all", () => {
//       describe("when the replace all button is pressed", () => {
//         it("replaces all matched text", () => {
//           findView.refs.replaceAllButton.click();
//           expect(findView.refs.resultCounter.textContent).toEqual("no results");
//           expect(editor.getText()).not.toMatch(/items/);
//           expect(editor.getText().match(/\bcats\b/g)).toHaveLength(6);
//           expect(editor.getSelectedBufferRange()).toEqual([[2, 0], [2, 0]]);
//         });
//
//         it("all changes are undoable in one transaction", () => {
//           findView.refs.replaceAllButton.click();
//           editor.undo();
//           expect(editor.getText()).not.toMatch(/\bcats\b/g);
//         });
//       });
//
//       describe("when the 'find-and-replace:replace-all' event is triggered", () => {
//         it("replaces all matched text", () => {
//           atom.commands.dispatch(editorView, "find-and-replace:replace-all");
//           expect(findView.refs.resultCounter.textContent).toEqual("no results");
//           expect(editor.getText()).not.toMatch(/items/);
//           expect(editor.getText().match(/\bcats\b/g)).toHaveLength(6);
//           expect(editor.getSelectedBufferRange()).toEqual([[2, 0], [2, 0]]);
//         });
//       });
//     });
//
//     describe("replacement patterns", () => {
//       describe("when the regex option is true", () => {
//         it("replaces $1, $2, etc... with substring matches", () => {
//           atom.commands.dispatch(findView.findEditor.element, "find-and-replace:toggle-regex-option");
//           findView.findEditor.setText("(items)([\\.;])");
//           findView.replaceEditor.setText("$2$1");
//           atom.commands.dispatch(editorView, "find-and-replace:replace-all");
//           expect(editor.getText()).toMatch(/;items/);
//           expect(editor.getText()).toMatch(/\.items/);
//         });
//       });
//
//       describe("when the regex option is false", () => {
//         it("replaces the matches with without any regex subsitions", () => {
//           findView.findEditor.setText("items");
//           findView.replaceEditor.setText("$&cats");
//           atom.commands.dispatch(editorView, "find-and-replace:replace-all");
//           expect(editor.getText()).not.toMatch(/items/);
//           expect(editor.getText().match(/\$&cats\b/g)).toHaveLength(6);
//         });
//       });
//     });
//   });
//
//   describe("history", () => {
//     beforeEach(async () => {
//       atom.commands.dispatch(editorView, "find-and-replace:show");
//       await activationPromise;
//     });
//
//     describe("when there is no history", () => {
//       it("retains unsearched text", () => {
//         const text = "something I want to search for but havent yet";
//         findView.findEditor.setText(text);
//         atom.commands.dispatch(findView.findEditor.element, "core:move-up");
//         expect(findView.findEditor.getText()).toEqual("");
//
//         atom.commands.dispatch(findView.findEditor.element, "core:move-down");
//         expect(findView.findEditor.getText()).toEqual(text);
//       });
//     });
//
//     describe("when there is history", () => {
//       const [oneRange, twoRange, threeRange] = [];
//
//       beforeEach(() => {
//         atom.commands.dispatch(editorView, "find-and-replace:show");
//         editor.setText("zero\none\ntwo\nthree\n");
//         findView.findEditor.setText("one");
//         atom.commands.dispatch(findView.findEditor.element, "core:confirm");
//         findView.findEditor.setText("two");
//         atom.commands.dispatch(findView.findEditor.element, "core:confirm");
//         findView.findEditor.setText("three");
//         atom.commands.dispatch(findView.findEditor.element, "core:confirm");
//       });
//
//       it("can navigate the entire history stack", () => {
//         expect(findView.findEditor.getText()).toEqual("three");
//
//         atom.commands.dispatch(findView.findEditor.element, "core:move-down");
//         expect(findView.findEditor.getText()).toEqual("");
//
//         atom.commands.dispatch(findView.findEditor.element, "core:move-down");
//         expect(findView.findEditor.getText()).toEqual("");
//
//         atom.commands.dispatch(findView.findEditor.element, "core:move-up");
//         expect(findView.findEditor.getText()).toEqual("three");
//
//         atom.commands.dispatch(findView.findEditor.element, "core:move-up");
//         expect(findView.findEditor.getText()).toEqual("two");
//
//         atom.commands.dispatch(findView.findEditor.element, "core:move-up");
//         expect(findView.findEditor.getText()).toEqual("one");
//
//         atom.commands.dispatch(findView.findEditor.element, "core:move-up");
//         expect(findView.findEditor.getText()).toEqual("one");
//
//         atom.commands.dispatch(findView.findEditor.element, "core:move-down");
//         expect(findView.findEditor.getText()).toEqual("two");
//       });
//
//       it("retains the current unsearched text", () => {
//         const text = "something I want to search for but havent yet";
//         findView.findEditor.setText(text);
//         atom.commands.dispatch(findView.findEditor.element, "core:move-up");
//         expect(findView.findEditor.getText()).toEqual("three");
//
//         atom.commands.dispatch(findView.findEditor.element, "core:move-down");
//         expect(findView.findEditor.getText()).toEqual(text);
//
//         atom.commands.dispatch(findView.findEditor.element, "core:move-up");
//         expect(findView.findEditor.getText()).toEqual("three");
//
//         atom.commands.dispatch(findView.findEditor.element, "core:move-down");
//         atom.commands.dispatch(findView.findEditor.element, "core:confirm");
//         atom.commands.dispatch(findView.findEditor.element, "core:move-down");
//         expect(findView.findEditor.getText()).toEqual("");
//       });
//
//       it("adds confirmed patterns to the history", () => {
//         findView.findEditor.setText("cool stuff");
//         atom.commands.dispatch(findView.findEditor.element, "core:confirm");
//         findView.findEditor.setText("cooler stuff");
//         atom.commands.dispatch(findView.findEditor.element, "core:move-up");
//         expect(findView.findEditor.getText()).toEqual("cool stuff");
//
//         atom.commands.dispatch(findView.findEditor.element, "core:move-up");
//         expect(findView.findEditor.getText()).toEqual("three");
//       });
//
//       describe("when user types in the find editor", () => {
//         function advance() {
//           advanceClock(findView.findEditor.getBuffer().stoppedChangingDelay + 1);
//         }
//
//         beforeEach(() => {
//           findView.findEditor.element.focus();
//         });
//
//         it("does not add live searches to the history", () => {
//           expect(findView.refs.descriptionLabel.textContent).toContain("1 result");
//
//           findView.findEditor.setText("FIXME: necessary search for some reason??");
//           advance();
//           findView.findEditor.setText("nope");
//           advance();
//           expect(findView.refs.descriptionLabel.textContent).toContain("nope");
//
//           findView.findEditor.setText("zero");
//           advance();
//           expect(findView.refs.descriptionLabel.textContent).toContain("zero");
//
//           atom.commands.dispatch(findView.findEditor.element, "core:move-up");
//           expect(findView.findEditor.getText()).toEqual("three");
//         });
//       });
//     });
//   });
//
//   describe("panel focus", () => {
//     beforeEach(async () => {
//       atom.commands.dispatch(editorView, "find-and-replace:show");
//       await activationPromise;
//     });
//
//     it("focuses the find editor when the panel gets focus", () => {
//       findView.replaceEditor.element.focus();
//       expect(findView.replaceEditor.element).toHaveFocus();
//       findView.element.focus();
//       expect(findView.findEditor.element).toHaveFocus();
//     });
//
//     it("moves focus between editors with find-and-replace:focus-next", () => {
//       findView.findEditor.element.focus();
//       expect(findView.findEditor.element).toHaveClass("is-focused");
//       expect(findView.replaceEditor).not.toHaveClass("is-focused");
//
//       atom.commands.dispatch(findView.findEditor.element, "find-and-replace:focus-next");
//       expect(findView.findEditor.element).not.toHaveClass("is-focused");
//       expect(findView.replaceEditor.element).toHaveClass("is-focused");
//
//       atom.commands.dispatch(findView.replaceEditor.element, "find-and-replace:focus-next");
//       expect(findView.findEditor.element).toHaveClass("is-focused");
//       expect(findView.replaceEditor.element).not.toHaveClass("is-focused");
//     });
//   });
//
//   describe("when language-javascript is active", () => {
//     beforeEach(async () => {
//       await atom.packages.activatePackage("language-javascript");
//     });
//
//     it("uses the regexp grammar when regex-mode is loaded from configuration", async () => {
//       atom.config.set("find-and-replace.useRegex", true);
//       atom.commands.dispatch(editorView, "find-and-replace:show");
//       await activationPromise;
//
//       expect(findView.model.getFindOptions().useRegex).toBe(true);
//       expect(findView.findEditor.getGrammar().scopeName).toBe("source.js.regexp");
//       expect(findView.replaceEditor.getGrammar().scopeName).toBe("source.js.regexp.replacement");
//     });
//
//     describe("when panel is active", () => {
//       beforeEach(async () => {
//         atom.commands.dispatch(editorView, "find-and-replace:show");
//         await activationPromise;
//       });
//
//       it("does not use regexp grammar when in non-regex mode", () => {
//         expect(findView.model.getFindOptions().useRegex).not.toBe(true);
//         expect(findView.findEditor.getGrammar().scopeName).toBe("text.plain.null-grammar");
//         expect(findView.replaceEditor.getGrammar().scopeName).toBe("text.plain.null-grammar");
//       });
//
//       it("uses regexp grammar when in regex mode and clears the regexp grammar when regex is disabled", () => {
//         atom.commands.dispatch(findView.findEditor.element, "find-and-replace:toggle-regex-option");
//         expect(findView.model.getFindOptions().useRegex).toBe(true);
//         expect(findView.findEditor.getGrammar().scopeName).toBe("source.js.regexp");
//         expect(findView.replaceEditor.getGrammar().scopeName).toBe("source.js.regexp.replacement");
//
//         atom.commands.dispatch(findView.findEditor.element, "find-and-replace:toggle-regex-option");
//         expect(findView.model.getFindOptions().useRegex).not.toBe(true);
//         expect(findView.findEditor.getGrammar().scopeName).toBe("text.plain.null-grammar");
//         expect(findView.replaceEditor.getGrammar().scopeName).toBe("text.plain.null-grammar");
//       });
//     });
//   });
//
//   describe("when no buffer is open", () => {
//     it("toggles regex via an event and finds text matching the pattern", async () => {
//       atom.commands.dispatch(editorView, "find-and-replace:show");
//       editor.destroy();
//       await activationPromise;
//
//       findView.findEditor.setText("items");
//       atom.commands.dispatch(findView.findEditor.element, "find-and-replace:toggle-regex-option");
//       expect(findView.model.getFindOptions().useRegex).toBe(true);
//       expect(findView.refs.descriptionLabel.textContent).toContain("No results");
//     });
//
//     it("toggles selection via an event and finds text matching the pattern", async () => {
//       atom.commands.dispatch(editorView, "find-and-replace:show");
//       editor.destroy();
//       await activationPromise;
//
//       findView.findEditor.setText("items");
//       atom.commands.dispatch(findView.findEditor.element, "find-and-replace:toggle-selection-option");
//       expect(findView.model.getFindOptions().inCurrentSelection).toBe(true);
//       expect(findView.refs.descriptionLabel.textContent).toContain("No results");
//     });
//   });
// });
