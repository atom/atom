/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as nls from 'vs/nls';
import { KeyChord, KeyCode, KeyMod } from 'vs/base/common/keyCodes';
import { CoreEditingCommands } from 'vs/editor/browser/controller/coreCommands';
import { ICodeEditor } from 'vs/editor/browser/editorBrowser';
import { EditorAction, IActionOptions, ServicesAccessor, registerEditorAction } from 'vs/editor/browser/editorExtensions';
import { ReplaceCommand, ReplaceCommandThatPreservesSelection } from 'vs/editor/common/commands/replaceCommand';
import { TrimTrailingWhitespaceCommand } from 'vs/editor/common/commands/trimTrailingWhitespaceCommand';
import { TypeOperations } from 'vs/editor/common/controller/cursorTypeOperations';
import { EditOperation } from 'vs/editor/common/core/editOperation';
import { Position } from 'vs/editor/common/core/position';
import { Range } from 'vs/editor/common/core/range';
import { Selection } from 'vs/editor/common/core/selection';
import { ICommand } from 'vs/editor/common/editorCommon';
import { EditorContextKeys } from 'vs/editor/common/editorContextKeys';
import { IIdentifiedSingleEditOperation } from 'vs/editor/common/model';
import { CopyLinesCommand } from 'vs/editor/contrib/linesOperations/copyLinesCommand';
import { DeleteLinesCommand } from 'vs/editor/contrib/linesOperations/deleteLinesCommand';
import { MoveLinesCommand } from 'vs/editor/contrib/linesOperations/moveLinesCommand';
import { SortLinesCommand } from 'vs/editor/contrib/linesOperations/sortLinesCommand';
import { MenuId } from 'vs/platform/actions/common/actions';
import { KeybindingWeight } from 'vs/platform/keybinding/common/keybindingsRegistry';

// copy lines

abstract class AbstractCopyLinesAction extends EditorAction {

	private down: boolean;

	constructor(down: boolean, opts: IActionOptions) {
		super(opts);
		this.down = down;
	}

	public run(_accessor: ServicesAccessor, editor: ICodeEditor): void {

		let commands: ICommand[] = [];
		let selections = editor.getSelections() || [];

		for (let i = 0; i < selections.length; i++) {
			commands.push(new CopyLinesCommand(selections[i], this.down));
		}

		editor.pushUndoStop();
		editor.executeCommands(this.id, commands);
		editor.pushUndoStop();
	}
}

class CopyLinesUpAction extends AbstractCopyLinesAction {
	constructor() {
		super(false, {
			id: 'editor.action.copyLinesUpAction',
			label: nls.localize('lines.copyUp', "Copy Line Up"),
			alias: 'Copy Line Up',
			precondition: EditorContextKeys.writable,
			kbOpts: {
				kbExpr: EditorContextKeys.editorTextFocus,
				primary: KeyMod.Alt | KeyMod.Shift | KeyCode.UpArrow,
				linux: { primary: KeyMod.CtrlCmd | KeyMod.Alt | KeyMod.Shift | KeyCode.UpArrow },
				weight: KeybindingWeight.EditorContrib
			},
			menubarOpts: {
				menuId: MenuId.MenubarSelectionMenu,
				group: '2_line',
				title: nls.localize({ key: 'miCopyLinesUp', comment: ['&& denotes a mnemonic'] }, "&&Copy Line Up"),
				order: 1
			}
		});
	}
}

class CopyLinesDownAction extends AbstractCopyLinesAction {
	constructor() {
		super(true, {
			id: 'editor.action.copyLinesDownAction',
			label: nls.localize('lines.copyDown', "Copy Line Down"),
			alias: 'Copy Line Down',
			precondition: EditorContextKeys.writable,
			kbOpts: {
				kbExpr: EditorContextKeys.editorTextFocus,
				primary: KeyMod.Alt | KeyMod.Shift | KeyCode.DownArrow,
				linux: { primary: KeyMod.CtrlCmd | KeyMod.Alt | KeyMod.Shift | KeyCode.DownArrow },
				weight: KeybindingWeight.EditorContrib
			},
			menubarOpts: {
				menuId: MenuId.MenubarSelectionMenu,
				group: '2_line',
				title: nls.localize({ key: 'miCopyLinesDown', comment: ['&& denotes a mnemonic'] }, "Co&&py Line Down"),
				order: 2
			}
		});
	}
}

