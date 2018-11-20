/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as assert from 'assert';
import { CoreEditingCommands, CoreNavigationCommands } from 'vs/editor/browser/controller/coreCommands';
import { IEditorOptions } from 'vs/editor/common/config/editorOptions';
import { Cursor, CursorStateChangedEvent } from 'vs/editor/common/controller/cursor';
import { EditOperation } from 'vs/editor/common/core/editOperation';
import { Position } from 'vs/editor/common/core/position';
import { Range } from 'vs/editor/common/core/range';
import { Selection } from 'vs/editor/common/core/selection';
import { TokenizationResult2 } from 'vs/editor/common/core/token';
import { Handler, ICommand, ICursorStateComputerData, IEditOperationBuilder } from 'vs/editor/common/editorCommon';
import { EndOfLinePreference, EndOfLineSequence, ITextModel } from 'vs/editor/common/model';
import { TextModel } from 'vs/editor/common/model/textModel';
import { IState, ITokenizationSupport, LanguageIdentifier, TokenizationRegistry } from 'vs/editor/common/modes';
import { IndentAction, IndentationRule } from 'vs/editor/common/modes/languageConfiguration';
import { LanguageConfigurationRegistry } from 'vs/editor/common/modes/languageConfigurationRegistry';
import { NULL_STATE } from 'vs/editor/common/modes/nullMode';
import { ViewModel } from 'vs/editor/common/viewModel/viewModelImpl';
import { withTestCodeEditor } from 'vs/editor/test/browser/testCodeEditor';
import { IRelaxedTextModelCreationOptions, createTextModel } from 'vs/editor/test/common/editorTestUtils';
import { MockMode } from 'vs/editor/test/common/mocks/mockMode';
import { TestConfiguration } from 'vs/editor/test/common/mocks/testConfiguration';
import { javascriptOnEnterRules } from 'vs/editor/test/common/modes/supports/javascriptOnEnterRules';

const H = Handler;

// --------- utils

function cursorCommand(cursor: Cursor, command: string, extraData?: any, overwriteSource?: string) {
	cursor.trigger(overwriteSource || 'tests', command, extraData);
}

function cursorCommandAndTokenize(model: TextModel, cursor: Cursor, command: string, extraData?: any, overwriteSource?: string) {
	cursor.trigger(overwriteSource || 'tests', command, extraData);
	model.forceTokenization(model.getLineCount());
}

function moveTo(cursor: Cursor, lineNumber: number, column: number, inSelectionMode: boolean = false) {
	if (inSelectionMode) {
		CoreNavigationCommands.MoveToSelect.runCoreEditorCommand(cursor, {
			position: new Position(lineNumber, column)
		});
	} else {
		CoreNavigationCommands.MoveTo.runCoreEditorCommand(cursor, {
			position: new Position(lineNumber, column)
		});
	}
}

function moveLeft(cursor: Cursor, inSelectionMode: boolean = false) {
	if (inSelectionMode) {
		CoreNavigationCommands.CursorLeftSelect.runCoreEditorCommand(cursor, {});
	} else {
		CoreNavigationCommands.CursorLeft.runCoreEditorCommand(cursor, {});
	}
}

function moveRight(cursor: Cursor, inSelectionMode: boolean = false) {
	if (inSelectionMode) {
		CoreNavigationCommands.CursorRightSelect.runCoreEditorCommand(cursor, {});
	} else {
		CoreNavigationCommands.CursorRight.runCoreEditorCommand(cursor, {});
	}
}

function moveDown(cursor: Cursor, inSelectionMode: boolean = false) {
	if (inSelectionMode) {
		CoreNavigationCommands.CursorDownSelect.runCoreEditorCommand(cursor, {});
	} else {
		CoreNavigationCommands.CursorDown.runCoreEditorCommand(cursor, {});
	}
}

function moveUp(cursor: Cursor, inSelectionMode: boolean = false) {
	if (inSelectionMode) {
		CoreNavigationCommands.CursorUpSelect.runCoreEditorCommand(cursor, {});
	} else {
		CoreNavigationCommands.CursorUp.runCoreEditorCommand(cursor, {});
	}
}

function moveToBeginningOfLine(cursor: Cursor, inSelectionMode: boolean = false) {
	if (inSelectionMode) {
		CoreNavigationCommands.CursorHomeSelect.runCoreEditorCommand(cursor, {});
	} else {
		CoreNavigationCommands.CursorHome.runCoreEditorCommand(cursor, {});
	}
}

function moveToEndOfLine(cursor: Cursor, inSelectionMode: boolean = false) {
	if (inSelectionMode) {
		CoreNavigationCommands.CursorEndSelect.runCoreEditorCommand(cursor, {});
	} else {
		CoreNavigationCommands.CursorEnd.runCoreEditorCommand(cursor, {});
	}
}

function moveToBeginningOfBuffer(cursor: Cursor, inSelectionMode: boolean = false) {
	if (inSelectionMode) {
		CoreNavigationCommands.CursorTopSelect.runCoreEditorCommand(cursor, {});
	} else {
		CoreNavigationCommands.CursorTop.runCoreEditorCommand(cursor, {});
	}
}

function moveToEndOfBuffer(cursor: Cursor, inSelectionMode: boolean = false) {
	if (inSelectionMode) {
		CoreNavigationCommands.CursorBottomSelect.runCoreEditorCommand(cursor, {});
	} else {
		CoreNavigationCommands.CursorBottom.runCoreEditorCommand(cursor, {});
	}
}

function assertCursor(cursor: Cursor, what: Position | Selection | Selection[]): void {
	let selections: Selection[];
	if (what instanceof Position) {
		selections = [new Selection(what.lineNumber, what.column, what.lineNumber, what.column)];
	} else if (what instanceof Selection) {
		selections = [what];
	} else {
		selections = what;
	}
	let actual = cursor.getSelections().map(s => s.toString());
	let expected = selections.map(s => s.toString());

	assert.deepEqual(actual, expected);
}

