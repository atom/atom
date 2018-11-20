/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import 'vs/css!./dnd';
import { IKeyboardEvent } from 'vs/base/browser/keyboardEvent';
import { IDisposable, dispose } from 'vs/base/common/lifecycle';
import { isMacintosh } from 'vs/base/common/platform';
import { KeyCode } from 'vs/base/common/keyCodes';
import { ICodeEditor, IEditorMouseEvent, IMouseTarget, MouseTargetType } from 'vs/editor/browser/editorBrowser';
import { registerEditorContribution } from 'vs/editor/browser/editorExtensions';
import * as editorCommon from 'vs/editor/common/editorCommon';
import { Position } from 'vs/editor/common/core/position';
import { Range } from 'vs/editor/common/core/range';
import { Selection } from 'vs/editor/common/core/selection';
import { DragAndDropCommand } from 'vs/editor/contrib/dnd/dragAndDropCommand';
import { ModelDecorationOptions } from 'vs/editor/common/model/textModel';
import { IModelDeltaDecoration } from 'vs/editor/common/model';
import { IMouseEvent } from 'vs/base/browser/mouseEvent';
import { CodeEditorWidget } from 'vs/editor/browser/widget/codeEditorWidget';

function hasTriggerModifier(e: IKeyboardEvent | IMouseEvent): boolean {
	if (isMacintosh) {
		return e.altKey;
	} else {
		return e.ctrlKey;
	}
}

export class DragAndDropController implements editorCommon.IEditorContribution {

	private static readonly ID = 'editor.contrib.dragAndDrop';

	private _editor: ICodeEditor;
	private _toUnhook: IDisposable[];
	private _dragSelection: Selection | null;
	private _dndDecorationIds: string[];
	private _mouseDown: boolean;
	private _modiferPressed: boolean;
	static TRIGGER_KEY_VALUE = isMacintosh ? KeyCode.Alt : KeyCode.Ctrl;

	static get(editor: ICodeEditor): DragAndDropController {
		return editor.getContribution<DragAndDropController>(DragAndDropController.ID);
	}

	constructor(editor: ICodeEditor) {
		this._editor = editor;
		this._toUnhook = [];
		this._toUnhook.push(this._editor.onMouseDown((e: IEditorMouseEvent) => this._onEditorMouseDown(e)));
		this._toUnhook.push(this._editor.onMouseUp((e: IEditorMouseEvent) => this._onEditorMouseUp(e)));
		this._toUnhook.push(this._editor.onMouseDrag((e: IEditorMouseEvent) => this._onEditorMouseDrag(e)));
		this._toUnhook.push(this._editor.onMouseDrop((e: IEditorMouseEvent) => this._onEditorMouseDrop(e)));
		this._toUnhook.push(this._editor.onKeyDown((e: IKeyboardEvent) => this.onEditorKeyDown(e)));
		this._toUnhook.push(this._editor.onKeyUp((e: IKeyboardEvent) => this.onEditorKeyUp(e)));
		this._toUnhook.push(this._editor.onDidBlurEditorWidget(() => this.onEditorBlur()));
		this._dndDecorationIds = [];
		this._mouseDown = false;
		this._modiferPressed = false;
		this._dragSelection = null;
	}

	private onEditorBlur() {
		this._removeDecoration();
		this._dragSelection = null;
		this._mouseDown = false;
		this._modiferPressed = false;
	}

	private onEditorKeyDown(e: IKeyboardEvent): void {
		if (!this._editor.getConfiguration().dragAndDrop) {
			return;
		}

		if (hasTriggerModifier(e)) {
			this._modiferPressed = true;
		}

		if (this._mouseDown && hasTriggerModifier(e)) {
			this._editor.updateOptions({
				mouseStyle: 'copy'
			});
		}
	}

	private onEditorKeyUp(e: IKeyboardEvent): void {
		if (!this._editor.getConfiguration().dragAndDrop) {
			return;
		}

		if (hasTriggerModifier(e)) {
			this._modiferPressed = false;
		}

		if (this._mouseDown && e.keyCode === DragAndDropController.TRIGGER_KEY_VALUE) {
			this._editor.updateOptions({
				mouseStyle: 'default'
			});
		}
	}

	private _onEditorMouseDown(mouseEvent: IEditorMouseEvent): void {
		this._mouseDown = true;
	}

	private _onEditorMouseUp(mouseEvent: IEditorMouseEvent): void {
		this._mouseDown = false;
		// Whenever users release the mouse, the drag and drop operation should finish and the cursor should revert to text.
		this._editor.updateOptions({
			mouseStyle: 'text'
		});
	}