// move lines

abstract class AbstractMoveLinesAction extends EditorAction {

	private down: boolean;

	constructor(down: boolean, opts: IActionOptions) {
		super(opts);
		this.down = down;
	}

	public run(_accessor: ServicesAccessor, editor: ICodeEditor): void {

		let commands: ICommand[] = [];
		let selections = editor.getSelections() || [];
		let autoIndent = editor.getConfiguration().autoIndent;

		for (let i = 0; i < selections.length; i++) {
			commands.push(new MoveLinesCommand(selections[i], this.down, autoIndent));
		}

		editor.pushUndoStop();
		editor.executeCommands(this.id, commands);
		editor.pushUndoStop();
	}
}

class MoveLinesUpAction extends AbstractMoveLinesAction {
	constructor() {
		super(false, {
			id: 'editor.action.moveLinesUpAction',
			label: nls.localize('lines.moveUp', "Move Line Up"),
			alias: 'Move Line Up',
			precondition: EditorContextKeys.writable,
			kbOpts: {
				kbExpr: EditorContextKeys.editorTextFocus,
				primary: KeyMod.Alt | KeyCode.UpArrow,
				linux: { primary: KeyMod.Alt | KeyCode.UpArrow },
				weight: KeybindingWeight.EditorContrib
			},
			menubarOpts: {
				menuId: MenuId.MenubarSelectionMenu,
				group: '2_line',
				title: nls.localize({ key: 'miMoveLinesUp', comment: ['&& denotes a mnemonic'] }, "Mo&&ve Line Up"),
				order: 3
			}
		});
	}
}

class MoveLinesDownAction extends AbstractMoveLinesAction {
	constructor() {
		super(true, {
			id: 'editor.action.moveLinesDownAction',
			label: nls.localize('lines.moveDown', "Move Line Down"),
			alias: 'Move Line Down',
			precondition: EditorContextKeys.writable,
			kbOpts: {
				kbExpr: EditorContextKeys.editorTextFocus,
				primary: KeyMod.Alt | KeyCode.DownArrow,
				linux: { primary: KeyMod.Alt | KeyCode.DownArrow },
				weight: KeybindingWeight.EditorContrib
			},
			menubarOpts: {
				menuId: MenuId.MenubarSelectionMenu,
				group: '2_line',
				title: nls.localize({ key: 'miMoveLinesDown', comment: ['&& denotes a mnemonic'] }, "Move &&Line Down"),
				order: 4
			}
		});
	}
}

export abstract class AbstractSortLinesAction extends EditorAction {
	private descending: boolean;

	constructor(descending: boolean, opts: IActionOptions) {
		super(opts);
		this.descending = descending;
	}

	public run(_accessor: ServicesAccessor, editor: ICodeEditor): void {
		const selections = editor.getSelections() || [];

		for (let i = 0, len = selections.length; i < len; i++) {
			const selection = selections[i];
			if (!SortLinesCommand.canRun(editor.getModel(), selection, this.descending)) {
				return;
			}
		}

		let commands: ICommand[] = [];
		for (let i = 0, len = selections.length; i < len; i++) {
			commands[i] = new SortLinesCommand(selections[i], this.descending);
		}

		editor.pushUndoStop();
		editor.executeCommands(this.id, commands);
		editor.pushUndoStop();
	}
}

export class SortLinesAscendingAction extends AbstractSortLinesAction {
	constructor() {
		super(false, {
			id: 'editor.action.sortLinesAscending',
			label: nls.localize('lines.sortAscending', "Sort Lines Ascending"),
			alias: 'Sort Lines Ascending',
			precondition: EditorContextKeys.writable
		});
	}
}

export class SortLinesDescendingAction extends AbstractSortLinesAction {
	constructor() {
		super(true, {
			id: 'editor.action.sortLinesDescending',
			label: nls.localize('lines.sortDescending', "Sort Lines Descending"),
			alias: 'Sort Lines Descending',
			precondition: EditorContextKeys.writable
		});
	}
}