suite('Editor Controller - Cursor', () => {
	const LINE1 = '    \tMy First Line\t ';
	const LINE2 = '\tMy Second Line';
	const LINE3 = '    Third Line🐶';
	const LINE4 = '';
	const LINE5 = '1';

	let thisModel: TextModel;
	let thisConfiguration: TestConfiguration;
	let thisViewModel: ViewModel;
	let thisCursor: Cursor;

	setup(() => {
		let text =
			LINE1 + '\r\n' +
			LINE2 + '\n' +
			LINE3 + '\n' +
			LINE4 + '\r\n' +
			LINE5;

		thisModel = createTextModel(text);
		thisConfiguration = new TestConfiguration(null);
		thisViewModel = new ViewModel(0, thisConfiguration, thisModel, null);

		thisCursor = new Cursor(thisConfiguration, thisModel, thisViewModel);
	});

	teardown(() => {
		thisCursor.dispose();
		thisViewModel.dispose();
		thisModel.dispose();
		thisConfiguration.dispose();
	});

	test('cursor initialized', () => {
		assertCursor(thisCursor, new Position(1, 1));
	});

	// --------- absolute move

	test('no move', () => {
		moveTo(thisCursor, 1, 1);
		assertCursor(thisCursor, new Position(1, 1));
	});

	test('move', () => {
		moveTo(thisCursor, 1, 2);
		assertCursor(thisCursor, new Position(1, 2));
	});

	test('move in selection mode', () => {
		moveTo(thisCursor, 1, 2, true);
		assertCursor(thisCursor, new Selection(1, 1, 1, 2));
	});

	test('move beyond line end', () => {
		moveTo(thisCursor, 1, 25);
		assertCursor(thisCursor, new Position(1, LINE1.length + 1));
	});

	test('move empty line', () => {
		moveTo(thisCursor, 4, 20);
		assertCursor(thisCursor, new Position(4, 1));
	});

	test('move one char line', () => {
		moveTo(thisCursor, 5, 20);
		assertCursor(thisCursor, new Position(5, 2));
	});

	test('selection down', () => {
		moveTo(thisCursor, 2, 1, true);
		assertCursor(thisCursor, new Selection(1, 1, 2, 1));
	});

	test('move and then select', () => {
		moveTo(thisCursor, 2, 3);
		assertCursor(thisCursor, new Position(2, 3));

		moveTo(thisCursor, 2, 15, true);
		assertCursor(thisCursor, new Selection(2, 3, 2, 15));

		moveTo(thisCursor, 1, 2, true);
		assertCursor(thisCursor, new Selection(2, 3, 1, 2));
	});

	// --------- move left

	test('move left on top left position', () => {
		moveLeft(thisCursor);
		assertCursor(thisCursor, new Position(1, 1));
	});

	test('move left', () => {
		moveTo(thisCursor, 1, 3);
		assertCursor(thisCursor, new Position(1, 3));
		moveLeft(thisCursor);
		assertCursor(thisCursor, new Position(1, 2));
	});

	test('move left with surrogate pair', () => {
		moveTo(thisCursor, 3, 17);
		assertCursor(thisCursor, new Position(3, 17));
		moveLeft(thisCursor);
		assertCursor(thisCursor, new Position(3, 15));
	});

	test('move left goes to previous row', () => {
		moveTo(thisCursor, 2, 1);
		assertCursor(thisCursor, new Position(2, 1));
		moveLeft(thisCursor);
		assertCursor(thisCursor, new Position(1, 21));
	});

	test('move left selection', () => {
		moveTo(thisCursor, 2, 1);
		assertCursor(thisCursor, new Position(2, 1));
		moveLeft(thisCursor, true);
		assertCursor(thisCursor, new Selection(2, 1, 1, 21));
	});

	// --------- move right

	test('move right on bottom right position', () => {
		moveTo(thisCursor, 5, 2);
		assertCursor(thisCursor, new Position(5, 2));
		moveRight(thisCursor);
		assertCursor(thisCursor, new Position(5, 2));
	});

	test('move right', () => {
		moveTo(thisCursor, 1, 3);
		assertCursor(thisCursor, new Position(1, 3));
		moveRight(thisCursor);
		assertCursor(thisCursor, new Position(1, 4));
	});

	test('move right with surrogate pair', () => {
		moveTo(thisCursor, 3, 15);
		assertCursor(thisCursor, new Position(3, 15));
		moveRight(thisCursor);
		assertCursor(thisCursor, new Position(3, 17));
	});

	test('move right goes to next row', () => {
		moveTo(thisCursor, 1, 21);
		assertCursor(thisCursor, new Position(1, 21));
		moveRight(thisCursor);
		assertCursor(thisCursor, new Position(2, 1));
	});

	test('move right selection', () => {
		moveTo(thisCursor, 1, 21);
		assertCursor(thisCursor, new Position(1, 21));
		moveRight(thisCursor, true);
		assertCursor(thisCursor, new Selection(1, 21, 2, 1));
	});

	// --------- move down

	test('move down', () => {
		moveDown(thisCursor);
		assertCursor(thisCursor, new Position(2, 1));
		moveDown(thisCursor);
		assertCursor(thisCursor, new Position(3, 1));
		moveDown(thisCursor);
		assertCursor(thisCursor, new Position(4, 1));
		moveDown(thisCursor);
		assertCursor(thisCursor, new Position(5, 1));
		moveDown(thisCursor);
		assertCursor(thisCursor, new Position(5, 2));
	});

	test('move down with selection', () => {
		moveDown(thisCursor, true);
		assertCursor(thisCursor, new Selection(1, 1, 2, 1));
		moveDown(thisCursor, true);
		assertCursor(thisCursor, new Selection(1, 1, 3, 1));
		moveDown(thisCursor, true);
		assertCursor(thisCursor, new Selection(1, 1, 4, 1));
		moveDown(thisCursor, true);
		assertCursor(thisCursor, new Selection(1, 1, 5, 1));
		moveDown(thisCursor, true);
		assertCursor(thisCursor, new Selection(1, 1, 5, 2));
	});

	test('move down with tabs', () => {
		moveTo(thisCursor, 1, 5);
		assertCursor(thisCursor, new Position(1, 5));
		moveDown(thisCursor);
		assertCursor(thisCursor, new Position(2, 2));
		moveDown(thisCursor);
		assertCursor(thisCursor, new Position(3, 5));
		moveDown(thisCursor);
		assertCursor(thisCursor, new Position(4, 1));
		moveDown(thisCursor);
		assertCursor(thisCursor, new Position(5, 2));
	});

	// --------- move up

	test('move up', () => {
		moveTo(thisCursor, 3, 5);
		assertCursor(thisCursor, new Position(3, 5));

		moveUp(thisCursor);
		assertCursor(thisCursor, new Position(2, 2));

		moveUp(thisCursor);
		assertCursor(thisCursor, new Position(1, 5));
	});

	test('move up with selection', () => {
		moveTo(thisCursor, 3, 5);
		assertCursor(thisCursor, new Position(3, 5));

		moveUp(thisCursor, true);
		assertCursor(thisCursor, new Selection(3, 5, 2, 2));

		moveUp(thisCursor, true);
		assertCursor(thisCursor, new Selection(3, 5, 1, 5));
	});

	test('move up and down with tabs', () => {
		moveTo(thisCursor, 1, 5);
		assertCursor(thisCursor, new Position(1, 5));
		moveDown(thisCursor);
		moveDown(thisCursor);
		moveDown(thisCursor);
		moveDown(thisCursor);
		assertCursor(thisCursor, new Position(5, 2));
		moveUp(thisCursor);
		assertCursor(thisCursor, new Position(4, 1));
		moveUp(thisCursor);
		assertCursor(thisCursor, new Position(3, 5));
		moveUp(thisCursor);
		assertCursor(thisCursor, new Position(2, 2));
		moveUp(thisCursor);
		assertCursor(thisCursor, new Position(1, 5));
	});

	test('move up and down with end of lines starting from a long one', () => {
		moveToEndOfLine(thisCursor);
		assertCursor(thisCursor, new Position(1, LINE1.length + 1));
		moveToEndOfLine(thisCursor);
		assertCursor(thisCursor, new Position(1, LINE1.length + 1));
		moveDown(thisCursor);
		assertCursor(thisCursor, new Position(2, LINE2.length + 1));
		moveDown(thisCursor);
		assertCursor(thisCursor, new Position(3, LINE3.length + 1));
		moveDown(thisCursor);
		assertCursor(thisCursor, new Position(4, LINE4.length + 1));
		moveDown(thisCursor);
		assertCursor(thisCursor, new Position(5, LINE5.length + 1));
		moveUp(thisCursor);
		moveUp(thisCursor);
		moveUp(thisCursor);
		moveUp(thisCursor);
		assertCursor(thisCursor, new Position(1, LINE1.length + 1));
	});

	// --------- move to beginning of line

	test('move to beginning of line', () => {
		moveToBeginningOfLine(thisCursor);
		assertCursor(thisCursor, new Position(1, 6));
		moveToBeginningOfLine(thisCursor);
		assertCursor(thisCursor, new Position(1, 1));
	});

	test('move to beginning of line from within line', () => {
		moveTo(thisCursor, 1, 8);
		moveToBeginningOfLine(thisCursor);
		assertCursor(thisCursor, new Position(1, 6));
		moveToBeginningOfLine(thisCursor);
		assertCursor(thisCursor, new Position(1, 1));
	});

	test('move to beginning of line from whitespace at beginning of line', () => {
		moveTo(thisCursor, 1, 2);
		moveToBeginningOfLine(thisCursor);
		assertCursor(thisCursor, new Position(1, 6));
		moveToBeginningOfLine(thisCursor);
		assertCursor(thisCursor, new Position(1, 1));
	});

	test('move to beginning of line from within line selection', () => {
		moveTo(thisCursor, 1, 8);
		moveToBeginningOfLine(thisCursor, true);
		assertCursor(thisCursor, new Selection(1, 8, 1, 6));
		moveToBeginningOfLine(thisCursor, true);
		assertCursor(thisCursor, new Selection(1, 8, 1, 1));
	});

	test('move to beginning of line with selection multiline forward', () => {
		moveTo(thisCursor, 1, 8);
		moveTo(thisCursor, 3, 9, true);
		moveToBeginningOfLine(thisCursor, false);
		assertCursor(thisCursor, new Selection(3, 5, 3, 5));
	});

	test('move to beginning of line with selection multiline backward', () => {
		moveTo(thisCursor, 3, 9);
		moveTo(thisCursor, 1, 8, true);
		moveToBeginningOfLine(thisCursor, false);
		assertCursor(thisCursor, new Selection(1, 6, 1, 6));
	});

	test('move to beginning of line with selection single line forward', () => {
		moveTo(thisCursor, 3, 2);
		moveTo(thisCursor, 3, 9, true);
		moveToBeginningOfLine(thisCursor, false);
		assertCursor(thisCursor, new Selection(3, 5, 3, 5));
	});

	test('move to beginning of line with selection single line backward', () => {
		moveTo(thisCursor, 3, 9);
		moveTo(thisCursor, 3, 2, true);
		moveToBeginningOfLine(thisCursor, false);
		assertCursor(thisCursor, new Selection(3, 5, 3, 5));
	});

	test('issue #15401: "End" key is behaving weird when text is selected part 1', () => {
		moveTo(thisCursor, 1, 8);
		moveTo(thisCursor, 3, 9, true);
		moveToBeginningOfLine(thisCursor, false);
		assertCursor(thisCursor, new Selection(3, 5, 3, 5));
	});

	test('issue #17011: Shift+home/end now go to the end of the selection start\'s line, not the selection\'s end', () => {
		moveTo(thisCursor, 1, 8);
		moveTo(thisCursor, 3, 9, true);
		moveToBeginningOfLine(thisCursor, true);
		assertCursor(thisCursor, new Selection(1, 8, 3, 5));
	});

	// --------- move to end of line

	test('move to end of line', () => {
		moveToEndOfLine(thisCursor);
		assertCursor(thisCursor, new Position(1, LINE1.length + 1));
		moveToEndOfLine(thisCursor);
		assertCursor(thisCursor, new Position(1, LINE1.length + 1));
	});

	test('move to end of line from within line', () => {
		moveTo(thisCursor, 1, 6);
		moveToEndOfLine(thisCursor);
		assertCursor(thisCursor, new Position(1, LINE1.length + 1));
		moveToEndOfLine(thisCursor);
		assertCursor(thisCursor, new Position(1, LINE1.length + 1));
	});

	test('move to end of line from whitespace at end of line', () => {
		moveTo(thisCursor, 1, 20);
		moveToEndOfLine(thisCursor);
		assertCursor(thisCursor, new Position(1, LINE1.length + 1));
		moveToEndOfLine(thisCursor);
		assertCursor(thisCursor, new Position(1, LINE1.length + 1));
	});

	test('move to end of line from within line selection', () => {
		moveTo(thisCursor, 1, 6);
		moveToEndOfLine(thisCursor, true);
		assertCursor(thisCursor, new Selection(1, 6, 1, LINE1.length + 1));
		moveToEndOfLine(thisCursor, true);
		assertCursor(thisCursor, new Selection(1, 6, 1, LINE1.length + 1));
	});

	test('move to end of line with selection multiline forward', () => {
		moveTo(thisCursor, 1, 1);
		moveTo(thisCursor, 3, 9, true);
		moveToEndOfLine(thisCursor, false);
		assertCursor(thisCursor, new Selection(3, 17, 3, 17));
	});

	test('move to end of line with selection multiline backward', () => {
		moveTo(thisCursor, 3, 9);
		moveTo(thisCursor, 1, 1, true);
		moveToEndOfLine(thisCursor, false);
		assertCursor(thisCursor, new Selection(1, 21, 1, 21));
	});

	test('move to end of line with selection single line forward', () => {
		moveTo(thisCursor, 3, 1);
		moveTo(thisCursor, 3, 9, true);
		moveToEndOfLine(thisCursor, false);
		assertCursor(thisCursor, new Selection(3, 17, 3, 17));
	});

	test('move to end of line with selection single line backward', () => {
		moveTo(thisCursor, 3, 9);
		moveTo(thisCursor, 3, 1, true);
		moveToEndOfLine(thisCursor, false);
		assertCursor(thisCursor, new Selection(3, 17, 3, 17));
	});

	test('issue #15401: "End" key is behaving weird when text is selected part 2', () => {
		moveTo(thisCursor, 1, 1);
		moveTo(thisCursor, 3, 9, true);
		moveToEndOfLine(thisCursor, false);
		assertCursor(thisCursor, new Selection(3, 17, 3, 17));
	});

	// --------- move to beginning of buffer

	test('move to beginning of buffer', () => {
		moveToBeginningOfBuffer(thisCursor);
		assertCursor(thisCursor, new Position(1, 1));
	});

	test('move to beginning of buffer from within first line', () => {
		moveTo(thisCursor, 1, 3);
		moveToBeginningOfBuffer(thisCursor);
		assertCursor(thisCursor, new Position(1, 1));
	});

	test('move to beginning of buffer from within another line', () => {
		moveTo(thisCursor, 3, 3);
		moveToBeginningOfBuffer(thisCursor);
		assertCursor(thisCursor, new Position(1, 1));
	});

	test('move to beginning of buffer from within first line selection', () => {
		moveTo(thisCursor, 1, 3);
		moveToBeginningOfBuffer(thisCursor, true);
		assertCursor(thisCursor, new Selection(1, 3, 1, 1));
	});

	test('move to beginning of buffer from within another line selection', () => {
		moveTo(thisCursor, 3, 3);
		moveToBeginningOfBuffer(thisCursor, true);
		assertCursor(thisCursor, new Selection(3, 3, 1, 1));
	});

	// --------- move to end of buffer

	test('move to end of buffer', () => {
		moveToEndOfBuffer(thisCursor);
		assertCursor(thisCursor, new Position(5, LINE5.length + 1));
	});

	test('move to end of buffer from within last line', () => {
		moveTo(thisCursor, 5, 1);
		moveToEndOfBuffer(thisCursor);
		assertCursor(thisCursor, new Position(5, LINE5.length + 1));
	});

	test('move to end of buffer from within another line', () => {
		moveTo(thisCursor, 3, 3);
		moveToEndOfBuffer(thisCursor);
		assertCursor(thisCursor, new Position(5, LINE5.length + 1));
	});

	test('move to end of buffer from within last line selection', () => {
		moveTo(thisCursor, 5, 1);
		moveToEndOfBuffer(thisCursor, true);
		assertCursor(thisCursor, new Selection(5, 1, 5, LINE5.length + 1));
	});

	test('move to end of buffer from within another line selection', () => {
		moveTo(thisCursor, 3, 3);
		moveToEndOfBuffer(thisCursor, true);
		assertCursor(thisCursor, new Selection(3, 3, 5, LINE5.length + 1));
	});

	// --------- misc

	test('select all', () => {
		CoreNavigationCommands.SelectAll.runCoreEditorCommand(thisCursor, {});
		assertCursor(thisCursor, new Selection(1, 1, 5, LINE5.length + 1));
	});

	test('expandLineSelection', () => {
		//              0          1         2
		//              01234 56789012345678 0
		// let LINE1 = '    \tMy First Line\t ';
		moveTo(thisCursor, 1, 1);
		CoreNavigationCommands.ExpandLineSelection.runCoreEditorCommand(thisCursor, {});
		assertCursor(thisCursor, new Selection(1, 1, 2, 1));

		moveTo(thisCursor, 1, 2);
		CoreNavigationCommands.ExpandLineSelection.runCoreEditorCommand(thisCursor, {});
		assertCursor(thisCursor, new Selection(1, 1, 2, 1));

		moveTo(thisCursor, 1, 5);
		CoreNavigationCommands.ExpandLineSelection.runCoreEditorCommand(thisCursor, {});
		assertCursor(thisCursor, new Selection(1, 1, 2, 1));

		moveTo(thisCursor, 1, 19);
		CoreNavigationCommands.ExpandLineSelection.runCoreEditorCommand(thisCursor, {});
		assertCursor(thisCursor, new Selection(1, 1, 2, 1));

		moveTo(thisCursor, 1, 20);
		CoreNavigationCommands.ExpandLineSelection.runCoreEditorCommand(thisCursor, {});
		assertCursor(thisCursor, new Selection(1, 1, 2, 1));

		moveTo(thisCursor, 1, 21);
		CoreNavigationCommands.ExpandLineSelection.runCoreEditorCommand(thisCursor, {});
		assertCursor(thisCursor, new Selection(1, 1, 2, 1));
		CoreNavigationCommands.ExpandLineSelection.runCoreEditorCommand(thisCursor, {});
		assertCursor(thisCursor, new Selection(1, 1, 3, 1));
		CoreNavigationCommands.ExpandLineSelection.runCoreEditorCommand(thisCursor, {});
		assertCursor(thisCursor, new Selection(1, 1, 4, 1));
		CoreNavigationCommands.ExpandLineSelection.runCoreEditorCommand(thisCursor, {});
		assertCursor(thisCursor, new Selection(1, 1, 5, 1));
		CoreNavigationCommands.ExpandLineSelection.runCoreEditorCommand(thisCursor, {});
		assertCursor(thisCursor, new Selection(1, 1, 5, LINE5.length + 1));
		CoreNavigationCommands.ExpandLineSelection.runCoreEditorCommand(thisCursor, {});
		assertCursor(thisCursor, new Selection(1, 1, 5, LINE5.length + 1));
	});

	// --------- eventing

	test('no move doesn\'t trigger event', () => {
		thisCursor.onDidChange((e) => {
			assert.ok(false, 'was not expecting event');
		});
		moveTo(thisCursor, 1, 1);
	});

	test('move eventing', () => {
		let events = 0;
		thisCursor.onDidChange((e: CursorStateChangedEvent) => {
			events++;
			assert.deepEqual(e.selections, [new Selection(1, 2, 1, 2)]);
		});
		moveTo(thisCursor, 1, 2);
		assert.equal(events, 1, 'receives 1 event');
	});

	test('move in selection mode eventing', () => {
		let events = 0;
		thisCursor.onDidChange((e: CursorStateChangedEvent) => {
			events++;
			assert.deepEqual(e.selections, [new Selection(1, 1, 1, 2)]);
		});
		moveTo(thisCursor, 1, 2, true);
		assert.equal(events, 1, 'receives 1 event');
	});

	// --------- state save & restore

	test('saveState & restoreState', () => {
		moveTo(thisCursor, 2, 1, true);
		assertCursor(thisCursor, new Selection(1, 1, 2, 1));

		let savedState = JSON.stringify(thisCursor.saveState());

		moveTo(thisCursor, 1, 1, false);
		assertCursor(thisCursor, new Position(1, 1));

		thisCursor.restoreState(JSON.parse(savedState));
		assertCursor(thisCursor, new Selection(1, 1, 2, 1));
	});

	// --------- updating cursor

	test('Independent model edit 1', () => {
		moveTo(thisCursor, 2, 16, true);

		thisModel.applyEdits([EditOperation.delete(new Range(2, 1, 2, 2))]);
		assertCursor(thisCursor, new Selection(1, 1, 2, 15));
	});

	test('column select 1', () => {
		withTestCodeEditor([
			'\tprivate compute(a:number): boolean {',
			'\t\tif (a + 3 === 0 || a + 5 === 0) {',
			'\t\t\treturn false;',
			'\t\t}',
			'\t}'
		], {}, (editor, cursor) => {

			moveTo(cursor, 1, 7, false);
			assertCursor(cursor, new Position(1, 7));

			CoreNavigationCommands.ColumnSelect.runCoreEditorCommand(cursor, {
				position: new Position(4, 4),
				viewPosition: new Position(4, 4),
				mouseColumn: 15
			});

			let expectedSelections = [
				new Selection(1, 7, 1, 12),
				new Selection(2, 4, 2, 9),
				new Selection(3, 3, 3, 6),
				new Selection(4, 4, 4, 4),
			];

			assertCursor(cursor, expectedSelections);

		});
	});

	test('issue #4905 - column select is biased to the right', () => {
		const model = createTextModel([
			'var gulp = require("gulp");',
			'var path = require("path");',
			'var rimraf = require("rimraf");',
			'var isarray = require("isarray");',
			'var merge = require("merge-stream");',
			'var concat = require("gulp-concat");',
			'var newer = require("gulp-newer");',
		].join('\n'));
		const config = new TestConfiguration(null);
		const viewModel = new ViewModel(0, config, model, null);
		const cursor = new Cursor(config, model, viewModel);

		moveTo(cursor, 1, 4, false);
		assertCursor(cursor, new Position(1, 4));

		CoreNavigationCommands.ColumnSelect.runCoreEditorCommand(cursor, {
			position: new Position(4, 1),
			viewPosition: new Position(4, 1),
			mouseColumn: 1
		});

		assertCursor(cursor, [
			new Selection(1, 4, 1, 1),
			new Selection(2, 4, 2, 1),
			new Selection(3, 4, 3, 1),
			new Selection(4, 4, 4, 1),
		]);

		cursor.dispose();
		viewModel.dispose();
		config.dispose();
		model.dispose();
	});

	test('issue #20087: column select with mouse', () => {
		const model = createTextModel([
			'<property id="SomeThing" key="SomeKey" value="000"/>',
			'<property id="SomeThing" key="SomeKey" value="000"/>',
			'<property id="SomeThing" Key="SomeKey" value="000"/>',
			'<property id="SomeThing" key="SomeKey" value="000"/>',
			'<property id="SomeThing" key="SoMEKEy" value="000"/>',
			'<property id="SomeThing" key="SomeKey" value="000"/>',
			'<property id="SomeThing" key="SomeKey" value="000"/>',
			'<property id="SomeThing" key="SomeKey" valuE="000"/>',
			'<property id="SomeThing" key="SomeKey" value="000"/>',
			'<property id="SomeThing" key="SomeKey" value="00X"/>',
		].join('\n'));
		const config = new TestConfiguration(null);
		const viewModel = new ViewModel(0, config, model, null);
		const cursor = new Cursor(config, model, viewModel);

		moveTo(cursor, 10, 10, false);
		assertCursor(cursor, new Position(10, 10));

		CoreNavigationCommands.ColumnSelect.runCoreEditorCommand(cursor, {
			position: new Position(1, 1),
			viewPosition: new Position(1, 1),
			mouseColumn: 1
		});
		assertCursor(cursor, [
			new Selection(10, 10, 10, 1),
			new Selection(9, 10, 9, 1),
			new Selection(8, 10, 8, 1),
			new Selection(7, 10, 7, 1),
			new Selection(6, 10, 6, 1),
			new Selection(5, 10, 5, 1),
			new Selection(4, 10, 4, 1),
			new Selection(3, 10, 3, 1),
			new Selection(2, 10, 2, 1),
			new Selection(1, 10, 1, 1),
		]);

		CoreNavigationCommands.ColumnSelect.runCoreEditorCommand(cursor, {
			position: new Position(1, 1),
			viewPosition: new Position(1, 1),
			mouseColumn: 1
		});
		assertCursor(cursor, [
			new Selection(10, 10, 10, 1),
			new Selection(9, 10, 9, 1),
			new Selection(8, 10, 8, 1),
			new Selection(7, 10, 7, 1),
			new Selection(6, 10, 6, 1),
			new Selection(5, 10, 5, 1),
			new Selection(4, 10, 4, 1),
			new Selection(3, 10, 3, 1),
			new Selection(2, 10, 2, 1),
			new Selection(1, 10, 1, 1),
		]);

		cursor.dispose();
		viewModel.dispose();
		config.dispose();
		model.dispose();
	});

	test('issue #20087: column select with keyboard', () => {
		const model = createTextModel([
			'<property id="SomeThing" key="SomeKey" value="000"/>',
			'<property id="SomeThing" key="SomeKey" value="000"/>',
			'<property id="SomeThing" Key="SomeKey" value="000"/>',
			'<property id="SomeThing" key="SomeKey" value="000"/>',
			'<property id="SomeThing" key="SoMEKEy" value="000"/>',
			'<property id="SomeThing" key="SomeKey" value="000"/>',
			'<property id="SomeThing" key="SomeKey" value="000"/>',
			'<property id="SomeThing" key="SomeKey" valuE="000"/>',
			'<property id="SomeThing" key="SomeKey" value="000"/>',
			'<property id="SomeThing" key="SomeKey" value="00X"/>',
		].join('\n'));
		const config = new TestConfiguration(null);
		const viewModel = new ViewModel(0, config, model, null);
		const cursor = new Cursor(config, model, viewModel);

		moveTo(cursor, 10, 10, false);
		assertCursor(cursor, new Position(10, 10));

		CoreNavigationCommands.CursorColumnSelectLeft.runCoreEditorCommand(cursor, {});
		assertCursor(cursor, [
			new Selection(10, 10, 10, 9)
		]);

		CoreNavigationCommands.CursorColumnSelectLeft.runCoreEditorCommand(cursor, {});
		assertCursor(cursor, [
			new Selection(10, 10, 10, 8)
		]);

		CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(cursor, {});
		assertCursor(cursor, [
			new Selection(10, 10, 10, 9)
		]);

		CoreNavigationCommands.CursorColumnSelectUp.runCoreEditorCommand(cursor, {});
		assertCursor(cursor, [
			new Selection(10, 10, 10, 9),
			new Selection(9, 10, 9, 9),
		]);

		CoreNavigationCommands.CursorColumnSelectDown.runCoreEditorCommand(cursor, {});
		assertCursor(cursor, [
			new Selection(10, 10, 10, 9)
		]);

		cursor.dispose();
		viewModel.dispose();
		config.dispose();
		model.dispose();
	});

	test('column select with keyboard', () => {
		const model = createTextModel([
			'var gulp = require("gulp");',
			'var path = require("path");',
			'var rimraf = require("rimraf");',
			'var isarray = require("isarray");',
			'var merge = require("merge-stream");',
			'var concat = require("gulp-concat");',
			'var newer = require("gulp-newer");',
		].join('\n'));
		const config = new TestConfiguration(null);
		const viewModel = new ViewModel(0, config, model, null);
		const cursor = new Cursor(config, model, viewModel);

		moveTo(cursor, 1, 4, false);
		assertCursor(cursor, new Position(1, 4));

		CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(cursor, {});
		assertCursor(cursor, [
			new Selection(1, 4, 1, 5)
		]);

		CoreNavigationCommands.CursorColumnSelectDown.runCoreEditorCommand(cursor, {});
		assertCursor(cursor, [
			new Selection(1, 4, 1, 5),
			new Selection(2, 4, 2, 5)
		]);

		CoreNavigationCommands.CursorColumnSelectDown.runCoreEditorCommand(cursor, {});
		assertCursor(cursor, [
			new Selection(1, 4, 1, 5),
			new Selection(2, 4, 2, 5),
			new Selection(3, 4, 3, 5),
		]);

		CoreNavigationCommands.CursorColumnSelectDown.runCoreEditorCommand(cursor, {});
		CoreNavigationCommands.CursorColumnSelectDown.runCoreEditorCommand(cursor, {});
		CoreNavigationCommands.CursorColumnSelectDown.runCoreEditorCommand(cursor, {});
		CoreNavigationCommands.CursorColumnSelectDown.runCoreEditorCommand(cursor, {});
		assertCursor(cursor, [
			new Selection(1, 4, 1, 5),
			new Selection(2, 4, 2, 5),
			new Selection(3, 4, 3, 5),
			new Selection(4, 4, 4, 5),
			new Selection(5, 4, 5, 5),
			new Selection(6, 4, 6, 5),
			new Selection(7, 4, 7, 5),
		]);

		CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(cursor, {});
		assertCursor(cursor, [
			new Selection(1, 4, 1, 6),
			new Selection(2, 4, 2, 6),
			new Selection(3, 4, 3, 6),
			new Selection(4, 4, 4, 6),
			new Selection(5, 4, 5, 6),
			new Selection(6, 4, 6, 6),
			new Selection(7, 4, 7, 6),
		]);

		// 10 times
		CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(cursor, {});
		CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(cursor, {});
		CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(cursor, {});
		CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(cursor, {});
		CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(cursor, {});
		CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(cursor, {});
		CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(cursor, {});
		CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(cursor, {});
		CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(cursor, {});
		CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(cursor, {});
		assertCursor(cursor, [
			new Selection(1, 4, 1, 16),
			new Selection(2, 4, 2, 16),
			new Selection(3, 4, 3, 16),
			new Selection(4, 4, 4, 16),
			new Selection(5, 4, 5, 16),
			new Selection(6, 4, 6, 16),
			new Selection(7, 4, 7, 16),
		]);

		// 10 times
		CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(cursor, {});
		CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(cursor, {});
		CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(cursor, {});
		CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(cursor, {});
		CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(cursor, {});
		CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(cursor, {});
		CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(cursor, {});
		CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(cursor, {});
		CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(cursor, {});
		CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(cursor, {});
		assertCursor(cursor, [
			new Selection(1, 4, 1, 26),
			new Selection(2, 4, 2, 26),
			new Selection(3, 4, 3, 26),
			new Selection(4, 4, 4, 26),
			new Selection(5, 4, 5, 26),
			new Selection(6, 4, 6, 26),
			new Selection(7, 4, 7, 26),
		]);

		// 2 times => reaching the ending of lines 1 and 2
		CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(cursor, {});
		CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(cursor, {});
		assertCursor(cursor, [
			new Selection(1, 4, 1, 28),
			new Selection(2, 4, 2, 28),
			new Selection(3, 4, 3, 28),
			new Selection(4, 4, 4, 28),
			new Selection(5, 4, 5, 28),
			new Selection(6, 4, 6, 28),
			new Selection(7, 4, 7, 28),
		]);

		// 4 times => reaching the ending of line 3
		CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(cursor, {});
		CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(cursor, {});
		CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(cursor, {});
		CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(cursor, {});
		assertCursor(cursor, [
			new Selection(1, 4, 1, 28),
			new Selection(2, 4, 2, 28),
			new Selection(3, 4, 3, 32),
			new Selection(4, 4, 4, 32),
			new Selection(5, 4, 5, 32),
			new Selection(6, 4, 6, 32),
			new Selection(7, 4, 7, 32),
		]);

		// 2 times => reaching the ending of line 4
		CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(cursor, {});
		CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(cursor, {});
		assertCursor(cursor, [
			new Selection(1, 4, 1, 28),
			new Selection(2, 4, 2, 28),
			new Selection(3, 4, 3, 32),
			new Selection(4, 4, 4, 34),
			new Selection(5, 4, 5, 34),
			new Selection(6, 4, 6, 34),
			new Selection(7, 4, 7, 34),
		]);

		// 1 time => reaching the ending of line 7
		CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(cursor, {});
		assertCursor(cursor, [
			new Selection(1, 4, 1, 28),
			new Selection(2, 4, 2, 28),
			new Selection(3, 4, 3, 32),
			new Selection(4, 4, 4, 34),
			new Selection(5, 4, 5, 35),
			new Selection(6, 4, 6, 35),
			new Selection(7, 4, 7, 35),
		]);

		// 3 times => reaching the ending of lines 5 & 6
		CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(cursor, {});
		CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(cursor, {});
		CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(cursor, {});
		assertCursor(cursor, [
			new Selection(1, 4, 1, 28),
			new Selection(2, 4, 2, 28),
			new Selection(3, 4, 3, 32),
			new Selection(4, 4, 4, 34),
			new Selection(5, 4, 5, 37),
			new Selection(6, 4, 6, 37),
			new Selection(7, 4, 7, 35),
		]);

		// cannot go anywhere anymore
		CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(cursor, {});
		assertCursor(cursor, [
			new Selection(1, 4, 1, 28),
			new Selection(2, 4, 2, 28),
			new Selection(3, 4, 3, 32),
			new Selection(4, 4, 4, 34),
			new Selection(5, 4, 5, 37),
			new Selection(6, 4, 6, 37),
			new Selection(7, 4, 7, 35),
		]);

		// cannot go anywhere anymore even if we insist
		CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(cursor, {});
		CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(cursor, {});
		CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(cursor, {});
		CoreNavigationCommands.CursorColumnSelectRight.runCoreEditorCommand(cursor, {});
		assertCursor(cursor, [
			new Selection(1, 4, 1, 28),
			new Selection(2, 4, 2, 28),
			new Selection(3, 4, 3, 32),
			new Selection(4, 4, 4, 34),
			new Selection(5, 4, 5, 37),
			new Selection(6, 4, 6, 37),
			new Selection(7, 4, 7, 35),
		]);

		// can easily go back
		CoreNavigationCommands.CursorColumnSelectLeft.runCoreEditorCommand(cursor, {});
		assertCursor(cursor, [
			new Selection(1, 4, 1, 28),
			new Selection(2, 4, 2, 28),
			new Selection(3, 4, 3, 32),
			new Selection(4, 4, 4, 34),
			new Selection(5, 4, 5, 36),
			new Selection(6, 4, 6, 36),
			new Selection(7, 4, 7, 35),
		]);

		cursor.dispose();
		viewModel.dispose();
		config.dispose();
		model.dispose();
	});
});

class SurroundingMode extends MockMode {

	private static readonly _id = new LanguageIdentifier('surroundingMode', 3);

	constructor() {
		super(SurroundingMode._id);
		this._register(LanguageConfigurationRegistry.register(this.getLanguageIdentifier(), {
			autoClosingPairs: [{ open: '(', close: ')' }]
		}));
	}
}

class OnEnterMode extends MockMode {
	private static readonly _id = new LanguageIdentifier('onEnterMode', 3);

	constructor(indentAction: IndentAction) {
		super(OnEnterMode._id);
		this._register(LanguageConfigurationRegistry.register(this.getLanguageIdentifier(), {
			onEnterRules: [{
				beforeText: /.*/,
				action: {
					indentAction: indentAction
				}
			}]
		}));
	}
}

class IndentRulesMode extends MockMode {
	private static readonly _id = new LanguageIdentifier('indentRulesMode', 4);
	constructor(indentationRules: IndentationRule) {
		super(IndentRulesMode._id);
		this._register(LanguageConfigurationRegistry.register(this.getLanguageIdentifier(), {
			indentationRules: indentationRules
		}));
	}
}