	private _onEditorMouseDrag(mouseEvent: IEditorMouseEvent): void {
		let target = mouseEvent.target;

		if (this._dragSelection === null) {
			const selections = this._editor.getSelections() || [];
			let possibleSelections = selections.filter(selection => target.position && selection.containsPosition(target.position));
			if (possibleSelections.length === 1) {
				this._dragSelection = possibleSelections[0];
			} else {
				return;
			}
		}

		if (hasTriggerModifier(mouseEvent.event)) {
			this._editor.updateOptions({
				mouseStyle: 'copy'
			});
		} else {
			this._editor.updateOptions({
				mouseStyle: 'default'
			});
		}

		if (target.position) {
			if (this._dragSelection.containsPosition(target.position)) {
				this._removeDecoration();
			} else {
				this.showAt(target.position);
			}
		}
	}

	private _onEditorMouseDrop(mouseEvent: IEditorMouseEvent): void {
		if (mouseEvent.target && (this._hitContent(mouseEvent.target) || this._hitMargin(mouseEvent.target)) && mouseEvent.target.position) {
			let newCursorPosition = new Position(mouseEvent.target.position.lineNumber, mouseEvent.target.position.column);

			if (this._dragSelection === null) {
				let newSelections: Selection[] | null = null;
				if (mouseEvent.event.shiftKey) {
					let primarySelection = this._editor.getSelection();
					if (primarySelection) {
						const { selectionStartLineNumber, selectionStartColumn } = primarySelection;
						newSelections = [new Selection(selectionStartLineNumber, selectionStartColumn, newCursorPosition.lineNumber, newCursorPosition.column)];
					}
				} else {
					newSelections = (this._editor.getSelections() || []).map(selection => {
						if (selection.containsPosition(newCursorPosition)) {
							return new Selection(newCursorPosition.lineNumber, newCursorPosition.column, newCursorPosition.lineNumber, newCursorPosition.column);
						} else {
							return selection;
						}
					});
				}
				// Use `mouse` as the source instead of `api`.
				(<CodeEditorWidget>this._editor).setSelections(newSelections || [], 'mouse');
			} else if (!this._dragSelection.containsPosition(newCursorPosition) ||
				(
					(
						hasTriggerModifier(mouseEvent.event) ||
						this._modiferPressed
					) && (
						this._dragSelection.getEndPosition().equals(newCursorPosition) || this._dragSelection.getStartPosition().equals(newCursorPosition)
					) // we allow users to paste content beside the selection
				)) {
				this._editor.pushUndoStop();
				this._editor.executeCommand(DragAndDropController.ID, new DragAndDropCommand(this._dragSelection, newCursorPosition, hasTriggerModifier(mouseEvent.event) || this._modiferPressed));
				this._editor.pushUndoStop();
			}
		}

		this._editor.updateOptions({
			mouseStyle: 'text'
		});

		this._removeDecoration();
		this._dragSelection = null;
		this._mouseDown = false;
	}

	private static readonly _DECORATION_OPTIONS = ModelDecorationOptions.register({
		className: 'dnd-target'
	});

	public showAt(position: Position): void {
		let newDecorations: IModelDeltaDecoration[] = [{
			range: new Range(position.lineNumber, position.column, position.lineNumber, position.column),
			options: DragAndDropController._DECORATION_OPTIONS
		}];

		this._dndDecorationIds = this._editor.deltaDecorations(this._dndDecorationIds, newDecorations);
		this._editor.revealPosition(position, editorCommon.ScrollType.Immediate);
	}

	private _removeDecoration(): void {
		this._dndDecorationIds = this._editor.deltaDecorations(this._dndDecorationIds, []);
	}

	private _hitContent(target: IMouseTarget): boolean {
		return target.type === MouseTargetType.CONTENT_TEXT ||
			target.type === MouseTargetType.CONTENT_EMPTY;
	}

	private _hitMargin(target: IMouseTarget): boolean {
		return target.type === MouseTargetType.GUTTER_GLYPH_MARGIN ||
			target.type === MouseTargetType.GUTTER_LINE_NUMBERS ||
			target.type === MouseTargetType.GUTTER_LINE_DECORATIONS;
	}

	public getId(): string {
		return DragAndDropController.ID;
	}

	public dispose(): void {
		this._removeDecoration();
		this._dragSelection = null;
		this._mouseDown = false;
		this._modiferPressed = false;
		this._toUnhook = dispose(this._toUnhook);
	}
}

registerEditorContribution(DragAndDropController);