export class TrimTrailingWhitespaceAction extends EditorAction {

	public static readonly ID = 'editor.action.trimTrailingWhitespace';

	constructor() {
		super({
			id: TrimTrailingWhitespaceAction.ID,
			label: nls.localize('lines.trimTrailingWhitespace', "Trim Trailing Whitespace"),
			alias: 'Trim Trailing Whitespace',
			precondition: EditorContextKeys.writable,
			kbOpts: {
				kbExpr: EditorContextKeys.editorTextFocus,
				primary: KeyChord(KeyMod.CtrlCmd | KeyCode.KEY_K, KeyMod.CtrlCmd | KeyCode.KEY_X),
				weight: KeybindingWeight.EditorContrib
			}
		});
	}

	public run(_accessor: ServicesAccessor, editor: ICodeEditor, args: any): void {

		let cursors: Position[] = [];
		if (args.reason === 'auto-save') {
			// See https://github.com/editorconfig/editorconfig-vscode/issues/47
			// It is very convenient for the editor config extension to invoke this action.
			// So, if we get a reason:'auto-save' passed in, let's preserve cursor positions.
			cursors = (editor.getSelections() || []).map(s => new Position(s.positionLineNumber, s.positionColumn));
		}

		let selection = editor.getSelection();
		if (selection === null) {
			return;
		}

		let command = new TrimTrailingWhitespaceCommand(selection, cursors);

		editor.pushUndoStop();
		editor.executeCommands(this.id, [command]);
		editor.pushUndoStop();
	}
}

// delete lines

interface IDeleteLinesOperation {
	startLineNumber: number;
	endLineNumber: number;
	positionColumn: number;
}

export class DeleteLinesAction extends EditorAction {

	constructor() {
		super({
			id: 'editor.action.deleteLines',
			label: nls.localize('lines.delete', "Delete Line"),
			alias: 'Delete Line',
			precondition: EditorContextKeys.writable,
			kbOpts: {
				kbExpr: EditorContextKeys.textInputFocus,
				primary: KeyMod.CtrlCmd | KeyMod.Shift | KeyCode.KEY_K,
				weight: KeybindingWeight.EditorContrib
			}
		});
	}

	public run(_accessor: ServicesAccessor, editor: ICodeEditor): void {

		let ops = this._getLinesToRemove(editor);

		// Finally, construct the delete lines commands
		let commands: ICommand[] = ops.map((op) => {
			return new DeleteLinesCommand(op.startLineNumber, op.endLineNumber, op.positionColumn);
		});

		editor.pushUndoStop();
		editor.executeCommands(this.id, commands);
		editor.pushUndoStop();
	}

	private _getLinesToRemove(editor: ICodeEditor): IDeleteLinesOperation[] {
		// Construct delete operations
		let selections = editor.getSelections();
		if (selections === null) {
			return [];
		}
		let operations: IDeleteLinesOperation[] = selections.map((s) => {

			let endLineNumber = s.endLineNumber;
			if (s.startLineNumber < s.endLineNumber && s.endColumn === 1) {
				endLineNumber -= 1;
			}

			return {
				startLineNumber: s.startLineNumber,
				endLineNumber: endLineNumber,
				positionColumn: s.positionColumn
			};
		});

		// Sort delete operations
		operations.sort((a, b) => {
			if (a.startLineNumber === b.startLineNumber) {
				return a.endLineNumber - b.endLineNumber;
			}
			return a.startLineNumber - b.startLineNumber;
		});

		// Merge delete operations which are adjacent or overlapping
		let mergedOperations: IDeleteLinesOperation[] = [];
		let previousOperation = operations[0];
		for (let i = 1; i < operations.length; i++) {
			if (previousOperation.endLineNumber + 1 >= operations[i].startLineNumber) {
				// Merge current operations into the previous one
				previousOperation.endLineNumber = operations[i].endLineNumber;
			} else {
				// Push previous operation
				mergedOperations.push(previousOperation);
				previousOperation = operations[i];
			}
		}
		// Push the last operation
		mergedOperations.push(previousOperation);

		return mergedOperations;
	}
}