suite('Editor Controller - Regression tests', () => {

	test('issue Microsoft/monaco-editor#443: Indentation of a single row deletes selected text in some cases', () => {
		let model = createTextModel(
			[
				'Hello world!',
				'another line'
			].join('\n'),
			{
				insertSpaces: false
			},
		);

		withTestCodeEditor(null, { model: model }, (editor, cursor) => {
			cursor.setSelections('test', [new Selection(1, 1, 1, 13)]);

			// Check that indenting maintains the selection start at column 1
			CoreEditingCommands.Tab.runEditorCommand(null, editor, null);
			assert.deepEqual(cursor.getSelection(), new Selection(1, 1, 1, 14));
		});

		model.dispose();
	});

	test('Bug 9121: Auto indent + undo + redo is funky', () => {
		let model = createTextModel(
			[
				''
			].join('\n'),
			{
				insertSpaces: false,
				trimAutoWhitespace: false
			},
		);

		withTestCodeEditor(null, { model: model }, (editor, cursor) => {
			cursorCommand(cursor, H.Type, { text: '\n' }, 'keyboard');
			assert.equal(model.getValue(EndOfLinePreference.LF), '\n', 'assert1');

			CoreEditingCommands.Tab.runEditorCommand(null, editor, null);
			assert.equal(model.getValue(EndOfLinePreference.LF), '\n\t', 'assert2');

			cursorCommand(cursor, H.Type, { text: '\n' }, 'keyboard');
			assert.equal(model.getValue(EndOfLinePreference.LF), '\n\t\n\t', 'assert3');

			cursorCommand(cursor, H.Type, { text: 'x' });
			assert.equal(model.getValue(EndOfLinePreference.LF), '\n\t\n\tx', 'assert4');

			CoreNavigationCommands.CursorLeft.runCoreEditorCommand(cursor, {});
			assert.equal(model.getValue(EndOfLinePreference.LF), '\n\t\n\tx', 'assert5');

			CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
			assert.equal(model.getValue(EndOfLinePreference.LF), '\n\t\nx', 'assert6');

			CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
			assert.equal(model.getValue(EndOfLinePreference.LF), '\n\tx', 'assert7');

			CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
			assert.equal(model.getValue(EndOfLinePreference.LF), '\nx', 'assert8');

			CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
			assert.equal(model.getValue(EndOfLinePreference.LF), 'x', 'assert9');

			cursorCommand(cursor, H.Undo, {});
			assert.equal(model.getValue(EndOfLinePreference.LF), '\nx', 'assert10');

			cursorCommand(cursor, H.Undo, {});
			assert.equal(model.getValue(EndOfLinePreference.LF), '\n\t\nx', 'assert11');

			cursorCommand(cursor, H.Undo, {});
			assert.equal(model.getValue(EndOfLinePreference.LF), '\n\t\n\tx', 'assert12');

			cursorCommand(cursor, H.Redo, {});
			assert.equal(model.getValue(EndOfLinePreference.LF), '\n\t\nx', 'assert13');

			cursorCommand(cursor, H.Redo, {});
			assert.equal(model.getValue(EndOfLinePreference.LF), '\nx', 'assert14');

			cursorCommand(cursor, H.Redo, {});
			assert.equal(model.getValue(EndOfLinePreference.LF), 'x', 'assert15');
		});

		model.dispose();
	});

	test('issue #23539: Setting model EOL isn\'t undoable', () => {
		usingCursor({
			text: [
				'Hello',
				'world'
			]
		}, (model, cursor) => {
			assertCursor(cursor, new Position(1, 1));
			model.setEOL(EndOfLineSequence.LF);
			assert.equal(model.getValue(), 'Hello\nworld');

			model.pushEOL(EndOfLineSequence.CRLF);
			assert.equal(model.getValue(), 'Hello\r\nworld');

			cursorCommand(cursor, H.Undo);
			assert.equal(model.getValue(), 'Hello\nworld');
		});
	});

	test('issue #47733: Undo mangles unicode characters', () => {
		const languageId = new LanguageIdentifier('myMode', 3);
		class MyMode extends MockMode {
			constructor() {
				super(languageId);
				this._register(LanguageConfigurationRegistry.register(this.getLanguageIdentifier(), {
					surroundingPairs: [{ open: '%', close: '%' }]
				}));
			}
		}

		const mode = new MyMode();
		const model = createTextModel('\'👁\'', undefined, languageId);

		withTestCodeEditor(null, { model: model }, (editor, cursor) => {
			editor.setSelection(new Selection(1, 1, 1, 2));

			cursorCommand(cursor, H.Type, { text: '%' }, 'keyboard');
			assert.equal(model.getValue(EndOfLinePreference.LF), '%\'%👁\'', 'assert1');

			cursorCommand(cursor, H.Undo, {});
			assert.equal(model.getValue(EndOfLinePreference.LF), '\'👁\'', 'assert2');
		});

		model.dispose();
		mode.dispose();
	});

	test('issue #46208: Allow empty selections in the undo/redo stack', () => {
		let model = createTextModel('');

		withTestCodeEditor(null, { model: model }, (editor, cursor) => {
			cursorCommand(cursor, H.Type, { text: 'Hello' }, 'keyboard');
			cursorCommand(cursor, H.Type, { text: ' ' }, 'keyboard');
			cursorCommand(cursor, H.Type, { text: 'world' }, 'keyboard');
			cursorCommand(cursor, H.Type, { text: ' ' }, 'keyboard');
			assert.equal(model.getLineContent(1), 'Hello world ');
			assertCursor(cursor, new Position(1, 13));

			moveLeft(cursor);
			moveRight(cursor);

			model.pushEditOperations([], [EditOperation.replaceMove(new Range(1, 12, 1, 13), '')], () => []);
			assert.equal(model.getLineContent(1), 'Hello world');
			assertCursor(cursor, new Position(1, 12));

			cursorCommand(cursor, H.Undo, {});
			assert.equal(model.getLineContent(1), 'Hello world ');
			assertCursor(cursor, new Position(1, 13));

			cursorCommand(cursor, H.Undo, {});
			assert.equal(model.getLineContent(1), 'Hello world');
			assertCursor(cursor, new Position(1, 12));

			cursorCommand(cursor, H.Undo, {});
			assert.equal(model.getLineContent(1), 'Hello');
			assertCursor(cursor, new Position(1, 6));

			cursorCommand(cursor, H.Undo, {});
			assert.equal(model.getLineContent(1), '');
			assertCursor(cursor, new Position(1, 1));

			cursorCommand(cursor, H.Redo, {});
			assert.equal(model.getLineContent(1), 'Hello');
			assertCursor(cursor, new Position(1, 6));

			cursorCommand(cursor, H.Redo, {});
			assert.equal(model.getLineContent(1), 'Hello world');
			assertCursor(cursor, new Position(1, 12));

			cursorCommand(cursor, H.Redo, {});
			assert.equal(model.getLineContent(1), 'Hello world ');
			assertCursor(cursor, new Position(1, 13));

			cursorCommand(cursor, H.Redo, {});
			assert.equal(model.getLineContent(1), 'Hello world');
			assertCursor(cursor, new Position(1, 12));

			cursorCommand(cursor, H.Redo, {});
			assert.equal(model.getLineContent(1), 'Hello world');
			assertCursor(cursor, new Position(1, 12));
		});

		model.dispose();
	});

	test('bug #16815:Shift+Tab doesn\'t go back to tabstop', () => {
		let mode = new OnEnterMode(IndentAction.IndentOutdent);
		let model = createTextModel(
			[
				'     function baz() {'
			].join('\n'),
			undefined,
			mode.getLanguageIdentifier()
		);

		withTestCodeEditor(null, { model: model }, (editor, cursor) => {
			moveTo(cursor, 1, 6, false);
			assertCursor(cursor, new Selection(1, 6, 1, 6));

			CoreEditingCommands.Outdent.runEditorCommand(null, editor, null);
			assert.equal(model.getLineContent(1), '    function baz() {');
			assertCursor(cursor, new Selection(1, 5, 1, 5));
		});

		model.dispose();
		mode.dispose();
	});

	test('Bug #18293:[regression][editor] Can\'t outdent whitespace line', () => {
		let model = createTextModel(
			[
				'      '
			].join('\n')
		);

		withTestCodeEditor(null, { model: model }, (editor, cursor) => {
			moveTo(cursor, 1, 7, false);
			assertCursor(cursor, new Selection(1, 7, 1, 7));

			CoreEditingCommands.Outdent.runEditorCommand(null, editor, null);
			assert.equal(model.getLineContent(1), '    ');
			assertCursor(cursor, new Selection(1, 5, 1, 5));
		});

		model.dispose();
	});

	test('Bug #16657: [editor] Tab on empty line of zero indentation moves cursor to position (1,1)', () => {
		let model = createTextModel(
			[
				'function baz() {',
				'\tfunction hello() { // something here',
				'\t',
				'',
				'\t}',
				'}',
				''
			].join('\n'),
			{
				insertSpaces: false,
			},
		);

		withTestCodeEditor(null, { model: model }, (editor, cursor) => {
			moveTo(cursor, 7, 1, false);
			assertCursor(cursor, new Selection(7, 1, 7, 1));

			CoreEditingCommands.Tab.runEditorCommand(null, editor, null);
			assert.equal(model.getLineContent(7), '\t');
			assertCursor(cursor, new Selection(7, 2, 7, 2));
		});

		model.dispose();
	});

	test('bug #16740: [editor] Cut line doesn\'t quite cut the last line', () => {

		// Part 1 => there is text on the last line
		withTestCodeEditor([
			'asdasd',
			'qwerty'
		], {}, (editor, cursor) => {
			const model = editor.getModel();

			moveTo(cursor, 2, 1, false);
			assertCursor(cursor, new Selection(2, 1, 2, 1));

			cursorCommand(cursor, H.Cut, null, 'keyboard');
			assert.equal(model.getLineCount(), 1);
			assert.equal(model.getLineContent(1), 'asdasd');

		});

		// Part 2 => there is no text on the last line
		withTestCodeEditor([
			'asdasd',
			''
		], {}, (editor, cursor) => {
			const model = editor.getModel();

			moveTo(cursor, 2, 1, false);
			assertCursor(cursor, new Selection(2, 1, 2, 1));

			cursorCommand(cursor, H.Cut, null, 'keyboard');
			assert.equal(model.getLineCount(), 1);
			assert.equal(model.getLineContent(1), 'asdasd');

			cursorCommand(cursor, H.Cut, null, 'keyboard');
			assert.equal(model.getLineCount(), 1);
			assert.equal(model.getLineContent(1), '');
		});
	});

	test('Bug #11476: Double bracket surrounding + undo is broken', () => {
		let mode = new SurroundingMode();
		usingCursor({
			text: [
				'hello'
			],
			languageIdentifier: mode.getLanguageIdentifier()
		}, (model, cursor) => {
			moveTo(cursor, 1, 3, false);
			moveTo(cursor, 1, 5, true);
			assertCursor(cursor, new Selection(1, 3, 1, 5));

			cursorCommand(cursor, H.Type, { text: '(' }, 'keyboard');
			assertCursor(cursor, new Selection(1, 4, 1, 6));

			cursorCommand(cursor, H.Type, { text: '(' }, 'keyboard');
			assertCursor(cursor, new Selection(1, 5, 1, 7));
		});
		mode.dispose();
	});

	test('issue #1140: Backspace stops prematurely', () => {
		let mode = new SurroundingMode();
		let model = createTextModel(
			[
				'function baz() {',
				'  return 1;',
				'};'
			].join('\n')
		);

		withTestCodeEditor(null, { model: model }, (editor, cursor) => {
			moveTo(cursor, 3, 2, false);
			moveTo(cursor, 1, 14, true);
			assertCursor(cursor, new Selection(3, 2, 1, 14));

			CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
			assertCursor(cursor, new Selection(1, 14, 1, 14));
			assert.equal(model.getLineCount(), 1);
			assert.equal(model.getLineContent(1), 'function baz(;');
		});

		model.dispose();
		mode.dispose();
	});

	test('issue #10212: Pasting entire line does not replace selection', () => {
		usingCursor({
			text: [
				'line1',
				'line2'
			],
		}, (model, cursor) => {
			moveTo(cursor, 2, 1, false);
			moveTo(cursor, 2, 6, true);

			cursorCommand(cursor, H.Paste, { text: 'line1\n', pasteOnNewLine: true });

			assert.equal(model.getLineContent(1), 'line1');
			assert.equal(model.getLineContent(2), 'line1');
			assert.equal(model.getLineContent(3), '');
		});
	});

	test('issue #4996: Multiple cursor paste pastes contents of all cursors', () => {
		usingCursor({
			text: [
				'line1',
				'line2',
				'line3'
			],
		}, (model, cursor) => {
			cursor.setSelections('test', [new Selection(1, 1, 1, 1), new Selection(2, 1, 2, 1)]);

			cursorCommand(cursor, H.Paste, {
				text: 'a\nb\nc\nd',
				pasteOnNewLine: false,
				multicursorText: [
					'a\nb',
					'c\nd'
				]
			});

			assert.equal(model.getValue(), [
				'a',
				'bline1',
				'c',
				'dline2',
				'line3'
			].join('\n'));
		});
	});

	test('issue #16155: Paste into multiple cursors has edge case when number of lines equals number of cursors - 1', () => {
		usingCursor({
			text: [
				'test',
				'test',
				'test',
				'test'
			],
		}, (model, cursor) => {
			cursor.setSelections('test', [
				new Selection(1, 1, 1, 5),
				new Selection(2, 1, 2, 5),
				new Selection(3, 1, 3, 5),
				new Selection(4, 1, 4, 5),
			]);

			cursorCommand(cursor, H.Paste, {
				text: 'aaa\nbbb\nccc\n',
				pasteOnNewLine: false,
				multicursorText: null
			});

			assert.equal(model.getValue(), [
				'aaa',
				'bbb',
				'ccc',
				'',
				'aaa',
				'bbb',
				'ccc',
				'',
				'aaa',
				'bbb',
				'ccc',
				'',
				'aaa',
				'bbb',
				'ccc',
				'',
			].join('\n'));
		});
	});

	test('issue #46440: (1) Pasting a multi-line selection pastes entire selection into every insertion point', () => {
		usingCursor({
			text: [
				'line1',
				'line2',
				'line3'
			],
		}, (model, cursor) => {
			cursor.setSelections('test', [new Selection(1, 1, 1, 1), new Selection(2, 1, 2, 1), new Selection(3, 1, 3, 1)]);

			cursorCommand(cursor, H.Paste, {
				text: 'a\nb\nc',
				pasteOnNewLine: false,
				multicursorText: null
			});

			assert.equal(model.getValue(), [
				'aline1',
				'bline2',
				'cline3'
			].join('\n'));
		});
	});

	test('issue #46440: (2) Pasting a multi-line selection pastes entire selection into every insertion point', () => {
		usingCursor({
			text: [
				'line1',
				'line2',
				'line3'
			],
		}, (model, cursor) => {
			cursor.setSelections('test', [new Selection(1, 1, 1, 1), new Selection(2, 1, 2, 1), new Selection(3, 1, 3, 1)]);

			cursorCommand(cursor, H.Paste, {
				text: 'a\nb\nc\n',
				pasteOnNewLine: false,
				multicursorText: null
			});

			assert.equal(model.getValue(), [
				'aline1',
				'bline2',
				'cline3'
			].join('\n'));
		});
	});

	test('issue #3071: Investigate why undo stack gets corrupted', () => {
		let model = createTextModel(
			[
				'some lines',
				'and more lines',
				'just some text',
			].join('\n')
		);

		withTestCodeEditor(null, { model: model }, (editor, cursor) => {
			moveTo(cursor, 1, 1, false);
			moveTo(cursor, 3, 4, true);

			let isFirst = true;
			model.onDidChangeContent(() => {
				if (isFirst) {
					isFirst = false;
					cursorCommand(cursor, H.Type, { text: '\t' }, 'keyboard');
				}
			});

			CoreEditingCommands.Tab.runEditorCommand(null, editor, null);
			assert.equal(model.getValue(), [
				'\t just some text'
			].join('\n'), '001');

			cursorCommand(cursor, H.Undo);
			assert.equal(model.getValue(), [
				'    some lines',
				'    and more lines',
				'    just some text',
			].join('\n'), '002');

			cursorCommand(cursor, H.Undo);
			assert.equal(model.getValue(), [
				'some lines',
				'and more lines',
				'just some text',
			].join('\n'), '003');

			cursorCommand(cursor, H.Undo);
			assert.equal(model.getValue(), [
				'some lines',
				'and more lines',
				'just some text',
			].join('\n'), '004');
		});

		model.dispose();
	});

	test('issue #12950: Cannot Double Click To Insert Emoji Using OSX Emoji Panel', () => {
		usingCursor({
			text: [
				'some lines',
				'and more lines',
				'just some text',
			],
			languageIdentifier: null
		}, (model, cursor) => {
			moveTo(cursor, 3, 1, false);

			cursorCommand(cursor, H.Type, { text: '😍' }, 'keyboard');

			assert.equal(model.getValue(), [
				'some lines',
				'and more lines',
				'😍just some text',
			].join('\n'));
		});
	});

	test('issue #3463: pressing tab adds spaces, but not as many as for a tab', () => {
		let model = createTextModel(
			[
				'function a() {',
				'\tvar a = {',
				'\t\tx: 3',
				'\t};',
				'}',
			].join('\n')
		);

		withTestCodeEditor(null, { model: model }, (editor, cursor) => {
			moveTo(cursor, 3, 2, false);
			CoreEditingCommands.Tab.runEditorCommand(null, editor, null);
			assert.equal(model.getLineContent(3), '\t    \tx: 3');
		});

		model.dispose();
	});

	test('issue #4312: trying to type a tab character over a sequence of spaces results in unexpected behaviour', () => {
		let model = createTextModel(
			[
				'var foo = 123;       // this is a comment',
				'var bar = 4;       // another comment'
			].join('\n'),
			{
				insertSpaces: false,
			}
		);

		withTestCodeEditor(null, { model: model }, (editor, cursor) => {
			moveTo(cursor, 1, 15, false);
			moveTo(cursor, 1, 22, true);
			CoreEditingCommands.Tab.runEditorCommand(null, editor, null);
			assert.equal(model.getLineContent(1), 'var foo = 123;\t// this is a comment');
		});

		model.dispose();
	});

	test('issue #832: word right', () => {

		usingCursor({
			text: [
				'   /* Just some   more   text a+= 3 +5-3 + 7 */  '
			],
		}, (model, cursor) => {
			moveTo(cursor, 1, 1, false);

			function assertWordRight(col: number, expectedCol: number) {
				let args = {
					position: {
						lineNumber: 1,
						column: col
					}
				};
				if (col === 1) {
					CoreNavigationCommands.WordSelect.runCoreEditorCommand(cursor, args);
				} else {
					CoreNavigationCommands.WordSelectDrag.runCoreEditorCommand(cursor, args);
				}

				assert.equal(cursor.getSelection().startColumn, 1, 'TEST FOR ' + col);
				assert.equal(cursor.getSelection().endColumn, expectedCol, 'TEST FOR ' + col);
			}

			assertWordRight(1, '   '.length + 1);
			assertWordRight(2, '   '.length + 1);
			assertWordRight(3, '   '.length + 1);
			assertWordRight(4, '   '.length + 1);
			assertWordRight(5, '   /'.length + 1);
			assertWordRight(6, '   /*'.length + 1);
			assertWordRight(7, '   /* '.length + 1);
			assertWordRight(8, '   /* Just'.length + 1);
			assertWordRight(9, '   /* Just'.length + 1);
			assertWordRight(10, '   /* Just'.length + 1);
			assertWordRight(11, '   /* Just'.length + 1);
			assertWordRight(12, '   /* Just '.length + 1);
			assertWordRight(13, '   /* Just some'.length + 1);
			assertWordRight(14, '   /* Just some'.length + 1);
			assertWordRight(15, '   /* Just some'.length + 1);
			assertWordRight(16, '   /* Just some'.length + 1);
			assertWordRight(17, '   /* Just some '.length + 1);
			assertWordRight(18, '   /* Just some  '.length + 1);
			assertWordRight(19, '   /* Just some   '.length + 1);
			assertWordRight(20, '   /* Just some   more'.length + 1);
			assertWordRight(21, '   /* Just some   more'.length + 1);
			assertWordRight(22, '   /* Just some   more'.length + 1);
			assertWordRight(23, '   /* Just some   more'.length + 1);
			assertWordRight(24, '   /* Just some   more '.length + 1);
			assertWordRight(25, '   /* Just some   more  '.length + 1);
			assertWordRight(26, '   /* Just some   more   '.length + 1);
			assertWordRight(27, '   /* Just some   more   text'.length + 1);
			assertWordRight(28, '   /* Just some   more   text'.length + 1);
			assertWordRight(29, '   /* Just some   more   text'.length + 1);
			assertWordRight(30, '   /* Just some   more   text'.length + 1);
			assertWordRight(31, '   /* Just some   more   text '.length + 1);
			assertWordRight(32, '   /* Just some   more   text a'.length + 1);
			assertWordRight(33, '   /* Just some   more   text a+'.length + 1);
			assertWordRight(34, '   /* Just some   more   text a+='.length + 1);
			assertWordRight(35, '   /* Just some   more   text a+= '.length + 1);
			assertWordRight(36, '   /* Just some   more   text a+= 3'.length + 1);
			assertWordRight(37, '   /* Just some   more   text a+= 3 '.length + 1);
			assertWordRight(38, '   /* Just some   more   text a+= 3 +'.length + 1);
			assertWordRight(39, '   /* Just some   more   text a+= 3 +5'.length + 1);
			assertWordRight(40, '   /* Just some   more   text a+= 3 +5-'.length + 1);
			assertWordRight(41, '   /* Just some   more   text a+= 3 +5-3'.length + 1);
			assertWordRight(42, '   /* Just some   more   text a+= 3 +5-3 '.length + 1);
			assertWordRight(43, '   /* Just some   more   text a+= 3 +5-3 +'.length + 1);
			assertWordRight(44, '   /* Just some   more   text a+= 3 +5-3 + '.length + 1);
			assertWordRight(45, '   /* Just some   more   text a+= 3 +5-3 + 7'.length + 1);
			assertWordRight(46, '   /* Just some   more   text a+= 3 +5-3 + 7 '.length + 1);
			assertWordRight(47, '   /* Just some   more   text a+= 3 +5-3 + 7 *'.length + 1);
			assertWordRight(48, '   /* Just some   more   text a+= 3 +5-3 + 7 */'.length + 1);
			assertWordRight(49, '   /* Just some   more   text a+= 3 +5-3 + 7 */ '.length + 1);
			assertWordRight(50, '   /* Just some   more   text a+= 3 +5-3 + 7 */  '.length + 1);
		});
	});

	test('issue #33788: Wrong cursor position when double click to select a word', () => {
		let model = createTextModel(
			[
				'Just some text'
			].join('\n')
		);

		withTestCodeEditor(null, { model: model }, (editor, cursor) => {
			CoreNavigationCommands.WordSelect.runCoreEditorCommand(cursor, { position: new Position(1, 8) });
			assert.deepEqual(cursor.getSelection(), new Selection(1, 6, 1, 10));

			CoreNavigationCommands.WordSelectDrag.runCoreEditorCommand(cursor, { position: new Position(1, 8) });
			assert.deepEqual(cursor.getSelection(), new Selection(1, 6, 1, 10));
		});

		model.dispose();
	});

	test('issue #12887: Double-click highlighting separating white space', () => {
		let model = createTextModel(
			[
				'abc def'
			].join('\n')
		);

		withTestCodeEditor(null, { model: model }, (editor, cursor) => {
			CoreNavigationCommands.WordSelect.runCoreEditorCommand(cursor, { position: new Position(1, 5) });
			assert.deepEqual(cursor.getSelection(), new Selection(1, 5, 1, 8));
		});

		model.dispose();
	});

	test('issue #9675: Undo/Redo adds a stop in between CHN Characters', () => {
		usingCursor({
			text: [
			]
		}, (model, cursor) => {
			assertCursor(cursor, new Position(1, 1));

			// Typing sennsei in Japanese - Hiragana
			cursorCommand(cursor, H.Type, { text: 'ｓ' }, 'keyboard');
			cursorCommand(cursor, H.ReplacePreviousChar, { text: 'せ', replaceCharCnt: 1 });
			cursorCommand(cursor, H.ReplacePreviousChar, { text: 'せｎ', replaceCharCnt: 1 });
			cursorCommand(cursor, H.ReplacePreviousChar, { text: 'せん', replaceCharCnt: 2 });
			cursorCommand(cursor, H.ReplacePreviousChar, { text: 'せんｓ', replaceCharCnt: 2 });
			cursorCommand(cursor, H.ReplacePreviousChar, { text: 'せんせ', replaceCharCnt: 3 });
			cursorCommand(cursor, H.ReplacePreviousChar, { text: 'せんせ', replaceCharCnt: 3 });
			cursorCommand(cursor, H.ReplacePreviousChar, { text: 'せんせい', replaceCharCnt: 3 });
			cursorCommand(cursor, H.ReplacePreviousChar, { text: 'せんせい', replaceCharCnt: 4 });
			cursorCommand(cursor, H.ReplacePreviousChar, { text: 'せんせい', replaceCharCnt: 4 });
			cursorCommand(cursor, H.ReplacePreviousChar, { text: 'せんせい', replaceCharCnt: 4 });

			assert.equal(model.getLineContent(1), 'せんせい');
			assertCursor(cursor, new Position(1, 5));

			cursorCommand(cursor, H.Undo);
			assert.equal(model.getLineContent(1), '');
			assertCursor(cursor, new Position(1, 1));
		});
	});

	test('issue #23913: Greater than 1000+ multi cursor typing replacement text appears inverted, lines begin to drop off selection', function () {
		this.timeout(10000);
		const LINE_CNT = 2000;

		let text: string[] = [];
		for (let i = 0; i < LINE_CNT; i++) {
			text[i] = 'asd';
		}
		usingCursor({
			text: text
		}, (model, cursor) => {

			let selections: Selection[] = [];
			for (let i = 0; i < LINE_CNT; i++) {
				selections[i] = new Selection(i + 1, 1, i + 1, 1);
			}
			cursor.setSelections('test', selections);

			cursorCommand(cursor, H.Type, { text: 'n' }, 'keyboard');
			cursorCommand(cursor, H.Type, { text: 'n' }, 'keyboard');

			for (let i = 0; i < LINE_CNT; i++) {
				assert.equal(model.getLineContent(i + 1), 'nnasd', 'line #' + (i + 1));
			}

			assert.equal(cursor.getSelections().length, LINE_CNT);
			assert.equal(cursor.getSelections()[LINE_CNT - 1].startLineNumber, LINE_CNT);
		});
	});

	test('issue #23983: Calling model.setEOL does not reset cursor position', () => {
		usingCursor({
			text: [
				'first line',
				'second line'
			]
		}, (model, cursor) => {
			model.setEOL(EndOfLineSequence.CRLF);

			cursor.setSelections('test', [new Selection(2, 2, 2, 2)]);
			model.setEOL(EndOfLineSequence.LF);

			assertCursor(cursor, new Selection(2, 2, 2, 2));
		});
	});

	test('issue #23983: Calling model.setValue() resets cursor position', () => {
		usingCursor({
			text: [
				'first line',
				'second line'
			]
		}, (model, cursor) => {
			model.setEOL(EndOfLineSequence.CRLF);

			cursor.setSelections('test', [new Selection(2, 2, 2, 2)]);
			model.setValue([
				'different first line',
				'different second line',
				'new third line'
			].join('\n'));

			assertCursor(cursor, new Selection(1, 1, 1, 1));
		});
	});

	test('issue #36740: wordwrap creates an extra step / character at the wrapping point', () => {
		// a single model line => 4 view lines
		withTestCodeEditor([
			[
				'Lorem ipsum ',
				'dolor sit amet ',
				'consectetur ',
				'adipiscing elit',
			].join('')
		], { wordWrap: 'wordWrapColumn', wordWrapColumn: 16 }, (editor, cursor) => {
			cursor.setSelections('test', [new Selection(1, 7, 1, 7)]);

			moveRight(cursor);
			assertCursor(cursor, new Selection(1, 8, 1, 8));

			moveRight(cursor);
			assertCursor(cursor, new Selection(1, 9, 1, 9));

			moveRight(cursor);
			assertCursor(cursor, new Selection(1, 10, 1, 10));

			moveRight(cursor);
			assertCursor(cursor, new Selection(1, 11, 1, 11));

			moveRight(cursor);
			assertCursor(cursor, new Selection(1, 12, 1, 12));

			moveRight(cursor);
			assertCursor(cursor, new Selection(1, 13, 1, 13));

			// moving to view line 2
			moveRight(cursor);
			assertCursor(cursor, new Selection(1, 14, 1, 14));

			moveLeft(cursor);
			assertCursor(cursor, new Selection(1, 13, 1, 13));

			// moving back to view line 1
			moveLeft(cursor);
			assertCursor(cursor, new Selection(1, 12, 1, 12));
		});
	});

	test('issue #41573 - delete across multiple lines does not shrink the selection when word wraps', () => {
		const model = createTextModel([
			'Authorization: \'Bearer pHKRfCTFSnGxs6akKlb9ddIXcca0sIUSZJutPHYqz7vEeHdMTMh0SGN0IGU3a0n59DXjTLRsj5EJ2u33qLNIFi9fk5XF8pK39PndLYUZhPt4QvHGLScgSkK0L4gwzkzMloTQPpKhqiikiIOvyNNSpd2o8j29NnOmdTUOKi9DVt74PD2ohKxyOrWZ6oZprTkb3eKajcpnS0LABKfaw2rmv4\','
		].join('\n'));
		const config = new TestConfiguration({
			wordWrap: 'wordWrapColumn',
			wordWrapColumn: 100
		});
		const viewModel = new ViewModel(0, config, model, null);
		const cursor = new Cursor(config, model, viewModel);

		moveTo(cursor, 1, 43, false);
		moveTo(cursor, 1, 147, true);
		assertCursor(cursor, new Selection(1, 43, 1, 147));

		model.applyEdits([{
			range: new Range(1, 1, 1, 43),
			text: ''
		}]);

		assertCursor(cursor, new Selection(1, 1, 1, 105));

		cursor.dispose();
		viewModel.dispose();
		config.dispose();
		model.dispose();
	});

	test('issue #22717: Moving text cursor cause an incorrect position in Chinese', () => {
		// a single model line => 4 view lines
		withTestCodeEditor([
			[
				'一二三四五六七八九十',
				'12345678901234567890',
			].join('\n')
		], {}, (editor, cursor) => {
			cursor.setSelections('test', [new Selection(1, 5, 1, 5)]);

			moveDown(cursor);
			assertCursor(cursor, new Selection(2, 9, 2, 9));

			moveRight(cursor);
			assertCursor(cursor, new Selection(2, 10, 2, 10));

			moveRight(cursor);
			assertCursor(cursor, new Selection(2, 11, 2, 11));

			moveUp(cursor);
			assertCursor(cursor, new Selection(1, 6, 1, 6));
		});
	});

	test('issue #44805: Should not be able to undo in readonly editor', () => {
		let model = createTextModel(
			[
				''
			].join('\n')
		);

		withTestCodeEditor(null, { readOnly: true, model: model }, (editor, cursor) => {
			model.pushEditOperations([new Selection(1, 1, 1, 1)], [{
				range: new Range(1, 1, 1, 1),
				text: 'Hello world!'
			}], () => [new Selection(1, 1, 1, 1)]);
			assert.equal(model.getValue(EndOfLinePreference.LF), 'Hello world!');

			cursorCommand(cursor, H.Undo, {});
			assert.equal(model.getValue(EndOfLinePreference.LF), 'Hello world!');
		});

		model.dispose();
	});

	test('issue #46314: ViewModel is out of sync with Model!', () => {

		const tokenizationSupport: ITokenizationSupport = {
			getInitialState: () => NULL_STATE,
			tokenize: undefined,
			tokenize2: (line: string, state: IState): TokenizationResult2 => {
				return new TokenizationResult2(null, state);
			}
		};

		const LANGUAGE_ID = 'modelModeTest1';
		const languageRegistration = TokenizationRegistry.register(LANGUAGE_ID, tokenizationSupport);
		let model = createTextModel('Just text', undefined, new LanguageIdentifier(LANGUAGE_ID, 0));

		withTestCodeEditor(null, { model: model }, (editor1, cursor1) => {
			withTestCodeEditor(null, { model: model }, (editor2, cursor2) => {

				editor1.onDidChangeCursorPosition(() => {
					model.tokenizeIfCheap(1);
				});

				model.applyEdits([{ range: new Range(1, 1, 1, 1), text: '-' }]);
			});
		});

		languageRegistration.dispose();
		model.dispose();
	});

	test('issue #37967: problem replacing consecutive characters', () => {
		let model = createTextModel(
			[
				'const a = "foo";',
				'const b = ""'
			].join('\n')
		);

		withTestCodeEditor(null, { multiCursorMergeOverlapping: false, model: model }, (editor, cursor) => {
			editor.setSelections([
				new Selection(1, 12, 1, 12),
				new Selection(1, 16, 1, 16),
				new Selection(2, 12, 2, 12),
				new Selection(2, 13, 2, 13),
			]);

			CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);

			assertCursor(cursor, [
				new Selection(1, 11, 1, 11),
				new Selection(1, 14, 1, 14),
				new Selection(2, 11, 2, 11),
				new Selection(2, 11, 2, 11),
			]);

			cursorCommand(cursor, H.Type, { text: '\'' }, 'keyboard');

			assert.equal(model.getLineContent(1), 'const a = \'foo\';');
			assert.equal(model.getLineContent(2), 'const b = \'\'');
		});

		model.dispose();
	});

	test('issue #15761: Cursor doesn\'t move in a redo operation', () => {
		let model = createTextModel(
			[
				'hello'
			].join('\n')
		);

		withTestCodeEditor(null, { model: model }, (editor, cursor) => {
			editor.setSelections([
				new Selection(1, 4, 1, 4)
			]);

			editor.executeEdits('test', [{
				range: new Range(1, 1, 1, 1),
				text: '*',
				forceMoveMarkers: true
			}]);
			assertCursor(cursor, [
				new Selection(1, 5, 1, 5),
			]);

			cursorCommand(cursor, H.Undo, null, 'keyboard');
			assertCursor(cursor, [
				new Selection(1, 4, 1, 4),
			]);

			cursorCommand(cursor, H.Redo, null, 'keyboard');
			assertCursor(cursor, [
				new Selection(1, 5, 1, 5),
			]);
		});

		model.dispose();
	});

	test('issue #42783: API Calls with Undo Leave Cursor in Wrong Position', () => {
		let model = createTextModel(
			[
				'ab'
			].join('\n')
		);

		withTestCodeEditor(null, { model: model }, (editor, cursor) => {
			editor.setSelections([
				new Selection(1, 1, 1, 1)
			]);

			editor.executeEdits('test', [{
				range: new Range(1, 1, 1, 3),
				text: ''
			}]);
			assertCursor(cursor, [
				new Selection(1, 1, 1, 1),
			]);

			cursorCommand(cursor, H.Undo, null, 'keyboard');
			assertCursor(cursor, [
				new Selection(1, 1, 1, 1),
			]);

			editor.executeEdits('test', [{
				range: new Range(1, 1, 1, 2),
				text: ''
			}]);
			assertCursor(cursor, [
				new Selection(1, 1, 1, 1),
			]);
		});

		model.dispose();
	});
});