export class IndentLinesAction extends EditorAction {
	constructor() {
		super({
			id: 'editor.action.indentLines',
			label: nls.localize('lines.indent', "Indent Line"),
			alias: 'Indent Line',
			precondition: EditorContextKeys.writable,
			kbOpts: {
				kbExpr: EditorContextKeys.editorTextFocus,
				primary: KeyMod.CtrlCmd | KeyCode.US_CLOSE_SQUARE_BRACKET,
				weight: KeybindingWeight.EditorContrib
			}
		});
	}

	public run(_accessor: ServicesAccessor, editor: ICodeEditor): void {
		const cursors = editor._getCursors();
		if (!cursors) {
			return;
		}
		editor.pushUndoStop();
		editor.executeCommands(this.id, TypeOperations.indent(cursors.context.config, editor.getModel(), editor.getSelections()));
		editor.pushUndoStop();
	}
}

class OutdentLinesAction extends EditorAction {
	constructor() {
		super({
			id: 'editor.action.outdentLines',
			label: nls.localize('lines.outdent', "Outdent Line"),
			alias: 'Outdent Line',
			precondition: EditorContextKeys.writable,
			kbOpts: {
				kbExpr: EditorContextKeys.editorTextFocus,
				primary: KeyMod.CtrlCmd | KeyCode.US_OPEN_SQUARE_BRACKET,
				weight: KeybindingWeight.EditorContrib
			}
		});
	}

	public run(_accessor: ServicesAccessor, editor: ICodeEditor): void {
		CoreEditingCommands.Outdent.runEditorCommand(_accessor, editor, null);
	}
}

export class InsertLineBeforeAction extends EditorAction {
	constructor() {
		super({
			id: 'editor.action.insertLineBefore',
			label: nls.localize('lines.insertBefore', "Insert Line Above"),
			alias: 'Insert Line Above',
			precondition: EditorContextKeys.writable,
			kbOpts: {
				kbExpr: EditorContextKeys.editorTextFocus,
				primary: KeyMod.CtrlCmd | KeyMod.Shift | KeyCode.Enter,
				weight: KeybindingWeight.EditorContrib
			}
		});
	}

	public run(_accessor: ServicesAccessor, editor: ICodeEditor): void {
		const cursors = editor._getCursors();
		if (!cursors) {
			return;
		}
		editor.pushUndoStop();
		editor.executeCommands(this.id, TypeOperations.lineInsertBefore(cursors.context.config, editor.getModel(), editor.getSelections()));
	}
}

export class InsertLineAfterAction extends EditorAction {
	constructor() {
		super({
			id: 'editor.action.insertLineAfter',
			label: nls.localize('lines.insertAfter', "Insert Line Below"),
			alias: 'Insert Line Below',
			precondition: EditorContextKeys.writable,
			kbOpts: {
				kbExpr: EditorContextKeys.editorTextFocus,
				primary: KeyMod.CtrlCmd | KeyCode.Enter,
				weight: KeybindingWeight.EditorContrib
			}
		});
	}

	public run(_accessor: ServicesAccessor, editor: ICodeEditor): void {
		const cursors = editor._getCursors();
		if (!cursors) {
			return;
		}
		editor.pushUndoStop();
		editor.executeCommands(this.id, TypeOperations.lineInsertAfter(cursors.context.config, editor.getModel(), editor.getSelections()));
	}
}

export abstract class AbstractDeleteAllToBoundaryAction extends EditorAction {
	public run(_accessor: ServicesAccessor, editor: ICodeEditor): void {
		const primaryCursor = editor.getSelection();
		if (primaryCursor === null) {
			return;
		}

		let rangesToDelete = this._getRangesToDelete(editor);
		// merge overlapping selections
		let effectiveRanges: Range[] = [];

		for (let i = 0, count = rangesToDelete.length - 1; i < count; i++) {
			let range = rangesToDelete[i];
			let nextRange = rangesToDelete[i + 1];

			if (Range.intersectRanges(range, nextRange) === null) {
				effectiveRanges.push(range);
			} else {
				rangesToDelete[i + 1] = Range.plusRange(range, nextRange);
			}
		}

		effectiveRanges.push(rangesToDelete[rangesToDelete.length - 1]);

		let endCursorState = this._getEndCursorState(primaryCursor, effectiveRanges);

		let edits: IIdentifiedSingleEditOperation[] = effectiveRanges.map(range => {
			return EditOperation.replace(range, '');
		});

		editor.pushUndoStop();
		editor.executeEdits(this.id, edits, endCursorState);
		editor.pushUndoStop();
	}

	/**
	 * Compute the cursor state after the edit operations were applied.
	 */
	protected abstract _getEndCursorState(primaryCursor: Range, rangesToDelete: Range[]): Selection[];

	protected abstract _getRangesToDelete(editor: ICodeEditor): Range[];
}

export class DeleteAllLeftAction extends AbstractDeleteAllToBoundaryAction {
	constructor() {
		super({
			id: 'deleteAllLeft',
			label: nls.localize('lines.deleteAllLeft', "Delete All Left"),
			alias: 'Delete All Left',
			precondition: EditorContextKeys.writable,
			kbOpts: {
				kbExpr: EditorContextKeys.textInputFocus,
				primary: 0,
				mac: { primary: KeyMod.CtrlCmd | KeyCode.Backspace },
				weight: KeybindingWeight.EditorContrib
			}
		});
	}

	_getEndCursorState(primaryCursor: Range, rangesToDelete: Range[]): Selection[] {
		let endPrimaryCursor: Selection | null = null;
		let endCursorState: Selection[] = [];
		let deletedLines = 0;

		rangesToDelete.forEach(range => {
			let endCursor;
			if (range.endColumn === 1 && deletedLines > 0) {
				let newStartLine = range.startLineNumber - deletedLines;
				endCursor = new Selection(newStartLine, range.startColumn, newStartLine, range.startColumn);
			} else {
				endCursor = new Selection(range.startLineNumber, range.startColumn, range.startLineNumber, range.startColumn);
			}

			deletedLines += range.endLineNumber - range.startLineNumber;

			if (range.intersectRanges(primaryCursor)) {
				endPrimaryCursor = endCursor;
			} else {
				endCursorState.push(endCursor);
			}
		});

		if (endPrimaryCursor) {
			endCursorState.unshift(endPrimaryCursor);
		}

		return endCursorState;
	}

	_getRangesToDelete(editor: ICodeEditor): Range[] {
		let selections = editor.getSelections();
		if (selections === null) {
			return [];
		}

		let rangesToDelete: Range[] = selections;
		let model = editor.getModel();

		if (model === null) {
			return [];
		}

		rangesToDelete.sort(Range.compareRangesUsingStarts);
		rangesToDelete = rangesToDelete.map(selection => {
			if (selection.isEmpty()) {
				if (selection.startColumn === 1) {
					let deleteFromLine = Math.max(1, selection.startLineNumber - 1);
					let deleteFromColumn = selection.startLineNumber === 1 ? 1 : model!.getLineContent(deleteFromLine).length + 1;
					return new Range(deleteFromLine, deleteFromColumn, selection.startLineNumber, 1);
				} else {
					return new Range(selection.startLineNumber, 1, selection.startLineNumber, selection.startColumn);
				}
			} else {
				return selection;
			}
		});

		return rangesToDelete;
	}
}

export class DeleteAllRightAction extends AbstractDeleteAllToBoundaryAction {
	constructor() {
		super({
			id: 'deleteAllRight',
			label: nls.localize('lines.deleteAllRight', "Delete All Right"),
			alias: 'Delete All Right',
			precondition: EditorContextKeys.writable,
			kbOpts: {
				kbExpr: EditorContextKeys.textInputFocus,
				primary: 0,
				mac: { primary: KeyMod.WinCtrl | KeyCode.KEY_K, secondary: [KeyMod.CtrlCmd | KeyCode.Delete] },
				weight: KeybindingWeight.EditorContrib
			}
		});
	}