suite('Editor Controller - Cursor Configuration', () => {

	test('Cursor honors insertSpaces configuration on new line', () => {
		usingCursor({
			text: [
				'    \tMy First Line\t ',
				'\tMy Second Line',
				'    Third Line',
				'',
				'1'
			]
		}, (model, cursor) => {
			CoreNavigationCommands.MoveTo.runCoreEditorCommand(cursor, { position: new Position(1, 21), source: 'keyboard' });
			cursorCommand(cursor, H.Type, { text: '\n' }, 'keyboard');
			assert.equal(model.getLineContent(1), '    \tMy First Line\t ');
			assert.equal(model.getLineContent(2), '        ');
		});
	});

	test('Cursor honors insertSpaces configuration on tab', () => {
		let model = createTextModel(
			[
				'    \tMy First Line\t ',
				'My Second Line123',
				'    Third Line',
				'',
				'1'
			].join('\n'),
			{
				tabSize: 13,
			}
		);

		withTestCodeEditor(null, { model: model }, (editor, cursor) => {
			// Tab on column 1
			CoreNavigationCommands.MoveTo.runCoreEditorCommand(cursor, { position: new Position(2, 1) });
			CoreEditingCommands.Tab.runEditorCommand(null, editor, null);
			assert.equal(model.getLineContent(2), '             My Second Line123');
			cursorCommand(cursor, H.Undo, null, 'keyboard');

			// Tab on column 2
			assert.equal(model.getLineContent(2), 'My Second Line123');
			CoreNavigationCommands.MoveTo.runCoreEditorCommand(cursor, { position: new Position(2, 2) });
			CoreEditingCommands.Tab.runEditorCommand(null, editor, null);
			assert.equal(model.getLineContent(2), 'M            y Second Line123');
			cursorCommand(cursor, H.Undo, null, 'keyboard');

			// Tab on column 3
			assert.equal(model.getLineContent(2), 'My Second Line123');
			CoreNavigationCommands.MoveTo.runCoreEditorCommand(cursor, { position: new Position(2, 3) });
			CoreEditingCommands.Tab.runEditorCommand(null, editor, null);
			assert.equal(model.getLineContent(2), 'My            Second Line123');
			cursorCommand(cursor, H.Undo, null, 'keyboard');

			// Tab on column 4
			assert.equal(model.getLineContent(2), 'My Second Line123');
			CoreNavigationCommands.MoveTo.runCoreEditorCommand(cursor, { position: new Position(2, 4) });
			CoreEditingCommands.Tab.runEditorCommand(null, editor, null);
			assert.equal(model.getLineContent(2), 'My           Second Line123');
			cursorCommand(cursor, H.Undo, null, 'keyboard');

			// Tab on column 5
			assert.equal(model.getLineContent(2), 'My Second Line123');
			CoreNavigationCommands.MoveTo.runCoreEditorCommand(cursor, { position: new Position(2, 5) });
			CoreEditingCommands.Tab.runEditorCommand(null, editor, null);
			assert.equal(model.getLineContent(2), 'My S         econd Line123');
			cursorCommand(cursor, H.Undo, null, 'keyboard');

			// Tab on column 5
			assert.equal(model.getLineContent(2), 'My Second Line123');
			CoreNavigationCommands.MoveTo.runCoreEditorCommand(cursor, { position: new Position(2, 5) });
			CoreEditingCommands.Tab.runEditorCommand(null, editor, null);
			assert.equal(model.getLineContent(2), 'My S         econd Line123');
			cursorCommand(cursor, H.Undo, null, 'keyboard');

			// Tab on column 13
			assert.equal(model.getLineContent(2), 'My Second Line123');
			CoreNavigationCommands.MoveTo.runCoreEditorCommand(cursor, { position: new Position(2, 13) });
			CoreEditingCommands.Tab.runEditorCommand(null, editor, null);
			assert.equal(model.getLineContent(2), 'My Second Li ne123');
			cursorCommand(cursor, H.Undo, null, 'keyboard');

			// Tab on column 14
			assert.equal(model.getLineContent(2), 'My Second Line123');
			CoreNavigationCommands.MoveTo.runCoreEditorCommand(cursor, { position: new Position(2, 14) });
			CoreEditingCommands.Tab.runEditorCommand(null, editor, null);
			assert.equal(model.getLineContent(2), 'My Second Lin             e123');
		});

		model.dispose();
	});

	test('Enter auto-indents with insertSpaces setting 1', () => {
		let mode = new OnEnterMode(IndentAction.Indent);
		usingCursor({
			text: [
				'\thello'
			],
			languageIdentifier: mode.getLanguageIdentifier()
		}, (model, cursor) => {
			moveTo(cursor, 1, 7, false);
			assertCursor(cursor, new Selection(1, 7, 1, 7));

			cursorCommand(cursor, H.Type, { text: '\n' }, 'keyboard');
			assert.equal(model.getValue(EndOfLinePreference.CRLF), '\thello\r\n        ');
		});
		mode.dispose();
	});

	test('Enter auto-indents with insertSpaces setting 2', () => {
		let mode = new OnEnterMode(IndentAction.None);
		usingCursor({
			text: [
				'\thello'
			],
			languageIdentifier: mode.getLanguageIdentifier()
		}, (model, cursor) => {
			moveTo(cursor, 1, 7, false);
			assertCursor(cursor, new Selection(1, 7, 1, 7));

			cursorCommand(cursor, H.Type, { text: '\n' }, 'keyboard');
			assert.equal(model.getValue(EndOfLinePreference.CRLF), '\thello\r\n    ');
		});
		mode.dispose();
	});

	test('Enter auto-indents with insertSpaces setting 3', () => {
		let mode = new OnEnterMode(IndentAction.IndentOutdent);
		usingCursor({
			text: [
				'\thell()'
			],
			languageIdentifier: mode.getLanguageIdentifier()
		}, (model, cursor) => {
			moveTo(cursor, 1, 7, false);
			assertCursor(cursor, new Selection(1, 7, 1, 7));

			cursorCommand(cursor, H.Type, { text: '\n' }, 'keyboard');
			assert.equal(model.getValue(EndOfLinePreference.CRLF), '\thell(\r\n        \r\n    )');
		});
		mode.dispose();
	});

	test('removeAutoWhitespace off', () => {
		usingCursor({
			text: [
				'    some  line abc  '
			],
			modelOpts: {
				trimAutoWhitespace: false
			}
		}, (model, cursor) => {

			// Move cursor to the end, verify that we do not trim whitespaces if line has values
			moveTo(cursor, 1, model.getLineContent(1).length + 1);
			cursorCommand(cursor, H.Type, { text: '\n' }, 'keyboard');
			assert.equal(model.getLineContent(1), '    some  line abc  ');
			assert.equal(model.getLineContent(2), '    ');

			// Try to enter again, we should trimmed previous line
			cursorCommand(cursor, H.Type, { text: '\n' }, 'keyboard');
			assert.equal(model.getLineContent(1), '    some  line abc  ');
			assert.equal(model.getLineContent(2), '    ');
			assert.equal(model.getLineContent(3), '    ');
		});
	});

	test('removeAutoWhitespace on: removes only whitespace the cursor added 1', () => {
		usingCursor({
			text: [
				'    '
			]
		}, (model, cursor) => {
			moveTo(cursor, 1, model.getLineContent(1).length + 1);
			cursorCommand(cursor, H.Type, { text: '\n' }, 'keyboard');
			assert.equal(model.getLineContent(1), '    ');
			assert.equal(model.getLineContent(2), '    ');

			cursorCommand(cursor, H.Type, { text: '\n' }, 'keyboard');
			assert.equal(model.getLineContent(1), '    ');
			assert.equal(model.getLineContent(2), '');
			assert.equal(model.getLineContent(3), '    ');
		});
	});

	test('issue #6862: Editor removes auto inserted indentation when formatting on type', () => {
		let mode = new OnEnterMode(IndentAction.IndentOutdent);
		usingCursor({
			text: [
				'function foo (params: string) {}'
			],
			languageIdentifier: mode.getLanguageIdentifier(),
		}, (model, cursor) => {

			moveTo(cursor, 1, 32);
			cursorCommand(cursor, H.Type, { text: '\n' }, 'keyboard');
			assert.equal(model.getLineContent(1), 'function foo (params: string) {');
			assert.equal(model.getLineContent(2), '    ');
			assert.equal(model.getLineContent(3), '}');

			class TestCommand implements ICommand {

				private _selectionId: string | null = null;

				public getEditOperations(model: ITextModel, builder: IEditOperationBuilder): void {
					builder.addEditOperation(new Range(1, 13, 1, 14), '');
					this._selectionId = builder.trackSelection(cursor.getSelection());
				}

				public computeCursorState(model: ITextModel, helper: ICursorStateComputerData): Selection {
					return helper.getTrackedSelection(this._selectionId);
				}

			}

			cursor.trigger('autoFormat', Handler.ExecuteCommand, new TestCommand());
			assert.equal(model.getLineContent(1), 'function foo(params: string) {');
			assert.equal(model.getLineContent(2), '    ');
			assert.equal(model.getLineContent(3), '}');
		});
		mode.dispose();
	});

	test('removeAutoWhitespace on: removes only whitespace the cursor added 2', () => {
		let model = createTextModel(
			[
				'    if (a) {',
				'        ',
				'',
				'',
				'    }'
			].join('\n')
		);

		withTestCodeEditor(null, { model: model }, (editor, cursor) => {

			moveTo(cursor, 3, 1);
			CoreEditingCommands.Tab.runEditorCommand(null, editor, null);
			assert.equal(model.getLineContent(1), '    if (a) {');
			assert.equal(model.getLineContent(2), '        ');
			assert.equal(model.getLineContent(3), '    ');
			assert.equal(model.getLineContent(4), '');
			assert.equal(model.getLineContent(5), '    }');

			moveTo(cursor, 4, 1);
			CoreEditingCommands.Tab.runEditorCommand(null, editor, null);
			assert.equal(model.getLineContent(1), '    if (a) {');
			assert.equal(model.getLineContent(2), '        ');
			assert.equal(model.getLineContent(3), '');
			assert.equal(model.getLineContent(4), '    ');
			assert.equal(model.getLineContent(5), '    }');

			moveTo(cursor, 5, model.getLineMaxColumn(5));
			cursorCommand(cursor, H.Type, { text: 'something' }, 'keyboard');
			assert.equal(model.getLineContent(1), '    if (a) {');
			assert.equal(model.getLineContent(2), '        ');
			assert.equal(model.getLineContent(3), '');
			assert.equal(model.getLineContent(4), '');
			assert.equal(model.getLineContent(5), '    }something');
		});

		model.dispose();
	});

	test('removeAutoWhitespace on: test 1', () => {
		let model = createTextModel(
			[
				'    some  line abc  '
			].join('\n')
		);

		withTestCodeEditor(null, { model: model }, (editor, cursor) => {

			// Move cursor to the end, verify that we do not trim whitespaces if line has values
			moveTo(cursor, 1, model.getLineContent(1).length + 1);
			cursorCommand(cursor, H.Type, { text: '\n' }, 'keyboard');
			assert.equal(model.getLineContent(1), '    some  line abc  ');
			assert.equal(model.getLineContent(2), '    ');

			// Try to enter again, we should trimmed previous line
			cursorCommand(cursor, H.Type, { text: '\n' }, 'keyboard');
			assert.equal(model.getLineContent(1), '    some  line abc  ');
			assert.equal(model.getLineContent(2), '');
			assert.equal(model.getLineContent(3), '    ');

			// More whitespaces
			CoreEditingCommands.Tab.runEditorCommand(null, editor, null);
			assert.equal(model.getLineContent(1), '    some  line abc  ');
			assert.equal(model.getLineContent(2), '');
			assert.equal(model.getLineContent(3), '        ');

			// Enter and verify that trimmed again
			cursorCommand(cursor, H.Type, { text: '\n' }, 'keyboard');
			assert.equal(model.getLineContent(1), '    some  line abc  ');
			assert.equal(model.getLineContent(2), '');
			assert.equal(model.getLineContent(3), '');
			assert.equal(model.getLineContent(4), '        ');

			// Trimmed if we will keep only text
			moveTo(cursor, 1, 5);
			cursorCommand(cursor, H.Type, { text: '\n' }, 'keyboard');
			assert.equal(model.getLineContent(1), '    ');
			assert.equal(model.getLineContent(2), '    some  line abc  ');
			assert.equal(model.getLineContent(3), '');
			assert.equal(model.getLineContent(4), '');
			assert.equal(model.getLineContent(5), '');

			// Trimmed if we will keep only text by selection
			moveTo(cursor, 2, 5);
			moveTo(cursor, 3, 1, true);
			cursorCommand(cursor, H.Type, { text: '\n' }, 'keyboard');
			assert.equal(model.getLineContent(1), '    ');
			assert.equal(model.getLineContent(2), '    ');
			assert.equal(model.getLineContent(3), '    ');
			assert.equal(model.getLineContent(4), '');
			assert.equal(model.getLineContent(5), '');
		});

		model.dispose();
	});

	test('issue #15118: remove auto whitespace when pasting entire line', () => {
		let model = createTextModel(
			[
				'    function f() {',
				'        // I\'m gonna copy this line',
				'        return 3;',
				'    }',
			].join('\n')
		);

		withTestCodeEditor(null, { model: model }, (editor, cursor) => {

			moveTo(cursor, 3, model.getLineMaxColumn(3));
			cursorCommand(cursor, H.Type, { text: '\n' }, 'keyboard');

			assert.equal(model.getValue(), [
				'    function f() {',
				'        // I\'m gonna copy this line',
				'        return 3;',
				'        ',
				'    }',
			].join('\n'));
			assertCursor(cursor, new Position(4, model.getLineMaxColumn(4)));

			cursorCommand(cursor, H.Paste, { text: '        // I\'m gonna copy this line\n', pasteOnNewLine: true });
			assert.equal(model.getValue(), [
				'    function f() {',
				'        // I\'m gonna copy this line',
				'        return 3;',
				'        // I\'m gonna copy this line',
				'',
				'    }',
			].join('\n'));
			assertCursor(cursor, new Position(5, 1));
		});

		model.dispose();
	});

	test('UseTabStops is off', () => {
		let model = createTextModel(
			[
				'    x',
				'        a    ',
				'    '
			].join('\n')
		);

		withTestCodeEditor(null, { model: model, useTabStops: false }, (editor, cursor) => {
			// DeleteLeft removes just one whitespace
			moveTo(cursor, 2, 9);
			CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
			assert.equal(model.getLineContent(2), '       a    ');
		});

		model.dispose();
	});

	test('Backspace removes whitespaces with tab size', () => {
		let model = createTextModel(
			[
				' \t \t     x',
				'        a    ',
				'    '
			].join('\n')
		);

		withTestCodeEditor(null, { model: model, useTabStops: true }, (editor, cursor) => {
			// DeleteLeft does not remove tab size, because some text exists before
			moveTo(cursor, 2, model.getLineContent(2).length + 1);
			CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
			assert.equal(model.getLineContent(2), '        a   ');

			// DeleteLeft removes tab size = 4
			moveTo(cursor, 2, 9);
			CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
			assert.equal(model.getLineContent(2), '    a   ');

			// DeleteLeft removes tab size = 4
			CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
			assert.equal(model.getLineContent(2), 'a   ');

			// Undo DeleteLeft - get us back to original indentation
			cursorCommand(cursor, H.Undo, {});
			assert.equal(model.getLineContent(2), '        a   ');

			// Nothing is broken when cursor is in (1,1)
			moveTo(cursor, 1, 1);
			CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
			assert.equal(model.getLineContent(1), ' \t \t     x');

			// DeleteLeft stops at tab stops even in mixed whitespace case
			moveTo(cursor, 1, 10);
			CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
			assert.equal(model.getLineContent(1), ' \t \t    x');

			CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
			assert.equal(model.getLineContent(1), ' \t \tx');

			CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
			assert.equal(model.getLineContent(1), ' \tx');

			CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
			assert.equal(model.getLineContent(1), 'x');

			// DeleteLeft on last line
			moveTo(cursor, 3, model.getLineContent(3).length + 1);
			CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
			assert.equal(model.getLineContent(3), '');

			// DeleteLeft with removing new line symbol
			CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
			assert.equal(model.getValue(EndOfLinePreference.LF), 'x\n        a   ');

			// In case of selection DeleteLeft only deletes selected text
			moveTo(cursor, 2, 3);
			moveTo(cursor, 2, 4, true);
			CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
			assert.equal(model.getLineContent(2), '       a   ');
		});

		model.dispose();
	});

	test('PR #5423: Auto indent + undo + redo is funky', () => {
		let model = createTextModel(
			[
				''
			].join('\n'),
			{
				insertSpaces: false,
			}
		);

		withTestCodeEditor(null, { model: model }, (editor, cursor) => {
			cursorCommand(cursor, H.Type, { text: '\n' }, 'keyboard');
			assert.equal(model.getValue(EndOfLinePreference.LF), '\n', 'assert1');

			CoreEditingCommands.Tab.runEditorCommand(null, editor, null);
			assert.equal(model.getValue(EndOfLinePreference.LF), '\n\t', 'assert2');

			cursorCommand(cursor, H.Type, { text: 'y' }, 'keyboard');
			assert.equal(model.getValue(EndOfLinePreference.LF), '\n\ty', 'assert2');

			cursorCommand(cursor, H.Type, { text: '\n' }, 'keyboard');
			assert.equal(model.getValue(EndOfLinePreference.LF), '\n\ty\n\t', 'assert3');

			cursorCommand(cursor, H.Type, { text: 'x' });
			assert.equal(model.getValue(EndOfLinePreference.LF), '\n\ty\n\tx', 'assert4');

			CoreNavigationCommands.CursorLeft.runCoreEditorCommand(cursor, {});
			assert.equal(model.getValue(EndOfLinePreference.LF), '\n\ty\n\tx', 'assert5');

			CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
			assert.equal(model.getValue(EndOfLinePreference.LF), '\n\ty\nx', 'assert6');

			CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
			assert.equal(model.getValue(EndOfLinePreference.LF), '\n\tyx', 'assert7');

			CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
			assert.equal(model.getValue(EndOfLinePreference.LF), '\n\tx', 'assert8');

			CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
			assert.equal(model.getValue(EndOfLinePreference.LF), '\nx', 'assert9');

			CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
			assert.equal(model.getValue(EndOfLinePreference.LF), 'x', 'assert10');

			cursorCommand(cursor, H.Undo, {});
			assert.equal(model.getValue(EndOfLinePreference.LF), '\nx', 'assert11');

			cursorCommand(cursor, H.Undo, {});
			assert.equal(model.getValue(EndOfLinePreference.LF), '\n\ty\nx', 'assert12');

			cursorCommand(cursor, H.Undo, {});
			assert.equal(model.getValue(EndOfLinePreference.LF), '\n\ty\n\tx', 'assert13');

			cursorCommand(cursor, H.Redo, {});
			assert.equal(model.getValue(EndOfLinePreference.LF), '\n\ty\nx', 'assert14');

			cursorCommand(cursor, H.Redo, {});
			assert.equal(model.getValue(EndOfLinePreference.LF), '\nx', 'assert15');

			cursorCommand(cursor, H.Redo, {});
			assert.equal(model.getValue(EndOfLinePreference.LF), 'x', 'assert16');
		});

		model.dispose();
	});
});