	_getEndCursorState(primaryCursor: Range, rangesToDelete: Range[]): Selection[] {
		let endPrimaryCursor: Selection | null = null;
		let endCursorState: Selection[] = [];
		for (let i = 0, len = rangesToDelete.length, offset = 0; i < len; i++) {
			let range = rangesToDelete[i];
			let endCursor = new Selection(range.startLineNumber - offset, range.startColumn, range.startLineNumber - offset, range.startColumn);

			if (range.intersectRanges(primaryCursor)) {
				endPrimaryCursor = endCursor;
			} else {
				endCursorState.push(endCursor);
			}
		}

		if (endPrimaryCursor) {
			endCursorState.unshift(endPrimaryCursor);
		}

		return endCursorState;
	}

	_getRangesToDelete(editor: ICodeEditor): Range[] {
		let model = editor.getModel();
		if (model === null) {
			return [];
		}

		let selections = editor.getSelections();

		if (selections === null) {
			return [];
		}

		let rangesToDelete: Range[] = selections.map((sel) => {
			if (sel.isEmpty()) {
				const maxColumn = model!.getLineMaxColumn(sel.startLineNumber);

				if (sel.startColumn === maxColumn) {
					return new Range(sel.startLineNumber, sel.startColumn, sel.startLineNumber + 1, 1);
				} else {
					return new Range(sel.startLineNumber, sel.startColumn, sel.startLineNumber, maxColumn);
				}
			}
			return sel;
		});

		rangesToDelete.sort(Range.compareRangesUsingStarts);
		return rangesToDelete;
	}
}

export class JoinLinesAction extends EditorAction {
	constructor() {
		super({
			id: 'editor.action.joinLines',
			label: nls.localize('lines.joinLines', "Join Lines"),
			alias: 'Join Lines',
			precondition: EditorContextKeys.writable,
			kbOpts: {
				kbExpr: EditorContextKeys.editorTextFocus,
				primary: 0,
				mac: { primary: KeyMod.WinCtrl | KeyCode.KEY_J },
				weight: KeybindingWeight.EditorContrib
			}
		});
	}

	public run(_accessor: ServicesAccessor, editor: ICodeEditor): void {
		let selections = editor.getSelections();
		if (selections === null) {
			return;
		}

		let primaryCursor = editor.getSelection();
		if (primaryCursor === null) {
			return;
		}

		selections.sort(Range.compareRangesUsingStarts);
		let reducedSelections: Selection[] = [];

		let lastSelection = selections.reduce((previousValue, currentValue) => {
			if (previousValue.isEmpty()) {
				if (previousValue.endLineNumber === currentValue.startLineNumber) {
					if (primaryCursor!.equalsSelection(previousValue)) {
						primaryCursor = currentValue;
					}
					return currentValue;
				}

				if (currentValue.startLineNumber > previousValue.endLineNumber + 1) {
					reducedSelections.push(previousValue);
					return currentValue;
				} else {
					return new Selection(previousValue.startLineNumber, previousValue.startColumn, currentValue.endLineNumber, currentValue.endColumn);
				}
			} else {
				if (currentValue.startLineNumber > previousValue.endLineNumber) {
					reducedSelections.push(previousValue);
					return currentValue;
				} else {
					return new Selection(previousValue.startLineNumber, previousValue.startColumn, currentValue.endLineNumber, currentValue.endColumn);
				}
			}
		});

		reducedSelections.push(lastSelection);

		let model = editor.getModel();
		if (model === null) {
			return;
		}

		let edits: IIdentifiedSingleEditOperation[] = [];
		let endCursorState: Selection[] = [];
		let endPrimaryCursor = primaryCursor;
		let lineOffset = 0;

		for (let i = 0, len = reducedSelections.length; i < len; i++) {
			let selection = reducedSelections[i];
			let startLineNumber = selection.startLineNumber;
			let startColumn = 1;
			let columnDeltaOffset = 0;
			let endLineNumber: number,
				endColumn: number;

			let selectionEndPositionOffset = model.getLineContent(selection.endLineNumber).length - selection.endColumn;

			if (selection.isEmpty() || selection.startLineNumber === selection.endLineNumber) {
				let position = selection.getStartPosition();
				if (position.lineNumber < model.getLineCount()) {
					endLineNumber = startLineNumber + 1;
					endColumn = model.getLineMaxColumn(endLineNumber);
				} else {
					endLineNumber = position.lineNumber;
					endColumn = model.getLineMaxColumn(position.lineNumber);
				}
			} else {
				endLineNumber = selection.endLineNumber;
				endColumn = model.getLineMaxColumn(endLineNumber);
			}

			let trimmedLinesContent = model.getLineContent(startLineNumber);

			for (let i = startLineNumber + 1; i <= endLineNumber; i++) {
				let lineText = model.getLineContent(i);
				let firstNonWhitespaceIdx = model.getLineFirstNonWhitespaceColumn(i);

				if (firstNonWhitespaceIdx >= 1) {
					let insertSpace = true;
					if (trimmedLinesContent === '') {
						insertSpace = false;
					}

					if (insertSpace && (trimmedLinesContent.charAt(trimmedLinesContent.length - 1) === ' ' ||
						trimmedLinesContent.charAt(trimmedLinesContent.length - 1) === '\t')) {
						insertSpace = false;
						trimmedLinesContent = trimmedLinesContent.replace(/[\s\uFEFF\xA0]+$/g, ' ');
					}

					let lineTextWithoutIndent = lineText.substr(firstNonWhitespaceIdx - 1);

					trimmedLinesContent += (insertSpace ? ' ' : '') + lineTextWithoutIndent;

					if (insertSpace) {
						columnDeltaOffset = lineTextWithoutIndent.length + 1;
					} else {
						columnDeltaOffset = lineTextWithoutIndent.length;
					}
				} else {
					columnDeltaOffset = 0;
				}
			}

			let deleteSelection = new Range(startLineNumber, startColumn, endLineNumber, endColumn);

			if (!deleteSelection.isEmpty()) {
				let resultSelection: Selection;

				if (selection.isEmpty()) {
					edits.push(EditOperation.replace(deleteSelection, trimmedLinesContent));
					resultSelection = new Selection(deleteSelection.startLineNumber - lineOffset, trimmedLinesContent.length - columnDeltaOffset + 1, startLineNumber - lineOffset, trimmedLinesContent.length - columnDeltaOffset + 1);
				} else {
					if (selection.startLineNumber === selection.endLineNumber) {
						edits.push(EditOperation.replace(deleteSelection, trimmedLinesContent));
						resultSelection = new Selection(selection.startLineNumber - lineOffset, selection.startColumn,
							selection.endLineNumber - lineOffset, selection.endColumn);
					} else {
						edits.push(EditOperation.replace(deleteSelection, trimmedLinesContent));
						resultSelection = new Selection(selection.startLineNumber - lineOffset, selection.startColumn,
							selection.startLineNumber - lineOffset, trimmedLinesContent.length - selectionEndPositionOffset);
					}
				}

				if (Range.intersectRanges(deleteSelection, primaryCursor) !== null) {
					endPrimaryCursor = resultSelection;
				} else {
					endCursorState.push(resultSelection);
				}
			}

			lineOffset += deleteSelection.endLineNumber - deleteSelection.startLineNumber;
		}

		endCursorState.unshift(endPrimaryCursor);
		editor.pushUndoStop();
		editor.executeEdits(this.id, edits, endCursorState);
		editor.pushUndoStop();
	}
}

export class TransposeAction extends EditorAction {
	constructor() {
		super({
			id: 'editor.action.transpose',
			label: nls.localize('editor.transpose', "Transpose characters around the cursor"),
			alias: 'Transpose characters around the cursor',
			precondition: EditorContextKeys.writable
		});
	}