suite('Editor Controller - Indentation Rules', () => {
	let mode = new IndentRulesMode({
		decreaseIndentPattern: /^\s*((?!\S.*\/[*]).*[*]\/\s*)?[})\]]|^\s*(case\b.*|default):\s*(\/\/.*|\/[*].*[*]\/\s*)?$/,
		increaseIndentPattern: /^((?!\/\/).)*(\{[^}"'`]*|\([^)"']*|\[[^\]"']*|^\s*(\{\}|\(\)|\[\]|(case\b.*|default):))\s*(\/\/.*|\/[*].*[*]\/\s*)?$/,
		indentNextLinePattern: /^\s*(for|while|if|else)\b(?!.*[;{}]\s*(\/\/.*|\/[*].*[*]\/\s*)?$)/,
		unIndentedLinePattern: /^(?!.*([;{}]|\S:)\s*(\/\/.*|\/[*].*[*]\/\s*)?$)(?!.*(\{[^}"']*|\([^)"']*|\[[^\]"']*|^\s*(\{\}|\(\)|\[\]|(case\b.*|default):))\s*(\/\/.*|\/[*].*[*]\/\s*)?$)(?!^\s*((?!\S.*\/[*]).*[*]\/\s*)?[})\]]|^\s*(case\b.*|default):\s*(\/\/.*|\/[*].*[*]\/\s*)?$)(?!^\s*(for|while|if|else)\b(?!.*[;{}]\s*(\/\/.*|\/[*].*[*]\/\s*)?$))/
	});

	test('Enter honors increaseIndentPattern', () => {
		usingCursor({
			text: [
				'if (true) {',
				'\tif (true) {'
			],
			languageIdentifier: mode.getLanguageIdentifier(),
			modelOpts: { insertSpaces: false },
			editorOpts: { autoIndent: true }
		}, (model, cursor) => {
			moveTo(cursor, 1, 12, false);
			assertCursor(cursor, new Selection(1, 12, 1, 12));

			cursorCommandAndTokenize(model, cursor, H.Type, { text: '\n' }, 'keyboard');
			assertCursor(cursor, new Selection(2, 2, 2, 2));

			moveTo(cursor, 3, 13, false);
			assertCursor(cursor, new Selection(3, 13, 3, 13));

			cursorCommand(cursor, H.Type, { text: '\n' }, 'keyboard');
			assertCursor(cursor, new Selection(4, 3, 4, 3));
		});
	});

	test('Type honors decreaseIndentPattern', () => {
		usingCursor({
			text: [
				'if (true) {',
				'\t'
			],
			languageIdentifier: mode.getLanguageIdentifier(),
			editorOpts: { autoIndent: true }
		}, (model, cursor) => {
			moveTo(cursor, 2, 2, false);
			assertCursor(cursor, new Selection(2, 2, 2, 2));

			cursorCommand(cursor, H.Type, { text: '}' }, 'keyboard');
			assertCursor(cursor, new Selection(2, 2, 2, 2));
			assert.equal(model.getLineContent(2), '}', '001');
		});
	});

	test('Enter honors unIndentedLinePattern', () => {
		usingCursor({
			text: [
				'if (true) {',
				'\t\t\treturn true'
			],
			languageIdentifier: mode.getLanguageIdentifier(),
			modelOpts: { insertSpaces: false },
			editorOpts: { autoIndent: true }
		}, (model, cursor) => {
			moveTo(cursor, 2, 15, false);
			assertCursor(cursor, new Selection(2, 15, 2, 15));

			cursorCommand(cursor, H.Type, { text: '\n' }, 'keyboard');
			assertCursor(cursor, new Selection(3, 2, 3, 2));
		});
	});

	test('Enter honors indentNextLinePattern', () => {
		usingCursor({
			text: [
				'if (true)',
				'\treturn true;',
				'if (true)',
				'\t\t\t\treturn true'
			],
			languageIdentifier: mode.getLanguageIdentifier(),
			modelOpts: { insertSpaces: false },
			editorOpts: { autoIndent: true }
		}, (model, cursor) => {
			moveTo(cursor, 2, 14, false);
			assertCursor(cursor, new Selection(2, 14, 2, 14));

			cursorCommandAndTokenize(model, cursor, H.Type, { text: '\n' }, 'keyboard');
			assertCursor(cursor, new Selection(3, 1, 3, 1));

			moveTo(cursor, 5, 16, false);
			assertCursor(cursor, new Selection(5, 16, 5, 16));

			cursorCommand(cursor, H.Type, { text: '\n' }, 'keyboard');
			assertCursor(cursor, new Selection(6, 2, 6, 2));
		});
	});

	test('Enter honors indentNextLinePattern 2', () => {
		let model = createTextModel(
			[
				'if (true)',
				'\tif (true)'
			].join('\n'),
			{
				insertSpaces: false,
			},
			mode.getLanguageIdentifier()
		);

		withTestCodeEditor(null, { model: model, autoIndent: true }, (editor, cursor) => {
			moveTo(cursor, 2, 11, false);
			assertCursor(cursor, new Selection(2, 11, 2, 11));

			cursorCommandAndTokenize(model, cursor, H.Type, { text: '\n' }, 'keyboard');
			assertCursor(cursor, new Selection(3, 3, 3, 3));

			cursorCommand(cursor, H.Type, { text: 'console.log();' }, 'keyboard');
			cursorCommand(cursor, H.Type, { text: '\n' }, 'keyboard');
			assertCursor(cursor, new Selection(4, 1, 4, 1));
		});

		model.dispose();
	});

	test('Enter honors intential indent', () => {
		usingCursor({
			text: [
				'if (true) {',
				'\tif (true) {',
				'return true;',
				'}}'
			],
			languageIdentifier: mode.getLanguageIdentifier(),
			editorOpts: { autoIndent: true }
		}, (model, cursor) => {
			moveTo(cursor, 3, 13, false);
			assertCursor(cursor, new Selection(3, 13, 3, 13));

			cursorCommand(cursor, H.Type, { text: '\n' }, 'keyboard');
			assertCursor(cursor, new Selection(4, 1, 4, 1));
			assert.equal(model.getLineContent(3), 'return true;', '001');
		});
	});

	test('Enter supports selection 1', () => {
		usingCursor({
			text: [
				'if (true) {',
				'\tif (true) {',
				'\t\treturn true;',
				'\t}a}'
			],
			languageIdentifier: mode.getLanguageIdentifier(),
			modelOpts: { insertSpaces: false }
		}, (model, cursor) => {
			moveTo(cursor, 4, 3, false);
			moveTo(cursor, 4, 4, true);
			assertCursor(cursor, new Selection(4, 3, 4, 4));

			cursorCommand(cursor, H.Type, { text: '\n' }, 'keyboard');
			assertCursor(cursor, new Selection(5, 1, 5, 1));
			assert.equal(model.getLineContent(4), '\t}', '001');
		});
	});

	test('Enter supports selection 2', () => {
		usingCursor({
			text: [
				'if (true) {',
				'\tif (true) {'
			],
			languageIdentifier: mode.getLanguageIdentifier(),
			modelOpts: { insertSpaces: false }
		}, (model, cursor) => {
			moveTo(cursor, 2, 12, false);
			moveTo(cursor, 2, 13, true);
			assertCursor(cursor, new Selection(2, 12, 2, 13));

			cursorCommand(cursor, H.Type, { text: '\n' }, 'keyboard');
			assertCursor(cursor, new Selection(3, 3, 3, 3));

			cursorCommand(cursor, H.Type, { text: '\n' }, 'keyboard');
			assertCursor(cursor, new Selection(4, 3, 4, 3));
		});
	});

	test('Enter honors tabSize and insertSpaces 1', () => {
		usingCursor({
			text: [
				'if (true) {',
				'\tif (true) {'
			],
			languageIdentifier: mode.getLanguageIdentifier(),
		}, (model, cursor) => {
			moveTo(cursor, 1, 12, false);
			assertCursor(cursor, new Selection(1, 12, 1, 12));

			cursorCommand(cursor, H.Type, { text: '\n' }, 'keyboard');
			assertCursor(cursor, new Selection(2, 5, 2, 5));

			model.forceTokenization(model.getLineCount());

			moveTo(cursor, 3, 13, false);
			assertCursor(cursor, new Selection(3, 13, 3, 13));

			cursorCommand(cursor, H.Type, { text: '\n' }, 'keyboard');
			assertCursor(cursor, new Selection(4, 9, 4, 9));
		});
	});

	test('Enter honors tabSize and insertSpaces 2', () => {
		usingCursor({
			text: [
				'if (true) {',
				'    if (true) {'
			],
			languageIdentifier: mode.getLanguageIdentifier(),
		}, (model, cursor) => {
			moveTo(cursor, 1, 12, false);
			assertCursor(cursor, new Selection(1, 12, 1, 12));

			cursorCommandAndTokenize(model, cursor, H.Type, { text: '\n' }, 'keyboard');
			assertCursor(cursor, new Selection(2, 5, 2, 5));

			moveTo(cursor, 3, 16, false);
			assertCursor(cursor, new Selection(3, 16, 3, 16));

			cursorCommand(cursor, H.Type, { text: '\n' }, 'keyboard');
			assert.equal(model.getLineContent(3), '    if (true) {');
			assertCursor(cursor, new Selection(4, 9, 4, 9));
		});
	});

	test('Enter honors tabSize and insertSpaces 3', () => {
		usingCursor({
			text: [
				'if (true) {',
				'    if (true) {'
			],
			languageIdentifier: mode.getLanguageIdentifier(),
			modelOpts: { insertSpaces: false }
		}, (model, cursor) => {
			moveTo(cursor, 1, 12, false);
			assertCursor(cursor, new Selection(1, 12, 1, 12));

			cursorCommandAndTokenize(model, cursor, H.Type, { text: '\n' }, 'keyboard');
			assertCursor(cursor, new Selection(2, 2, 2, 2));

			moveTo(cursor, 3, 16, false);
			assertCursor(cursor, new Selection(3, 16, 3, 16));

			cursorCommand(cursor, H.Type, { text: '\n' }, 'keyboard');
			assert.equal(model.getLineContent(3), '    if (true) {');
			assertCursor(cursor, new Selection(4, 3, 4, 3));
		});
	});

	test('Enter supports intentional indentation', () => {
		usingCursor({
			text: [
				'\tif (true) {',
				'\t\tswitch(true) {',
				'\t\t\tcase true:',
				'\t\t\t\tbreak;',
				'\t\t}',
				'\t}'
			],
			languageIdentifier: mode.getLanguageIdentifier(),
			modelOpts: { insertSpaces: false },
			editorOpts: { autoIndent: true }
		}, (model, cursor) => {
			moveTo(cursor, 5, 4, false);
			assertCursor(cursor, new Selection(5, 4, 5, 4));

			cursorCommand(cursor, H.Type, { text: '\n' }, 'keyboard');
			assert.equal(model.getLineContent(5), '\t\t}');
			assertCursor(cursor, new Selection(6, 3, 6, 3));
		});
	});

	test('Enter should not adjust cursor position when press enter in the middle of a line 1', () => {
		usingCursor({
			text: [
				'if (true) {',
				'\tif (true) {',
				'\t\treturn true;',
				'\t}a}'
			],
			languageIdentifier: mode.getLanguageIdentifier(),
			modelOpts: { insertSpaces: false }
		}, (model, cursor) => {
			moveTo(cursor, 3, 9, false);
			assertCursor(cursor, new Selection(3, 9, 3, 9));

			cursorCommand(cursor, H.Type, { text: '\n' }, 'keyboard');
			assertCursor(cursor, new Selection(4, 3, 4, 3));
			assert.equal(model.getLineContent(4), '\t\t true;', '001');
		});
	});

	test('Enter should not adjust cursor position when press enter in the middle of a line 2', () => {
		usingCursor({
			text: [
				'if (true) {',
				'\tif (true) {',
				'\t\treturn true;',
				'\t}a}'
			],
			languageIdentifier: mode.getLanguageIdentifier(),
			modelOpts: { insertSpaces: false }
		}, (model, cursor) => {
			moveTo(cursor, 3, 3, false);
			assertCursor(cursor, new Selection(3, 3, 3, 3));

			cursorCommand(cursor, H.Type, { text: '\n' }, 'keyboard');
			assertCursor(cursor, new Selection(4, 3, 4, 3));
			assert.equal(model.getLineContent(4), '\t\treturn true;', '001');
		});
	});

	test('Enter should not adjust cursor position when press enter in the middle of a line 3', () => {
		usingCursor({
			text: [
				'if (true) {',
				'  if (true) {',
				'    return true;',
				'  }a}'
			],
			languageIdentifier: mode.getLanguageIdentifier()
		}, (model, cursor) => {
			moveTo(cursor, 3, 11, false);
			assertCursor(cursor, new Selection(3, 11, 3, 11));

			cursorCommand(cursor, H.Type, { text: '\n' }, 'keyboard');
			assertCursor(cursor, new Selection(4, 5, 4, 5));
			assert.equal(model.getLineContent(4), '     true;', '001');
		});
	});

	test('Enter should adjust cursor position when press enter in the middle of leading whitespaces 1', () => {
		usingCursor({
			text: [
				'if (true) {',
				'\tif (true) {',
				'\t\treturn true;',
				'\t}a}'
			],
			languageIdentifier: mode.getLanguageIdentifier(),
			modelOpts: { insertSpaces: false }
		}, (model, cursor) => {
			moveTo(cursor, 3, 2, false);
			assertCursor(cursor, new Selection(3, 2, 3, 2));

			cursorCommand(cursor, H.Type, { text: '\n' }, 'keyboard');
			assertCursor(cursor, new Selection(4, 2, 4, 2));
			assert.equal(model.getLineContent(4), '\t\treturn true;', '001');

			moveTo(cursor, 4, 1, false);
			assertCursor(cursor, new Selection(4, 1, 4, 1));

			cursorCommand(cursor, H.Type, { text: '\n' }, 'keyboard');
			assertCursor(cursor, new Selection(5, 1, 5, 1));
			assert.equal(model.getLineContent(5), '\t\treturn true;', '002');
		});
	});

	test('Enter should adjust cursor position when press enter in the middle of leading whitespaces 2', () => {
		usingCursor({
			text: [
				'\tif (true) {',
				'\t\tif (true) {',
				'\t    \treturn true;',
				'\t\t}a}'
			],
			languageIdentifier: mode.getLanguageIdentifier(),
			modelOpts: { insertSpaces: false }
		}, (model, cursor) => {
			moveTo(cursor, 3, 4, false);
			assertCursor(cursor, new Selection(3, 4, 3, 4));

			cursorCommand(cursor, H.Type, { text: '\n' }, 'keyboard');
			assertCursor(cursor, new Selection(4, 3, 4, 3));
			assert.equal(model.getLineContent(4), '\t\t\treturn true;', '001');

			moveTo(cursor, 4, 1, false);
			assertCursor(cursor, new Selection(4, 1, 4, 1));

			cursorCommand(cursor, H.Type, { text: '\n' }, 'keyboard');
			assertCursor(cursor, new Selection(5, 1, 5, 1));
			assert.equal(model.getLineContent(5), '\t\t\treturn true;', '002');
		});
	});

	test('Enter should adjust cursor position when press enter in the middle of leading whitespaces 3', () => {
		usingCursor({
			text: [
				'if (true) {',
				'  if (true) {',
				'    return true;',
				'}a}'
			],
			languageIdentifier: mode.getLanguageIdentifier()
		}, (model, cursor) => {
			moveTo(cursor, 3, 2, false);
			assertCursor(cursor, new Selection(3, 2, 3, 2));

			cursorCommand(cursor, H.Type, { text: '\n' }, 'keyboard');
			assertCursor(cursor, new Selection(4, 2, 4, 2));
			assert.equal(model.getLineContent(4), '    return true;', '001');

			moveTo(cursor, 4, 3, false);
			cursorCommand(cursor, H.Type, { text: '\n' }, 'keyboard');
			assertCursor(cursor, new Selection(5, 3, 5, 3));
			assert.equal(model.getLineContent(5), '    return true;', '002');
		});
	});

	test('Enter should adjust cursor position when press enter in the middle of leading whitespaces 4', () => {
		usingCursor({
			text: [
				'if (true) {',
				'  if (true) {',
				'\t  return true;',
				'}a}',
				'',
				'if (true) {',
				'  if (true) {',
				'\t  return true;',
				'}a}'
			],
			languageIdentifier: mode.getLanguageIdentifier(),
			modelOpts: { tabSize: 2 }
		}, (model, cursor) => {
			moveTo(cursor, 3, 3, false);
			assertCursor(cursor, new Selection(3, 3, 3, 3));

			cursorCommand(cursor, H.Type, { text: '\n' }, 'keyboard');
			assertCursor(cursor, new Selection(4, 4, 4, 4));
			assert.equal(model.getLineContent(4), '    return true;', '001');

			moveTo(cursor, 9, 4, false);
			cursorCommand(cursor, H.Type, { text: '\n' }, 'keyboard');
			assertCursor(cursor, new Selection(10, 5, 10, 5));
			assert.equal(model.getLineContent(10), '    return true;', '001');
		});
	});

	test('Enter should adjust cursor position when press enter in the middle of leading whitespaces 5', () => {
		usingCursor({
			text: [
				'if (true) {',
				'  if (true) {',
				'    return true;',
				'    return true;',
				''
			],
			languageIdentifier: mode.getLanguageIdentifier(),
			modelOpts: { tabSize: 2 }
		}, (model, cursor) => {
			moveTo(cursor, 3, 5, false);
			moveTo(cursor, 4, 3, true);
			assertCursor(cursor, new Selection(3, 5, 4, 3));

			cursorCommand(cursor, H.Type, { text: '\n' }, 'keyboard');
			assertCursor(cursor, new Selection(4, 3, 4, 3));
			assert.equal(model.getLineContent(4), '    return true;', '001');
		});
	});

	test('issue Microsoft/monaco-editor#108 part 1/2: Auto indentation on Enter with selection is half broken', () => {
		usingCursor({
			text: [
				'function baz() {',
				'\tvar x = 1;',
				'\t\t\t\t\t\t\treturn x;',
				'}'
			],
			modelOpts: {
				insertSpaces: false,
			},
			languageIdentifier: mode.getLanguageIdentifier(),
		}, (model, cursor) => {
			moveTo(cursor, 3, 8, false);
			moveTo(cursor, 2, 12, true);
			assertCursor(cursor, new Selection(3, 8, 2, 12));

			cursorCommand(cursor, H.Type, { text: '\n' }, 'keyboard');
			assert.equal(model.getLineContent(3), '\treturn x;');
			assertCursor(cursor, new Position(3, 2));
		});
	});

	test('issue Microsoft/monaco-editor#108 part 2/2: Auto indentation on Enter with selection is half broken', () => {
		usingCursor({
			text: [
				'function baz() {',
				'\tvar x = 1;',
				'\t\t\t\t\t\t\treturn x;',
				'}'
			],
			modelOpts: {
				insertSpaces: false,
			},
			languageIdentifier: mode.getLanguageIdentifier(),
		}, (model, cursor) => {
			moveTo(cursor, 2, 12, false);
			moveTo(cursor, 3, 8, true);
			assertCursor(cursor, new Selection(2, 12, 3, 8));

			cursorCommand(cursor, H.Type, { text: '\n' }, 'keyboard');
			assert.equal(model.getLineContent(3), '\treturn x;');
			assertCursor(cursor, new Position(3, 2));
		});
	});

	test('onEnter works if there are no indentation rules', () => {
		usingCursor({
			text: [
				'<?',
				'\tif (true) {',
				'\t\techo $hi;',
				'\t\techo $bye;',
				'\t}',
				'?>'
			],
			modelOpts: { insertSpaces: false }
		}, (model, cursor) => {
			moveTo(cursor, 5, 3, false);
			assertCursor(cursor, new Selection(5, 3, 5, 3));

			cursorCommand(cursor, H.Type, { text: '\n' }, 'keyboard');
			assert.equal(model.getLineContent(6), '\t');
			assertCursor(cursor, new Selection(6, 2, 6, 2));
			assert.equal(model.getLineContent(5), '\t}');
		});
	});

	test('onEnter works if there are no indentation rules 2', () => {
		usingCursor({
			text: [
				'	if (5)',
				'		return 5;',
				'	'
			],
			modelOpts: { insertSpaces: false }
		}, (model, cursor) => {
			moveTo(cursor, 3, 2, false);
			assertCursor(cursor, new Selection(3, 2, 3, 2));

			cursorCommand(cursor, H.Type, { text: '\n' }, 'keyboard');
			assertCursor(cursor, new Selection(4, 2, 4, 2));
			assert.equal(model.getLineContent(4), '\t');
		});
	});

	test('bug #16543: Tab should indent to correct indentation spot immediately', () => {
		let model = createTextModel(
			[
				'function baz() {',
				'\tfunction hello() { // something here',
				'\t',
				'',
				'\t}',
				'}'
			].join('\n'),
			{
				insertSpaces: false,
			},
			mode.getLanguageIdentifier()
		);

		withTestCodeEditor(null, { model: model }, (editor, cursor) => {
			moveTo(cursor, 4, 1, false);
			assertCursor(cursor, new Selection(4, 1, 4, 1));

			CoreEditingCommands.Tab.runEditorCommand(null, editor, null);
			assert.equal(model.getLineContent(4), '\t\t');
		});

		model.dispose();
	});


	test('bug #2938 (1): When pressing Tab on white-space only lines, indent straight to the right spot (similar to empty lines)', () => {
		let model = createTextModel(
			[
				'\tfunction baz() {',
				'\t\tfunction hello() { // something here',
				'\t\t',
				'\t',
				'\t\t}',
				'\t}'
			].join('\n'),
			{
				insertSpaces: false,
			},
			mode.getLanguageIdentifier()
		);

		withTestCodeEditor(null, { model: model }, (editor, cursor) => {
			moveTo(cursor, 4, 2, false);
			assertCursor(cursor, new Selection(4, 2, 4, 2));

			CoreEditingCommands.Tab.runEditorCommand(null, editor, null);
			assert.equal(model.getLineContent(4), '\t\t\t');
		});

		model.dispose();
	});


	test('bug #2938 (2): When pressing Tab on white-space only lines, indent straight to the right spot (similar to empty lines)', () => {
		let model = createTextModel(
			[
				'\tfunction baz() {',
				'\t\tfunction hello() { // something here',
				'\t\t',
				'    ',
				'\t\t}',
				'\t}'
			].join('\n'),
			{
				insertSpaces: false,
			},
			mode.getLanguageIdentifier()
		);

		withTestCodeEditor(null, { model: model }, (editor, cursor) => {
			moveTo(cursor, 4, 1, false);
			assertCursor(cursor, new Selection(4, 1, 4, 1));

			CoreEditingCommands.Tab.runEditorCommand(null, editor, null);
			assert.equal(model.getLineContent(4), '\t\t\t');
		});

		model.dispose();
	});

	test('bug #2938 (3): When pressing Tab on white-space only lines, indent straight to the right spot (similar to empty lines)', () => {
		let model = createTextModel(
			[
				'\tfunction baz() {',
				'\t\tfunction hello() { // something here',
				'\t\t',
				'\t\t\t',
				'\t\t}',
				'\t}'
			].join('\n'),
			{
				insertSpaces: false,
			},
			mode.getLanguageIdentifier()
		);

		withTestCodeEditor(null, { model: model }, (editor, cursor) => {
			moveTo(cursor, 4, 3, false);
			assertCursor(cursor, new Selection(4, 3, 4, 3));

			CoreEditingCommands.Tab.runEditorCommand(null, editor, null);
			assert.equal(model.getLineContent(4), '\t\t\t\t');
		});

		model.dispose();
	});

	test('bug #2938 (4): When pressing Tab on white-space only lines, indent straight to the right spot (similar to empty lines)', () => {
		let model = createTextModel(
			[
				'\tfunction baz() {',
				'\t\tfunction hello() { // something here',
				'\t\t',
				'\t\t\t\t',
				'\t\t}',
				'\t}'
			].join('\n'),
			{
				insertSpaces: false,
			},
			mode.getLanguageIdentifier()
		);

		withTestCodeEditor(null, { model: model }, (editor, cursor) => {
			moveTo(cursor, 4, 4, false);
			assertCursor(cursor, new Selection(4, 4, 4, 4));

			CoreEditingCommands.Tab.runEditorCommand(null, editor, null);
			assert.equal(model.getLineContent(4), '\t\t\t\t\t');
		});

		model.dispose();
	});

	test('bug #31015: When pressing Tab on lines and Enter rules are avail, indent straight to the right spotTab', () => {
		let mode = new OnEnterMode(IndentAction.Indent);
		let model = createTextModel(
			[
				'    if (a) {',
				'        ',
				'',
				'',
				'    }'
			].join('\n'),
			undefined,
			mode.getLanguageIdentifier()
		);

		withTestCodeEditor(null, { model: model }, (editor, cursor) => {

			moveTo(cursor, 3, 1);
			CoreEditingCommands.Tab.runEditorCommand(null, editor, null);
			assert.equal(model.getLineContent(1), '    if (a) {');
			assert.equal(model.getLineContent(2), '        ');
			assert.equal(model.getLineContent(3), '        ');
			assert.equal(model.getLineContent(4), '');
			assert.equal(model.getLineContent(5), '    }');
		});

		model.dispose();
	});

	test('type honors indentation rules: ruby keywords', () => {
		let rubyMode = new IndentRulesMode({
			increaseIndentPattern: /^\s*((begin|class|def|else|elsif|ensure|for|if|module|rescue|unless|until|when|while)|(.*\sdo\b))\b[^\{;]*$/,
			decreaseIndentPattern: /^\s*([}\]]([,)]?\s*(#|$)|\.[a-zA-Z_]\w*\b)|(end|rescue|ensure|else|elsif|when)\b)/
		});
		let model = createTextModel(
			[
				'class Greeter',
				'  def initialize(name)',
				'    @name = name',
				'    en'
			].join('\n'),
			undefined,
			rubyMode.getLanguageIdentifier()
		);

		withTestCodeEditor(null, { model: model, autoIndent: true }, (editor, cursor) => {
			moveTo(cursor, 4, 7, false);
			assertCursor(cursor, new Selection(4, 7, 4, 7));

			cursorCommand(cursor, H.Type, { text: 'd' }, 'keyboard');
			assert.equal(model.getLineContent(4), '  end');
		});

		rubyMode.dispose();
		model.dispose();
	});

	test('Auto indent on type: increaseIndentPattern has higher priority than decreaseIndent when inheriting', () => {
		usingCursor({
			text: [
				'\tif (true) {',
				'\t\tconsole.log();',
				'\t} else if {',
				'\t\tconsole.log()',
				'\t}'
			],
			languageIdentifier: mode.getLanguageIdentifier()
		}, (model, cursor) => {
			moveTo(cursor, 5, 3, false);
			assertCursor(cursor, new Selection(5, 3, 5, 3));

			cursorCommand(cursor, H.Type, { text: 'e' }, 'keyboard');
			assertCursor(cursor, new Selection(5, 4, 5, 4));
			assert.equal(model.getLineContent(5), '\t}e', 'This line should not decrease indent');
		});
	});

	test('type honors users indentation adjustment', () => {
		usingCursor({
			text: [
				'\tif (true ||',
				'\t ) {',
				'\t}',
				'if (true ||',
				') {',
				'}'
			],
			languageIdentifier: mode.getLanguageIdentifier()
		}, (model, cursor) => {
			moveTo(cursor, 2, 3, false);
			assertCursor(cursor, new Selection(2, 3, 2, 3));

			cursorCommand(cursor, H.Type, { text: ' ' }, 'keyboard');
			assertCursor(cursor, new Selection(2, 4, 2, 4));
			assert.equal(model.getLineContent(2), '\t  ) {', 'This line should not decrease indent');
		});
	});

	test('bug 29972: if a line is line comment, open bracket should not indent next line', () => {
		usingCursor({
			text: [
				'if (true) {',
				'\t// {',
				'\t\t'
			],
			languageIdentifier: mode.getLanguageIdentifier(),
			editorOpts: { autoIndent: true }
		}, (model, cursor) => {
			moveTo(cursor, 3, 3, false);
			assertCursor(cursor, new Selection(3, 3, 3, 3));

			cursorCommand(cursor, H.Type, { text: '}' }, 'keyboard');
			assertCursor(cursor, new Selection(3, 2, 3, 2));
			assert.equal(model.getLineContent(3), '}');
		});
	});

	test('issue #36090: JS: editor.autoIndent seems to be broken', () => {
		class JSMode extends MockMode {
			private static readonly _id = new LanguageIdentifier('indentRulesMode', 4);
			constructor() {
				super(JSMode._id);
				this._register(LanguageConfigurationRegistry.register(this.getLanguageIdentifier(), {
					brackets: [
						['{', '}'],
						['[', ']'],
						['(', ')']
					],
					indentationRules: {
						// ^(.*\*/)?\s*\}.*$
						decreaseIndentPattern: /^((?!.*?\/\*).*\*\/)?\s*[\}\]\)].*$/,
						// ^.*\{[^}"']*$
						increaseIndentPattern: /^((?!\/\/).)*(\{[^}"'`]*|\([^)"'`]*|\[[^\]"'`]*)$/
					},
					onEnterRules: javascriptOnEnterRules
				}));
			}
		}

		let mode = new JSMode();
		let model = createTextModel(
			[
				'class ItemCtrl {',
				'    getPropertiesByItemId(id) {',
				'        return this.fetchItem(id)',
				'            .then(item => {',
				'                return this.getPropertiesOfItem(item);',
				'            });',
				'    }',
				'}',
			].join('\n'),
			undefined,
			mode.getLanguageIdentifier()
		);

		withTestCodeEditor(null, { model: model, autoIndent: false }, (editor, cursor) => {
			moveTo(cursor, 7, 6, false);
			assertCursor(cursor, new Selection(7, 6, 7, 6));

			cursorCommand(cursor, H.Type, { text: '\n' }, 'keyboard');
			assert.equal(model.getValue(),
				[
					'class ItemCtrl {',
					'    getPropertiesByItemId(id) {',
					'        return this.fetchItem(id)',
					'            .then(item => {',
					'                return this.getPropertiesOfItem(item);',
					'            });',
					'    }',
					'    ',
					'}',
				].join('\n')
			);
			assertCursor(cursor, new Selection(8, 5, 8, 5));
		});

		model.dispose();
		mode.dispose();
	});

	test('issue #38261: TAB key results in bizarre indentation in C++ mode ', () => {
		class CppMode extends MockMode {
			private static readonly _id = new LanguageIdentifier('indentRulesMode', 4);
			constructor() {
				super(CppMode._id);
				this._register(LanguageConfigurationRegistry.register(this.getLanguageIdentifier(), {
					brackets: [
						['{', '}'],
						['[', ']'],
						['(', ')']
					],
					indentationRules: {
						increaseIndentPattern: new RegExp('^.*\\{[^}\"\\\']*$|^.*\\([^\\)\"\\\']*$|^\\s*(public|private|protected):\\s*$|^\\s*@(public|private|protected)\\s*$|^\\s*\\{\\}$'),
						decreaseIndentPattern: new RegExp('^\\s*(\\s*/[*].*[*]/\\s*)*\\}|^\\s*(\\s*/[*].*[*]/\\s*)*\\)|^\\s*(public|private|protected):\\s*$|^\\s*@(public|private|protected)\\s*$'),
					}
				}));
			}
		}

		let mode = new CppMode();
		let model = createTextModel(
			[
				'int main() {',
				'  return 0;',
				'}',
				'',
				'bool Foo::bar(const string &a,',
				'              const string &b) {',
				'  foo();',
				'',
				')',
			].join('\n'),
			{ tabSize: 2 },
			mode.getLanguageIdentifier()
		);

		withTestCodeEditor(null, { model: model, autoIndent: false }, (editor, cursor) => {
			moveTo(cursor, 8, 1, false);
			assertCursor(cursor, new Selection(8, 1, 8, 1));

			CoreEditingCommands.Tab.runEditorCommand(null, editor, null);
			assert.equal(model.getValue(),
				[
					'int main() {',
					'  return 0;',
					'}',
					'',
					'bool Foo::bar(const string &a,',
					'              const string &b) {',
					'  foo();',
					'  ',
					')',
				].join('\n')
			);
			assert.deepEqual(cursor.getSelection(), new Selection(8, 3, 8, 3));
		});

		model.dispose();
		mode.dispose();
	});
});

interface ICursorOpts {
	text: string[];
	languageIdentifier?: LanguageIdentifier;
	modelOpts?: IRelaxedTextModelCreationOptions;
	editorOpts?: IEditorOptions;
}

function usingCursor(opts: ICursorOpts, callback: (model: TextModel, cursor: Cursor) => void): void {
	let model = createTextModel(opts.text.join('\n'), opts.modelOpts, opts.languageIdentifier);
	model.forceTokenization(model.getLineCount());
	let config = new TestConfiguration(opts.editorOpts);
	let viewModel = new ViewModel(0, config, model, null);
	let cursor = new Cursor(config, model, viewModel);

	callback(model, cursor);

	cursor.dispose();
	viewModel.dispose();
	config.dispose();
	model.dispose();
}

class ElectricCharMode extends MockMode {

	private static readonly _id = new LanguageIdentifier('electricCharMode', 3);

	constructor() {
		super(ElectricCharMode._id);
		this._register(LanguageConfigurationRegistry.register(this.getLanguageIdentifier(), {
			__electricCharacterSupport: {
				docComment: { open: '/**', close: ' */' }
			},
			brackets: [
				['{', '}'],
				['[', ']'],
				['(', ')']
			]
		}));
	}
}

suite('ElectricCharacter', () => {
	test('does nothing if no electric char', () => {
		let mode = new ElectricCharMode();
		usingCursor({
			text: [
				'  if (a) {',
				''
			],
			languageIdentifier: mode.getLanguageIdentifier()
		}, (model, cursor) => {
			moveTo(cursor, 2, 1);
			cursorCommand(cursor, H.Type, { text: '*' }, 'keyboard');
			assert.deepEqual(model.getLineContent(2), '*');
		});
		mode.dispose();
	});

	test('indents in order to match bracket', () => {
		let mode = new ElectricCharMode();
		usingCursor({
			text: [
				'  if (a) {',
				''
			],
			languageIdentifier: mode.getLanguageIdentifier()
		}, (model, cursor) => {
			moveTo(cursor, 2, 1);
			cursorCommand(cursor, H.Type, { text: '}' }, 'keyboard');
			assert.deepEqual(model.getLineContent(2), '  }');
		});
		mode.dispose();
	});

	test('unindents in order to match bracket', () => {
		let mode = new ElectricCharMode();
		usingCursor({
			text: [
				'  if (a) {',
				'    '
			],
			languageIdentifier: mode.getLanguageIdentifier()
		}, (model, cursor) => {
			moveTo(cursor, 2, 5);
			cursorCommand(cursor, H.Type, { text: '}' }, 'keyboard');
			assert.deepEqual(model.getLineContent(2), '  }');
		});
		mode.dispose();
	});

	test('matches with correct bracket', () => {
		let mode = new ElectricCharMode();
		usingCursor({
			text: [
				'  if (a) {',
				'    if (b) {',
				'    }',
				'    '
			],
			languageIdentifier: mode.getLanguageIdentifier()
		}, (model, cursor) => {
			moveTo(cursor, 4, 1);
			cursorCommand(cursor, H.Type, { text: '}' }, 'keyboard');
			assert.deepEqual(model.getLineContent(4), '  }    ');
		});
		mode.dispose();
	});

	test('does nothing if bracket does not match', () => {
		let mode = new ElectricCharMode();
		usingCursor({
			text: [
				'  if (a) {',
				'    if (b) {',
				'    }',
				'  }  '
			],
			languageIdentifier: mode.getLanguageIdentifier()
		}, (model, cursor) => {
			moveTo(cursor, 4, 6);
			cursorCommand(cursor, H.Type, { text: '}' }, 'keyboard');
			assert.deepEqual(model.getLineContent(4), '  }  }');
		});
		mode.dispose();
	});

	test('matches bracket even in line with content', () => {
		let mode = new ElectricCharMode();
		usingCursor({
			text: [
				'  if (a) {',
				'// hello'
			],
			languageIdentifier: mode.getLanguageIdentifier()
		}, (model, cursor) => {
			moveTo(cursor, 2, 1);
			cursorCommand(cursor, H.Type, { text: '}' }, 'keyboard');
			assert.deepEqual(model.getLineContent(2), '  }// hello');
		});
		mode.dispose();
	});

	test('is no-op if bracket is lined up', () => {
		let mode = new ElectricCharMode();
		usingCursor({
			text: [
				'  if (a) {',
				'  '
			],
			languageIdentifier: mode.getLanguageIdentifier()
		}, (model, cursor) => {
			moveTo(cursor, 2, 3);
			cursorCommand(cursor, H.Type, { text: '}' }, 'keyboard');
			assert.deepEqual(model.getLineContent(2), '  }');
		});
		mode.dispose();
	});

	test('is no-op if there is non-whitespace text before', () => {
		let mode = new ElectricCharMode();
		usingCursor({
			text: [
				'  if (a) {',
				'a'
			],
			languageIdentifier: mode.getLanguageIdentifier()
		}, (model, cursor) => {
			moveTo(cursor, 2, 2);
			cursorCommand(cursor, H.Type, { text: '}' }, 'keyboard');
			assert.deepEqual(model.getLineContent(2), 'a}');
		});
		mode.dispose();
	});

	test('is no-op if pairs are all matched before', () => {
		let mode = new ElectricCharMode();
		usingCursor({
			text: [
				'foo(() => {',
				'  ( 1 + 2 ) ',
				'})'
			],
			languageIdentifier: mode.getLanguageIdentifier()
		}, (model, cursor) => {
			moveTo(cursor, 2, 13);
			cursorCommand(cursor, H.Type, { text: '*' }, 'keyboard');
			assert.deepEqual(model.getLineContent(2), '  ( 1 + 2 ) *');
		});
		mode.dispose();
	});

	test('is no-op if matching bracket is on the same line', () => {
		let mode = new ElectricCharMode();
		usingCursor({
			text: [
				'(div',
			],
			languageIdentifier: mode.getLanguageIdentifier()
		}, (model, cursor) => {
			moveTo(cursor, 1, 5);
			let changeText: string | null = null;
			model.onDidChangeContent(e => {
				changeText = e.changes[0].text;
			});
			cursorCommand(cursor, H.Type, { text: ')' }, 'keyboard');
			assert.deepEqual(model.getLineContent(1), '(div)');
			assert.deepEqual(changeText, ')');
		});
		mode.dispose();
	});

	test('is no-op if the line has other content', () => {
		let mode = new ElectricCharMode();
		usingCursor({
			text: [
				'Math.max(',
				'\t2',
				'\t3'
			],
			languageIdentifier: mode.getLanguageIdentifier()
		}, (model, cursor) => {
			moveTo(cursor, 3, 3);
			cursorCommand(cursor, H.Type, { text: ')' }, 'keyboard');
			assert.deepEqual(model.getLineContent(3), '\t3)');
		});
		mode.dispose();
	});

	test('appends text', () => {
		let mode = new ElectricCharMode();
		usingCursor({
			text: [
				'  if (a) {',
				'/*'
			],
			languageIdentifier: mode.getLanguageIdentifier()
		}, (model, cursor) => {
			moveTo(cursor, 2, 3);
			cursorCommand(cursor, H.Type, { text: '*' }, 'keyboard');
			assert.deepEqual(model.getLineContent(2), '/** */');
		});
		mode.dispose();
	});

	test('appends text 2', () => {
		let mode = new ElectricCharMode();
		usingCursor({
			text: [
				'  if (a) {',
				'  /*'
			],
			languageIdentifier: mode.getLanguageIdentifier()
		}, (model, cursor) => {
			moveTo(cursor, 2, 5);
			cursorCommand(cursor, H.Type, { text: '*' }, 'keyboard');
			assert.deepEqual(model.getLineContent(2), '  /** */');
		});
		mode.dispose();
	});

	test('issue #23711: Replacing selected text with )]} fails to delete old text with backwards-dragged selection', () => {
		let mode = new ElectricCharMode();
		usingCursor({
			text: [
				'{',
				'word'
			],
			languageIdentifier: mode.getLanguageIdentifier()
		}, (model, cursor) => {
			moveTo(cursor, 2, 5);
			moveTo(cursor, 2, 1, true);
			cursorCommand(cursor, H.Type, { text: '}' }, 'keyboard');
			assert.deepEqual(model.getLineContent(2), '}');
		});
		mode.dispose();
	});
});

suite('autoClosingPairs', () => {

	class AutoClosingMode extends MockMode {

		private static readonly _id = new LanguageIdentifier('autoClosingMode', 5);

		constructor() {
			super(AutoClosingMode._id);
			this._register(LanguageConfigurationRegistry.register(this.getLanguageIdentifier(), {
				autoClosingPairs: [
					{ open: '{', close: '}' },
					{ open: '[', close: ']' },
					{ open: '(', close: ')' },
					{ open: '\'', close: '\'', notIn: ['string', 'comment'] },
					{ open: '\"', close: '\"', notIn: ['string'] },
					{ open: '`', close: '`', notIn: ['string', 'comment'] },
					{ open: '/**', close: ' */', notIn: ['string'] }
				],
			}));
		}

		public setAutocloseEnabledSet(chars: string) {
			this._register(LanguageConfigurationRegistry.register(this.getLanguageIdentifier(), {
				autoCloseBefore: chars,
				autoClosingPairs: [
					{ open: '{', close: '}' },
					{ open: '[', close: ']' },
					{ open: '(', close: ')' },
					{ open: '\'', close: '\'', notIn: ['string', 'comment'] },
					{ open: '\"', close: '\"', notIn: ['string'] },
					{ open: '`', close: '`', notIn: ['string', 'comment'] },
					{ open: '/**', close: ' */', notIn: ['string'] }
				],
			}));
		}
	}

	const enum ColumnType {
		Normal = 0,
		Special1 = 1,
		Special2 = 2
	}

	function extractSpecialColumns(maxColumn: number, annotatedLine: string): ColumnType[] {
		let result: ColumnType[] = [];
		for (let j = 1; j <= maxColumn; j++) {
			result[j] = ColumnType.Normal;
		}
		let column = 1;
		for (let j = 0; j < annotatedLine.length; j++) {
			if (annotatedLine.charAt(j) === '|') {
				result[column] = ColumnType.Special1;
			} else if (annotatedLine.charAt(j) === '!') {
				result[column] = ColumnType.Special2;
			} else {
				column++;
			}
		}
		return result;
	}

	function assertType(model: TextModel, cursor: Cursor, lineNumber: number, column: number, chr: string, expectedInsert: string, message: string): void {
		let lineContent = model.getLineContent(lineNumber);
		let expected = lineContent.substr(0, column - 1) + expectedInsert + lineContent.substr(column - 1);
		moveTo(cursor, lineNumber, column);
		cursorCommand(cursor, H.Type, { text: chr }, 'keyboard');
		assert.deepEqual(model.getLineContent(lineNumber), expected, message);
		cursorCommand(cursor, H.Undo);
	}

	test('open parens: default', () => {
		let mode = new AutoClosingMode();
		usingCursor({
			text: [
				'var a = [];',
				'var b = `asd`;',
				'var c = \'asd\';',
				'var d = "asd";',
				'var e = /*3*/	3;',
				'var f = /** 3 */3;',
				'var g = (3+5);',
				'var h = { a: \'value\' };',
			],
			languageIdentifier: mode.getLanguageIdentifier()
		}, (model, cursor) => {

			let autoClosePositions = [
				'var| a| |=| [|]|;|',
				'var| b| |=| `asd`|;|',
				'var| c| |=| \'asd\'|;|',
				'var| d| |=| "asd"|;|',
				'var| e| |=| /*3*/|	3|;|',
				'var| f| |=| /**| 3| */3|;|',
				'var| g| |=| (3+5|)|;|',
				'var| h| |=| {| a|:| \'value\'| |}|;|',
			];
			for (let i = 0, len = autoClosePositions.length; i < len; i++) {
				const lineNumber = i + 1;
				const autoCloseColumns = extractSpecialColumns(model.getLineMaxColumn(lineNumber), autoClosePositions[i]);

				for (let column = 1; column < autoCloseColumns.length; column++) {
					model.forceTokenization(lineNumber);
					if (autoCloseColumns[column] === ColumnType.Special1) {
						assertType(model, cursor, lineNumber, column, '(', '()', `auto closes @ (${lineNumber}, ${column})`);
					} else {
						assertType(model, cursor, lineNumber, column, '(', '(', `does not auto close @ (${lineNumber}, ${column})`);
					}
				}
			}
		});
		mode.dispose();
	});

	test('open parens: whitespace', () => {
		let mode = new AutoClosingMode();
		usingCursor({
			text: [
				'var a = [];',
				'var b = `asd`;',
				'var c = \'asd\';',
				'var d = "asd";',
				'var e = /*3*/	3;',
				'var f = /** 3 */3;',
				'var g = (3+5);',
				'var h = { a: \'value\' };',
			],
			languageIdentifier: mode.getLanguageIdentifier(),
			editorOpts: {
				autoClosingBrackets: 'beforeWhitespace'
			}
		}, (model, cursor) => {

			let autoClosePositions = [
				'var| a| =| [|];|',
				'var| b| =| `asd`;|',
				'var| c| =| \'asd\';|',
				'var| d| =| "asd";|',
				'var| e| =| /*3*/|	3;|',
				'var| f| =| /**| 3| */3;|',
				'var| g| =| (3+5|);|',
				'var| h| =| {| a:| \'value\'| |};|',
			];
			for (let i = 0, len = autoClosePositions.length; i < len; i++) {
				const lineNumber = i + 1;
				const autoCloseColumns = extractSpecialColumns(model.getLineMaxColumn(lineNumber), autoClosePositions[i]);

				for (let column = 1; column < autoCloseColumns.length; column++) {
					model.forceTokenization(lineNumber);
					if (autoCloseColumns[column] === ColumnType.Special1) {
						assertType(model, cursor, lineNumber, column, '(', '()', `auto closes @ (${lineNumber}, ${column})`);
					} else {
						assertType(model, cursor, lineNumber, column, '(', '(', `does not auto close @ (${lineNumber}, ${column})`);
					}
				}
			}
		});
		mode.dispose();
	});

	test('open parens disabled/enabled open quotes enabled/disabled', () => {
		let mode = new AutoClosingMode();
		usingCursor({
			text: [
				'var a = [];',
			],
			languageIdentifier: mode.getLanguageIdentifier(),
			editorOpts: {
				autoClosingBrackets: 'beforeWhitespace',
				autoClosingQuotes: 'never'
			}
		}, (model, cursor) => {

			let autoClosePositions = [
				'var| a| =| [|];|',
			];
			for (let i = 0, len = autoClosePositions.length; i < len; i++) {
				const lineNumber = i + 1;
				const autoCloseColumns = extractSpecialColumns(model.getLineMaxColumn(lineNumber), autoClosePositions[i]);

				for (let column = 1; column < autoCloseColumns.length; column++) {
					model.forceTokenization(lineNumber);
					if (autoCloseColumns[column] === ColumnType.Special1) {
						assertType(model, cursor, lineNumber, column, '(', '()', `auto closes @ (${lineNumber}, ${column})`);
					} else {
						assertType(model, cursor, lineNumber, column, '(', '(', `does not auto close @ (${lineNumber}, ${column})`);
					}
					assertType(model, cursor, lineNumber, column, '\'', '\'', `does not auto close @ (${lineNumber}, ${column})`);
				}
			}
		});

		usingCursor({
			text: [
				'var b = [];',
			],
			languageIdentifier: mode.getLanguageIdentifier(),
			editorOpts: {
				autoClosingBrackets: 'never',
				autoClosingQuotes: 'beforeWhitespace'
			}
		}, (model, cursor) => {

			let autoClosePositions = [
				'var b =| [|];|',
			];
			for (let i = 0, len = autoClosePositions.length; i < len; i++) {
				const lineNumber = i + 1;
				const autoCloseColumns = extractSpecialColumns(model.getLineMaxColumn(lineNumber), autoClosePositions[i]);

				for (let column = 1; column < autoCloseColumns.length; column++) {
					model.forceTokenization(lineNumber);
					if (autoCloseColumns[column] === ColumnType.Special1) {
						assertType(model, cursor, lineNumber, column, '\'', '\'\'', `auto closes @ (${lineNumber}, ${column})`);
					} else {
						assertType(model, cursor, lineNumber, column, '\'', '\'', `does not auto close @ (${lineNumber}, ${column})`);
					}
					assertType(model, cursor, lineNumber, column, '(', '(', `does not auto close @ (${lineNumber}, ${column})`);
				}
			}
		});
		mode.dispose();
	});

	test('configurable open parens', () => {
		let mode = new AutoClosingMode();
		mode.setAutocloseEnabledSet('abc');
		usingCursor({
			text: [
				'var a = [];',
				'var b = `asd`;',
				'var c = \'asd\';',
				'var d = "asd";',
				'var e = /*3*/	3;',
				'var f = /** 3 */3;',
				'var g = (3+5);',
				'var h = { a: \'value\' };',
			],
			languageIdentifier: mode.getLanguageIdentifier(),
			editorOpts: {
				autoClosingBrackets: 'languageDefined'
			}
		}, (model, cursor) => {

			let autoClosePositions = [
				'v|ar |a = [|];|',
				'v|ar |b = `|asd`;|',
				'v|ar |c = \'|asd\';|',
				'v|ar d = "|asd";|',
				'v|ar e = /*3*/	3;|',
				'v|ar f = /** 3 */3;|',
				'v|ar g = (3+5|);|',
				'v|ar h = { |a: \'v|alue\' |};|',
			];
			for (let i = 0, len = autoClosePositions.length; i < len; i++) {
				const lineNumber = i + 1;
				const autoCloseColumns = extractSpecialColumns(model.getLineMaxColumn(lineNumber), autoClosePositions[i]);

				for (let column = 1; column < autoCloseColumns.length; column++) {
					model.forceTokenization(lineNumber);
					if (autoCloseColumns[column] === ColumnType.Special1) {
						assertType(model, cursor, lineNumber, column, '(', '()', `auto closes @ (${lineNumber}, ${column})`);
					} else {
						assertType(model, cursor, lineNumber, column, '(', '(', `does not auto close @ (${lineNumber}, ${column})`);
					}
				}
			}
		});
		mode.dispose();
	});

	test('auto-pairing can be disabled', () => {
		let mode = new AutoClosingMode();
		usingCursor({
			text: [
				'var a = [];',
				'var b = `asd`;',
				'var c = \'asd\';',
				'var d = "asd";',
				'var e = /*3*/	3;',
				'var f = /** 3 */3;',
				'var g = (3+5);',
				'var h = { a: \'value\' };',
			],
			languageIdentifier: mode.getLanguageIdentifier(),
			editorOpts: {
				autoClosingBrackets: 'never',
				autoClosingQuotes: 'never'
			}
		}, (model, cursor) => {

			let autoClosePositions = [
				'var a = [];',
				'var b = `asd`;',
				'var c = \'asd\';',
				'var d = "asd";',
				'var e = /*3*/	3;',
				'var f = /** 3 */3;',
				'var g = (3+5);',
				'var h = { a: \'value\' };',
			];
			for (let i = 0, len = autoClosePositions.length; i < len; i++) {
				const lineNumber = i + 1;
				const autoCloseColumns = extractSpecialColumns(model.getLineMaxColumn(lineNumber), autoClosePositions[i]);

				for (let column = 1; column < autoCloseColumns.length; column++) {
					model.forceTokenization(lineNumber);
					if (autoCloseColumns[column] === ColumnType.Special1) {
						assertType(model, cursor, lineNumber, column, '(', '()', `auto closes @ (${lineNumber}, ${column})`);
						assertType(model, cursor, lineNumber, column, '"', '""', `auto closes @ (${lineNumber}, ${column})`);
					} else {
						assertType(model, cursor, lineNumber, column, '(', '(', `does not auto close @ (${lineNumber}, ${column})`);
						assertType(model, cursor, lineNumber, column, '"', '"', `does not auto close @ (${lineNumber}, ${column})`);
					}
				}
			}
		});
		mode.dispose();
	});

	test('auto wrapping is configurable', () => {
		let mode = new AutoClosingMode();
		usingCursor({
			text: [
				'var a = asd'
			],
			languageIdentifier: mode.getLanguageIdentifier()
		}, (model, cursor) => {

			cursor.setSelections('test', [
				new Selection(1, 1, 1, 4),
				new Selection(1, 9, 1, 12),
			]);

			// type a `
			cursorCommand(cursor, H.Type, { text: '`' }, 'keyboard');

			assert.equal(model.getValue(), '`var` a = `asd`');

			// type a (
			cursorCommand(cursor, H.Type, { text: '(' }, 'keyboard');

			assert.equal(model.getValue(), '`(var)` a = `(asd)`');
		});

		usingCursor({
			text: [
				'var a = asd'
			],
			languageIdentifier: mode.getLanguageIdentifier(),
			editorOpts: {
				autoSurround: 'never'
			}
		}, (model, cursor) => {

			cursor.setSelections('test', [
				new Selection(1, 1, 1, 4),
			]);

			// type a `
			cursorCommand(cursor, H.Type, { text: '`' }, 'keyboard');

			assert.equal(model.getValue(), '` a = asd');
		});

		usingCursor({
			text: [
				'var a = asd'
			],
			languageIdentifier: mode.getLanguageIdentifier(),
			editorOpts: {
				autoSurround: 'quotes'
			}
		}, (model, cursor) => {

			cursor.setSelections('test', [
				new Selection(1, 1, 1, 4),
			]);

			// type a `
			cursorCommand(cursor, H.Type, { text: '`' }, 'keyboard');
			assert.equal(model.getValue(), '`var` a = asd');

			// type a (
			cursorCommand(cursor, H.Type, { text: '(' }, 'keyboard');
			assert.equal(model.getValue(), '`(` a = asd');
		});

		usingCursor({
			text: [
				'var a = asd'
			],
			languageIdentifier: mode.getLanguageIdentifier(),
			editorOpts: {
				autoSurround: 'brackets'
			}
		}, (model, cursor) => {

			cursor.setSelections('test', [
				new Selection(1, 1, 1, 4),
			]);

			// type a (
			cursorCommand(cursor, H.Type, { text: '(' }, 'keyboard');
			assert.equal(model.getValue(), '(var) a = asd');

			// type a `
			cursorCommand(cursor, H.Type, { text: '`' }, 'keyboard');
			assert.equal(model.getValue(), '(`) a = asd');
		});
		mode.dispose();
	});

	test('quote', () => {
		let mode = new AutoClosingMode();
		usingCursor({
			text: [
				'var a = [];',
				'var b = `asd`;',
				'var c = \'asd\';',
				'var d = "asd";',
				'var e = /*3*/	3;',
				'var f = /** 3 */3;',
				'var g = (3+5);',
				'var h = { a: \'value\' };',
			],
			languageIdentifier: mode.getLanguageIdentifier()
		}, (model, cursor) => {

			let autoClosePositions = [
				'var a |=| [|]|;|',
				'var b |=| |`asd`|;|',
				'var c |=| |\'asd!\'|;|',
				'var d |=| |"asd"|;|',
				'var e |=| /*3*/|	3;|',
				'var f |=| /**| 3 */3;|',
				'var g |=| (3+5)|;|',
				'var h |=| {| a:| |\'value!\'| |}|;|',
			];
			for (let i = 0, len = autoClosePositions.length; i < len; i++) {
				const lineNumber = i + 1;
				const autoCloseColumns = extractSpecialColumns(model.getLineMaxColumn(lineNumber), autoClosePositions[i]);

				for (let column = 1; column < autoCloseColumns.length; column++) {
					model.forceTokenization(lineNumber);
					if (autoCloseColumns[column] === ColumnType.Special1) {
						assertType(model, cursor, lineNumber, column, '\'', '\'\'', `auto closes @ (${lineNumber}, ${column})`);
					} else if (autoCloseColumns[column] === ColumnType.Special2) {
						assertType(model, cursor, lineNumber, column, '\'', '', `over types @ (${lineNumber}, ${column})`);
					} else {
						assertType(model, cursor, lineNumber, column, '\'', '\'', `does not auto close @ (${lineNumber}, ${column})`);
					}
				}
			}
		});
		mode.dispose();
	});

	test('issue #55314: Do not auto-close when ending with open', () => {
		const languageId = new LanguageIdentifier('myElectricMode', 5);
		class ElectricMode extends MockMode {
			constructor() {
				super(languageId);
				this._register(LanguageConfigurationRegistry.register(this.getLanguageIdentifier(), {
					autoClosingPairs: [
						{ open: '{', close: '}' },
						{ open: '[', close: ']' },
						{ open: '(', close: ')' },
						{ open: '\'', close: '\'', notIn: ['string', 'comment'] },
						{ open: '\"', close: '\"', notIn: ['string'] },
						{ open: 'B\"', close: '\"', notIn: ['string', 'comment'] },
						{ open: '`', close: '`', notIn: ['string', 'comment'] },
						{ open: '/**', close: ' */', notIn: ['string'] }
					],
				}));
			}
		}

		const mode = new ElectricMode();

		usingCursor({
			text: [
				'little goat',
				'little LAMB',
				'little sheep',
				'Big LAMB'
			],
			languageIdentifier: mode.getLanguageIdentifier()
		}, (model, cursor) => {
			model.forceTokenization(model.getLineCount());
			assertType(model, cursor, 1, 4, '"', '"', `does not double quote when ending with open`);
			model.forceTokenization(model.getLineCount());
			assertType(model, cursor, 2, 4, '"', '"', `does not double quote when ending with open`);
			model.forceTokenization(model.getLineCount());
			assertType(model, cursor, 3, 4, '"', '"', `does not double quote when ending with open`);
			model.forceTokenization(model.getLineCount());
			assertType(model, cursor, 4, 2, '"', '""', `double quote when ending with open`);
			model.forceTokenization(model.getLineCount());
			assertType(model, cursor, 4, 3, '"', '"', `does not double quote when ending with open`);
		});
		mode.dispose();
	});

	test('issue #27937: Trying to add an item to the front of a list is cumbersome', () => {
		let mode = new AutoClosingMode();
		usingCursor({
			text: [
				'var arr = ["b", "c"];'
			],
			languageIdentifier: mode.getLanguageIdentifier()
		}, (model, cursor) => {
			assertType(model, cursor, 1, 12, '"', '""', `does not over type and will auto close`);
		});
		mode.dispose();
	});

	test('issue #25658 - Do not auto-close single/double quotes after word characters', () => {
		let mode = new AutoClosingMode();
		usingCursor({
			text: [
				'',
			],
			languageIdentifier: mode.getLanguageIdentifier()
		}, (model, cursor) => {

			function typeCharacters(cursor: Cursor, chars: string): void {
				for (let i = 0, len = chars.length; i < len; i++) {
					cursorCommand(cursor, H.Type, { text: chars[i] }, 'keyboard');
				}
			}

			// First gif
			model.forceTokenization(model.getLineCount());
			typeCharacters(cursor, 'teste1 = teste\' ok');
			assert.equal(model.getLineContent(1), 'teste1 = teste\' ok');

			cursor.setSelections('test', [new Selection(1, 1000, 1, 1000)]);
			typeCharacters(cursor, '\n');
			model.forceTokenization(model.getLineCount());
			typeCharacters(cursor, 'teste2 = teste \'ok');
			assert.equal(model.getLineContent(2), 'teste2 = teste \'ok\'');

			cursor.setSelections('test', [new Selection(2, 1000, 2, 1000)]);
			typeCharacters(cursor, '\n');
			model.forceTokenization(model.getLineCount());
			typeCharacters(cursor, 'teste3 = teste" ok');
			assert.equal(model.getLineContent(3), 'teste3 = teste" ok');

			cursor.setSelections('test', [new Selection(3, 1000, 3, 1000)]);
			typeCharacters(cursor, '\n');
			model.forceTokenization(model.getLineCount());
			typeCharacters(cursor, 'teste4 = teste "ok');
			assert.equal(model.getLineContent(4), 'teste4 = teste "ok"');

			// Second gif
			cursor.setSelections('test', [new Selection(4, 1000, 4, 1000)]);
			typeCharacters(cursor, '\n');
			model.forceTokenization(model.getLineCount());
			typeCharacters(cursor, 'teste \'');
			assert.equal(model.getLineContent(5), 'teste \'\'');

			cursor.setSelections('test', [new Selection(5, 1000, 5, 1000)]);
			typeCharacters(cursor, '\n');
			model.forceTokenization(model.getLineCount());
			typeCharacters(cursor, 'teste "');
			assert.equal(model.getLineContent(6), 'teste ""');

			cursor.setSelections('test', [new Selection(6, 1000, 6, 1000)]);
			typeCharacters(cursor, '\n');
			model.forceTokenization(model.getLineCount());
			typeCharacters(cursor, 'teste\'');
			assert.equal(model.getLineContent(7), 'teste\'');

			cursor.setSelections('test', [new Selection(7, 1000, 7, 1000)]);
			typeCharacters(cursor, '\n');
			model.forceTokenization(model.getLineCount());
			typeCharacters(cursor, 'teste"');
			assert.equal(model.getLineContent(8), 'teste"');
		});
		mode.dispose();
	});

	test('issue #15825: accents on mac US intl keyboard', () => {
		let mode = new AutoClosingMode();
		usingCursor({
			text: [
			],
			languageIdentifier: mode.getLanguageIdentifier()
		}, (model, cursor) => {
			assertCursor(cursor, new Position(1, 1));

			// Typing ` + e on the mac US intl kb layout
			cursorCommand(cursor, H.CompositionStart, null, 'keyboard');
			cursorCommand(cursor, H.Type, { text: '`' }, 'keyboard');
			cursorCommand(cursor, H.ReplacePreviousChar, { replaceCharCnt: 1, text: 'è' }, 'keyboard');
			cursorCommand(cursor, H.CompositionEnd, null, 'keyboard');

			assert.equal(model.getValue(), 'è');
		});
		mode.dispose();
	});

	test('issue #2773: Accents (´`¨^, others?) are inserted in the wrong position (Mac)', () => {
		let mode = new AutoClosingMode();
		usingCursor({
			text: [
				'hello',
				'world'
			],
			languageIdentifier: mode.getLanguageIdentifier()
		}, (model, cursor) => {
			assertCursor(cursor, new Position(1, 1));

			// Typing ` and pressing shift+down on the mac US intl kb layout
			// Here we're just replaying what the cursor gets
			cursorCommand(cursor, H.CompositionStart, null, 'keyboard');
			cursorCommand(cursor, H.Type, { text: '`' }, 'keyboard');
			moveDown(cursor, true);
			cursorCommand(cursor, H.ReplacePreviousChar, { replaceCharCnt: 1, text: '`' }, 'keyboard');
			cursorCommand(cursor, H.ReplacePreviousChar, { replaceCharCnt: 1, text: '`' }, 'keyboard');
			cursorCommand(cursor, H.CompositionEnd, null, 'keyboard');

			assert.equal(model.getValue(), '`hello\nworld');
			assertCursor(cursor, new Selection(1, 2, 2, 2));
		});
		mode.dispose();
	});

	test('issue #26820: auto close quotes when not used as accents', () => {
		let mode = new AutoClosingMode();
		usingCursor({
			text: [
				''
			],
			languageIdentifier: mode.getLanguageIdentifier()
		}, (model, cursor) => {
			assertCursor(cursor, new Position(1, 1));

			// on the mac US intl kb layout

			// Typing ` + space
			cursorCommand(cursor, H.CompositionStart, null, 'keyboard');
			cursorCommand(cursor, H.Type, { text: '\'' }, 'keyboard');
			cursorCommand(cursor, H.ReplacePreviousChar, { replaceCharCnt: 1, text: '\'' }, 'keyboard');
			cursorCommand(cursor, H.CompositionEnd, null, 'keyboard');

			assert.equal(model.getValue(), '\'\'');

			// Typing " + space within string
			cursor.setSelections('test', [new Selection(1, 2, 1, 2)]);
			cursorCommand(cursor, H.CompositionStart, null, 'keyboard');
			cursorCommand(cursor, H.Type, { text: '"' }, 'keyboard');
			cursorCommand(cursor, H.ReplacePreviousChar, { replaceCharCnt: 1, text: '"' }, 'keyboard');
			cursorCommand(cursor, H.CompositionEnd, null, 'keyboard');

			assert.equal(model.getValue(), '\'"\'');

			// Typing ' + space after '
			model.setValue('\'');
			cursor.setSelections('test', [new Selection(1, 2, 1, 2)]);
			cursorCommand(cursor, H.CompositionStart, null, 'keyboard');
			cursorCommand(cursor, H.Type, { text: '\'' }, 'keyboard');
			cursorCommand(cursor, H.ReplacePreviousChar, { replaceCharCnt: 1, text: '\'' }, 'keyboard');
			cursorCommand(cursor, H.CompositionEnd, null, 'keyboard');

			assert.equal(model.getValue(), '\'\'');

			// Typing ' as a closing tag
			model.setValue('\'abc');
			cursor.setSelections('test', [new Selection(1, 5, 1, 5)]);
			cursorCommand(cursor, H.CompositionStart, null, 'keyboard');
			cursorCommand(cursor, H.Type, { text: '\'' }, 'keyboard');
			cursorCommand(cursor, H.ReplacePreviousChar, { replaceCharCnt: 1, text: '\'' }, 'keyboard');
			cursorCommand(cursor, H.CompositionEnd, null, 'keyboard');

			assert.equal(model.getValue(), '\'abc\'');

			// quotes before the newly added character are all paired.
			model.setValue('\'abc\'def ');
			cursor.setSelections('test', [new Selection(1, 10, 1, 10)]);
			cursorCommand(cursor, H.CompositionStart, null, 'keyboard');
			cursorCommand(cursor, H.Type, { text: '\'' }, 'keyboard');
			cursorCommand(cursor, H.ReplacePreviousChar, { replaceCharCnt: 1, text: '\'' }, 'keyboard');
			cursorCommand(cursor, H.CompositionEnd, null, 'keyboard');

			assert.equal(model.getValue(), '\'abc\'def \'\'');

			// No auto closing if there is non-whitespace character after the cursor
			model.setValue('abc');
			cursor.setSelections('test', [new Selection(1, 1, 1, 1)]);
			cursorCommand(cursor, H.CompositionStart, null, 'keyboard');
			cursorCommand(cursor, H.Type, { text: '\'' }, 'keyboard');
			cursorCommand(cursor, H.ReplacePreviousChar, { replaceCharCnt: 1, text: '\'' }, 'keyboard');
			cursorCommand(cursor, H.CompositionEnd, null, 'keyboard');

			// No auto closing if it's after a word.
			model.setValue('abc');
			cursor.setSelections('test', [new Selection(1, 4, 1, 4)]);
			cursorCommand(cursor, H.CompositionStart, null, 'keyboard');
			cursorCommand(cursor, H.Type, { text: '\'' }, 'keyboard');
			cursorCommand(cursor, H.ReplacePreviousChar, { replaceCharCnt: 1, text: '\'' }, 'keyboard');
			cursorCommand(cursor, H.CompositionEnd, null, 'keyboard');

			assert.equal(model.getValue(), 'abc\'');
		});
		mode.dispose();
	});

	test('issue #20891: All cursors should do the same thing', () => {
		let mode = new AutoClosingMode();
		usingCursor({
			text: [
				'var a = asd'
			],
			languageIdentifier: mode.getLanguageIdentifier()
		}, (model, cursor) => {

			cursor.setSelections('test', [
				new Selection(1, 9, 1, 9),
				new Selection(1, 12, 1, 12),
			]);

			// type a `
			cursorCommand(cursor, H.Type, { text: '`' }, 'keyboard');

			assert.equal(model.getValue(), 'var a = `asd`');
		});
		mode.dispose();
	});

	test('issue #41825: Special handling of quotes in surrounding pairs', () => {
		const languageId = new LanguageIdentifier('myMode', 3);
		class MyMode extends MockMode {
			constructor() {
				super(languageId);
				this._register(LanguageConfigurationRegistry.register(this.getLanguageIdentifier(), {
					surroundingPairs: [
						{ open: '"', close: '"' },
						{ open: '\'', close: '\'' },
					]
				}));
			}
		}

		const mode = new MyMode();
		const model = createTextModel('var x = \'hi\';', undefined, languageId);

		withTestCodeEditor(null, { model: model }, (editor, cursor) => {
			editor.setSelections([
				new Selection(1, 9, 1, 10),
				new Selection(1, 12, 1, 13)
			]);
			cursorCommand(cursor, H.Type, { text: '"' }, 'keyboard');
			assert.equal(model.getValue(EndOfLinePreference.LF), 'var x = "hi";', 'assert1');

			editor.setSelections([
				new Selection(1, 9, 1, 10),
				new Selection(1, 12, 1, 13)
			]);
			cursorCommand(cursor, H.Type, { text: '\'' }, 'keyboard');
			assert.equal(model.getValue(EndOfLinePreference.LF), 'var x = \'hi\';', 'assert2');
		});

		model.dispose();
		mode.dispose();
	});

	test('All cursors should do the same thing when deleting left', () => {
		let mode = new AutoClosingMode();
		let model = createTextModel(
			[
				'var a = ()'
			].join('\n'),
			TextModel.DEFAULT_CREATION_OPTIONS,
			mode.getLanguageIdentifier()
		);

		withTestCodeEditor(null, { model: model }, (editor, cursor) => {
			cursor.setSelections('test', [
				new Selection(1, 4, 1, 4),
				new Selection(1, 10, 1, 10),
			]);

			// delete left
			CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);

			assert.equal(model.getValue(), 'va a = )');
		});
		model.dispose();
		mode.dispose();
	});

	test('issue #7100: Mouse word selection is strange when non-word character is at the end of line', () => {
		let model = createTextModel(
			[
				'before.a',
				'before',
				'hello:',
				'there:',
				'this is strange:',
				'here',
				'it',
				'is',
			].join('\n')
		);

		withTestCodeEditor(null, { model: model }, (editor, cursor) => {
			CoreNavigationCommands.WordSelect.runEditorCommand(null, editor, {
				position: new Position(3, 7)
			});
			assertCursor(cursor, new Selection(3, 7, 3, 7));

			CoreNavigationCommands.WordSelectDrag.runEditorCommand(null, editor, {
				position: new Position(4, 7)
			});
			assertCursor(cursor, new Selection(3, 7, 4, 7));
		});
	});
});

suite('Undo stops', () => {

	test('there is an undo stop between typing and deleting left', () => {
		let model = createTextModel(
			[
				'A  line',
				'Another line',
			].join('\n')
		);

		withTestCodeEditor(null, { model: model }, (editor, cursor) => {
			cursor.setSelections('test', [new Selection(1, 3, 1, 3)]);
			cursorCommand(cursor, H.Type, { text: 'first' }, 'keyboard');
			assert.equal(model.getLineContent(1), 'A first line');
			assertCursor(cursor, new Selection(1, 8, 1, 8));

			CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
			CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
			assert.equal(model.getLineContent(1), 'A fir line');
			assertCursor(cursor, new Selection(1, 6, 1, 6));

			cursorCommand(cursor, H.Undo, {});
			assert.equal(model.getLineContent(1), 'A first line');
			assertCursor(cursor, new Selection(1, 8, 1, 8));

			cursorCommand(cursor, H.Undo, {});
			assert.equal(model.getLineContent(1), 'A  line');
			assertCursor(cursor, new Selection(1, 3, 1, 3));
		});
	});

	test('there is an undo stop between typing and deleting right', () => {
		let model = createTextModel(
			[
				'A  line',
				'Another line',
			].join('\n')
		);

		withTestCodeEditor(null, { model: model }, (editor, cursor) => {
			cursor.setSelections('test', [new Selection(1, 3, 1, 3)]);
			cursorCommand(cursor, H.Type, { text: 'first' }, 'keyboard');
			assert.equal(model.getLineContent(1), 'A first line');
			assertCursor(cursor, new Selection(1, 8, 1, 8));

			CoreEditingCommands.DeleteRight.runEditorCommand(null, editor, null);
			CoreEditingCommands.DeleteRight.runEditorCommand(null, editor, null);
			assert.equal(model.getLineContent(1), 'A firstine');
			assertCursor(cursor, new Selection(1, 8, 1, 8));

			cursorCommand(cursor, H.Undo, {});
			assert.equal(model.getLineContent(1), 'A first line');
			assertCursor(cursor, new Selection(1, 8, 1, 8));

			cursorCommand(cursor, H.Undo, {});
			assert.equal(model.getLineContent(1), 'A  line');
			assertCursor(cursor, new Selection(1, 3, 1, 3));
		});
	});

	test('there is an undo stop between deleting left and typing', () => {
		let model = createTextModel(
			[
				'A  line',
				'Another line',
			].join('\n')
		);

		withTestCodeEditor(null, { model: model }, (editor, cursor) => {
			cursor.setSelections('test', [new Selection(2, 8, 2, 8)]);
			CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
			CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
			CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
			CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
			CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
			CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
			CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
			assert.equal(model.getLineContent(2), ' line');
			assertCursor(cursor, new Selection(2, 1, 2, 1));

			cursorCommand(cursor, H.Type, { text: 'Second' }, 'keyboard');
			assert.equal(model.getLineContent(2), 'Second line');
			assertCursor(cursor, new Selection(2, 7, 2, 7));

			cursorCommand(cursor, H.Undo, {});
			assert.equal(model.getLineContent(2), ' line');
			assertCursor(cursor, new Selection(2, 1, 2, 1));

			cursorCommand(cursor, H.Undo, {});
			assert.equal(model.getLineContent(2), 'Another line');
			assertCursor(cursor, new Selection(2, 8, 2, 8));
		});
	});

	test('there is an undo stop between deleting left and deleting right', () => {
		let model = createTextModel(
			[
				'A  line',
				'Another line',
			].join('\n')
		);

		withTestCodeEditor(null, { model: model }, (editor, cursor) => {
			cursor.setSelections('test', [new Selection(2, 8, 2, 8)]);
			CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
			CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
			CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
			CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
			CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
			CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
			CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
			assert.equal(model.getLineContent(2), ' line');
			assertCursor(cursor, new Selection(2, 1, 2, 1));

			CoreEditingCommands.DeleteRight.runEditorCommand(null, editor, null);
			CoreEditingCommands.DeleteRight.runEditorCommand(null, editor, null);
			CoreEditingCommands.DeleteRight.runEditorCommand(null, editor, null);
			CoreEditingCommands.DeleteRight.runEditorCommand(null, editor, null);
			CoreEditingCommands.DeleteRight.runEditorCommand(null, editor, null);
			assert.equal(model.getLineContent(2), '');
			assertCursor(cursor, new Selection(2, 1, 2, 1));

			cursorCommand(cursor, H.Undo, {});
			assert.equal(model.getLineContent(2), ' line');
			assertCursor(cursor, new Selection(2, 1, 2, 1));

			cursorCommand(cursor, H.Undo, {});
			assert.equal(model.getLineContent(2), 'Another line');
			assertCursor(cursor, new Selection(2, 8, 2, 8));
		});
	});

	test('there is an undo stop between deleting right and typing', () => {
		let model = createTextModel(
			[
				'A  line',
				'Another line',
			].join('\n')
		);

		withTestCodeEditor(null, { model: model }, (editor, cursor) => {
			cursor.setSelections('test', [new Selection(2, 9, 2, 9)]);
			CoreEditingCommands.DeleteRight.runEditorCommand(null, editor, null);
			CoreEditingCommands.DeleteRight.runEditorCommand(null, editor, null);
			CoreEditingCommands.DeleteRight.runEditorCommand(null, editor, null);
			CoreEditingCommands.DeleteRight.runEditorCommand(null, editor, null);
			assert.equal(model.getLineContent(2), 'Another ');
			assertCursor(cursor, new Selection(2, 9, 2, 9));

			cursorCommand(cursor, H.Type, { text: 'text' }, 'keyboard');
			assert.equal(model.getLineContent(2), 'Another text');
			assertCursor(cursor, new Selection(2, 13, 2, 13));

			cursorCommand(cursor, H.Undo, {});
			assert.equal(model.getLineContent(2), 'Another ');
			assertCursor(cursor, new Selection(2, 9, 2, 9));

			cursorCommand(cursor, H.Undo, {});
			assert.equal(model.getLineContent(2), 'Another line');
			assertCursor(cursor, new Selection(2, 9, 2, 9));
		});
	});

	test('there is an undo stop between deleting right and deleting left', () => {
		let model = createTextModel(
			[
				'A  line',
				'Another line',
			].join('\n')
		);

		withTestCodeEditor(null, { model: model }, (editor, cursor) => {
			cursor.setSelections('test', [new Selection(2, 9, 2, 9)]);
			CoreEditingCommands.DeleteRight.runEditorCommand(null, editor, null);
			CoreEditingCommands.DeleteRight.runEditorCommand(null, editor, null);
			CoreEditingCommands.DeleteRight.runEditorCommand(null, editor, null);
			CoreEditingCommands.DeleteRight.runEditorCommand(null, editor, null);
			assert.equal(model.getLineContent(2), 'Another ');
			assertCursor(cursor, new Selection(2, 9, 2, 9));

			CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
			CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
			CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
			CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
			CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
			CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);
			assert.equal(model.getLineContent(2), 'An');
			assertCursor(cursor, new Selection(2, 3, 2, 3));

			cursorCommand(cursor, H.Undo, {});
			assert.equal(model.getLineContent(2), 'Another ');
			assertCursor(cursor, new Selection(2, 9, 2, 9));

			cursorCommand(cursor, H.Undo, {});
			assert.equal(model.getLineContent(2), 'Another line');
			assertCursor(cursor, new Selection(2, 9, 2, 9));
		});
	});

	test('inserts undo stop when typing space', () => {
		let model = createTextModel(
			[
				'A  line',
				'Another line',
			].join('\n')
		);

		withTestCodeEditor(null, { model: model }, (editor, cursor) => {
			cursor.setSelections('test', [new Selection(1, 3, 1, 3)]);
			cursorCommand(cursor, H.Type, { text: 'first and interesting' }, 'keyboard');
			assert.equal(model.getLineContent(1), 'A first and interesting line');
			assertCursor(cursor, new Selection(1, 24, 1, 24));

			cursorCommand(cursor, H.Undo, {});
			assert.equal(model.getLineContent(1), 'A first and line');
			assertCursor(cursor, new Selection(1, 12, 1, 12));

			cursorCommand(cursor, H.Undo, {});
			assert.equal(model.getLineContent(1), 'A first line');
			assertCursor(cursor, new Selection(1, 8, 1, 8));

			cursorCommand(cursor, H.Undo, {});
			assert.equal(model.getLineContent(1), 'A  line');
			assertCursor(cursor, new Selection(1, 3, 1, 3));
		});
	});

});