	public run(_accessor: ServicesAccessor, editor: ICodeEditor): void {
		let selections = editor.getSelections();
		if (selections === null) {
			return;
		}

		let model = editor.getModel();
		if (model === null) {
			return;
		}

		let commands: ICommand[] = [];

		for (let i = 0, len = selections.length; i < len; i++) {
			let selection = selections[i];

			if (!selection.isEmpty()) {
				continue;
			}

			let cursor = selection.getStartPosition();
			let maxColumn = model.getLineMaxColumn(cursor.lineNumber);

			if (cursor.column >= maxColumn) {
				if (cursor.lineNumber === model.getLineCount()) {
					continue;
				}

				// The cursor is at the end of current line and current line is not empty
				// then we transpose the character before the cursor and the line break if there is any following line.
				let deleteSelection = new Range(cursor.lineNumber, Math.max(1, cursor.column - 1), cursor.lineNumber + 1, 1);
				let chars = model.getValueInRange(deleteSelection).split('').reverse().join('');

				commands.push(new ReplaceCommand(new Selection(cursor.lineNumber, Math.max(1, cursor.column - 1), cursor.lineNumber + 1, 1), chars));
			} else {
				let deleteSelection = new Range(cursor.lineNumber, Math.max(1, cursor.column - 1), cursor.lineNumber, cursor.column + 1);
				let chars = model.getValueInRange(deleteSelection).split('').reverse().join('');
				commands.push(new ReplaceCommandThatPreservesSelection(deleteSelection, chars,
					new Selection(cursor.lineNumber, cursor.column + 1, cursor.lineNumber, cursor.column + 1)));
			}
		}

		editor.pushUndoStop();
		editor.executeCommands(this.id, commands);
		editor.pushUndoStop();
	}
}

export abstract class AbstractCaseAction extends EditorAction {
	public run(_accessor: ServicesAccessor, editor: ICodeEditor): void {
		let selections = editor.getSelections();
		if (selections === null) {
			return;
		}

		let model = editor.getModel();
		if (model === null) {
			return;
		}

		let commands: ICommand[] = [];

		for (let i = 0, len = selections.length; i < len; i++) {
			let selection = selections[i];
			if (selection.isEmpty()) {
				let cursor = selection.getStartPosition();
				let word = model.getWordAtPosition(cursor);

				if (!word) {
					continue;
				}

				let wordRange = new Range(cursor.lineNumber, word.startColumn, cursor.lineNumber, word.endColumn);
				let text = model.getValueInRange(wordRange);
				commands.push(new ReplaceCommandThatPreservesSelection(wordRange, this._modifyText(text),
					new Selection(cursor.lineNumber, cursor.column, cursor.lineNumber, cursor.column)));

			} else {
				let text = model.getValueInRange(selection);
				commands.push(new ReplaceCommandThatPreservesSelection(selection, this._modifyText(text), selection));
			}
		}

		editor.pushUndoStop();
		editor.executeCommands(this.id, commands);
		editor.pushUndoStop();
	}

	protected abstract _modifyText(text: string): string;
}

export class UpperCaseAction extends AbstractCaseAction {
	constructor() {
		super({
			id: 'editor.action.transformToUppercase',
			label: nls.localize('editor.transformToUppercase', "Transform to Uppercase"),
			alias: 'Transform to Uppercase',
			precondition: EditorContextKeys.writable
		});
	}

	protected _modifyText(text: string): string {
		return text.toLocaleUpperCase();
	}
}

export class LowerCaseAction extends AbstractCaseAction {
	constructor() {
		super({
			id: 'editor.action.transformToLowercase',
			label: nls.localize('editor.transformToLowercase', "Transform to Lowercase"),
			alias: 'Transform to Lowercase',
			precondition: EditorContextKeys.writable
		});
	}

	protected _modifyText(text: string): string {
		return text.toLocaleLowerCase();
	}
}

registerEditorAction(CopyLinesUpAction);
registerEditorAction(CopyLinesDownAction);
registerEditorAction(MoveLinesUpAction);
registerEditorAction(MoveLinesDownAction);
registerEditorAction(SortLinesAscendingAction);
registerEditorAction(SortLinesDescendingAction);
registerEditorAction(TrimTrailingWhitespaceAction);
registerEditorAction(DeleteLinesAction);
registerEditorAction(IndentLinesAction);
registerEditorAction(OutdentLinesAction);
registerEditorAction(InsertLineBeforeAction);
registerEditorAction(InsertLineAfterAction);
registerEditorAction(DeleteAllLeftAction);
registerEditorAction(DeleteAllRightAction);
registerEditorAction(JoinLinesAction);
registerEditorAction(TransposeAction);
registerEditorAction(UpperCaseAction);
registerEditorAction(LowerCaseAction);
