/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import 'vs/css!./goToDefinitionMouse';
import { KeyCode } from 'vs/base/common/keyCodes';
import * as browser from 'vs/base/browser/browser';
import { IKeyboardEvent } from 'vs/base/browser/keyboardEvent';
import { ICodeEditor, IEditorMouseEvent, IMouseTarget } from 'vs/editor/browser/editorBrowser';
import { Disposable } from 'vs/base/common/lifecycle';
import { ICursorSelectionChangedEvent } from 'vs/editor/common/controller/cursorEvents';
import { Event, Emitter } from 'vs/base/common/event';
import * as platform from 'vs/base/common/platform';

function hasModifier(e: { ctrlKey: boolean; shiftKey: boolean; altKey: boolean; metaKey: boolean }, modifier: 'ctrlKey' | 'shiftKey' | 'altKey' | 'metaKey'): boolean {
	return !!e[modifier];
}

/**
 * An event that encapsulates the various trigger modifiers logic needed for go to definition.
 */
export class ClickLinkMouseEvent {

	public readonly target: IMouseTarget;
	public readonly hasTriggerModifier: boolean;
	public readonly hasSideBySideModifier: boolean;
	public readonly isNoneOrSingleMouseDown: boolean;

	constructor(source: IEditorMouseEvent, opts: ClickLinkOptions) {
		this.target = source.target;
		this.hasTriggerModifier = hasModifier(source.event, opts.triggerModifier);
		this.hasSideBySideModifier = hasModifier(source.event, opts.triggerSideBySideModifier);
		this.isNoneOrSingleMouseDown = (browser.isIE || source.event.detail <= 1); // IE does not support event.detail properly
	}
}

/**
 * An event that encapsulates the various trigger modifiers logic needed for go to definition.
 */
export class ClickLinkKeyboardEvent {

	public readonly keyCodeIsTriggerKey: boolean;
	public readonly keyCodeIsSideBySideKey: boolean;
	public readonly hasTriggerModifier: boolean;

	constructor(source: IKeyboardEvent, opts: ClickLinkOptions) {
		this.keyCodeIsTriggerKey = (source.keyCode === opts.triggerKey);
		this.keyCodeIsSideBySideKey = (source.keyCode === opts.triggerSideBySideKey);
		this.hasTriggerModifier = hasModifier(source, opts.triggerModifier);
	}
}
export type TriggerModifier = 'ctrlKey' | 'shiftKey' | 'altKey' | 'metaKey';

export class ClickLinkOptions {

	public readonly triggerKey: KeyCode;
	public readonly triggerModifier: TriggerModifier;
	public readonly triggerSideBySideKey: KeyCode;
	public readonly triggerSideBySideModifier: TriggerModifier;

	constructor(
		triggerKey: KeyCode,
		triggerModifier: TriggerModifier,
		triggerSideBySideKey: KeyCode,
		triggerSideBySideModifier: TriggerModifier
	) {
		this.triggerKey = triggerKey;
		this.triggerModifier = triggerModifier;
		this.triggerSideBySideKey = triggerSideBySideKey;
		this.triggerSideBySideModifier = triggerSideBySideModifier;
	}

	public equals(other: ClickLinkOptions): boolean {
		return (
			this.triggerKey === other.triggerKey
			&& this.triggerModifier === other.triggerModifier
			&& this.triggerSideBySideKey === other.triggerSideBySideKey
			&& this.triggerSideBySideModifier === other.triggerSideBySideModifier
		);
	}
}

function createOptions(multiCursorModifier: 'altKey' | 'ctrlKey' | 'metaKey'): ClickLinkOptions {
	if (multiCursorModifier === 'altKey') {
		if (platform.isMacintosh) {
			return new ClickLinkOptions(KeyCode.Meta, 'metaKey', KeyCode.Alt, 'altKey');
		}
		return new ClickLinkOptions(KeyCode.Ctrl, 'ctrlKey', KeyCode.Alt, 'altKey');
	}

	if (platform.isMacintosh) {
		return new ClickLinkOptions(KeyCode.Alt, 'altKey', KeyCode.Meta, 'metaKey');
	}
	return new ClickLinkOptions(KeyCode.Alt, 'altKey', KeyCode.Ctrl, 'ctrlKey');
}

export class ClickLinkGesture extends Disposable {

	private readonly _onMouseMoveOrRelevantKeyDown: Emitter<[ClickLinkMouseEvent, ClickLinkKeyboardEvent | null]> = this._register(new Emitter<[ClickLinkMouseEvent, ClickLinkKeyboardEvent | null]>());
	public readonly onMouseMoveOrRelevantKeyDown: Event<[ClickLinkMouseEvent, ClickLinkKeyboardEvent | null]> = this._onMouseMoveOrRelevantKeyDown.event;

	private readonly _onExecute: Emitter<ClickLinkMouseEvent> = this._register(new Emitter<ClickLinkMouseEvent>());
	public readonly onExecute: Event<ClickLinkMouseEvent> = this._onExecute.event;

	private readonly _onCancel: Emitter<void> = this._register(new Emitter<void>());
	public readonly onCancel: Event<void> = this._onCancel.event;

	private readonly _editor: ICodeEditor;
	private _opts: ClickLinkOptions;

	private lastMouseMoveEvent: ClickLinkMouseEvent | null;
	private hasTriggerKeyOnMouseDown: boolean;

	constructor(editor: ICodeEditor) {
		super();

		this._editor = editor;
		this._opts = createOptions(this._editor.getConfiguration().multiCursorModifier);

		this.lastMouseMoveEvent = null;
		this.hasTriggerKeyOnMouseDown = false;

		this._register(this._editor.onDidChangeConfiguration((e) => {
			if (e.multiCursorModifier) {
				const newOpts = createOptions(this._editor.getConfiguration().multiCursorModifier);
				if (this._opts.equals(newOpts)) {
					return;
				}
				this._opts = newOpts;
				this.lastMouseMoveEvent = null;
				this.hasTriggerKeyOnMouseDown = false;
				this._onCancel.fire();
			}
		}));
		this._register(this._editor.onMouseMove((e: IEditorMouseEvent) => this.onEditorMouseMove(new ClickLinkMouseEvent(e, this._opts))));
		this._register(this._editor.onMouseDown((e: IEditorMouseEvent) => this.onEditorMouseDown(new ClickLinkMouseEvent(e, this._opts))));
		this._register(this._editor.onMouseUp((e: IEditorMouseEvent) => this.onEditorMouseUp(new ClickLinkMouseEvent(e, this._opts))));
		this._register(this._editor.onKeyDown((e: IKeyboardEvent) => this.onEditorKeyDown(new ClickLinkKeyboardEvent(e, this._opts))));
		this._register(this._editor.onKeyUp((e: IKeyboardEvent) => this.onEditorKeyUp(new ClickLinkKeyboardEvent(e, this._opts))));
		this._register(this._editor.onMouseDrag(() => this.resetHandler()));

		this._register(this._editor.onDidChangeCursorSelection((e) => this.onDidChangeCursorSelection(e)));
		this._register(this._editor.onDidChangeModel((e) => this.resetHandler()));
		this._register(this._editor.onDidChangeModelContent(() => this.resetHandler()));
		this._register(this._editor.onDidScrollChange((e) => {
			if (e.scrollTopChanged || e.scrollLeftChanged) {
				this.resetHandler();
			}
		}));
	}

	private onDidChangeCursorSelection(e: ICursorSelectionChangedEvent): void {
		if (e.selection && e.selection.startColumn !== e.selection.endColumn) {
			this.resetHandler(); // immediately stop this feature if the user starts to select (https://github.com/Microsoft/vscode/issues/7827)
		}
	}

	private onEditorMouseMove(mouseEvent: ClickLinkMouseEvent): void {
		this.lastMouseMoveEvent = mouseEvent;

		this._onMouseMoveOrRelevantKeyDown.fire([mouseEvent, null]);
	}

	private onEditorMouseDown(mouseEvent: ClickLinkMouseEvent): void {
		// We need to record if we had the trigger key on mouse down because someone might select something in the editor
		// holding the mouse down and then while mouse is down start to press Ctrl/Cmd to start a copy operation and then
		// release the mouse button without wanting to do the navigation.
		// With this flag we prevent goto definition if the mouse was down before the trigger key was pressed.
		this.hasTriggerKeyOnMouseDown = mouseEvent.hasTriggerModifier;
	}

	private onEditorMouseUp(mouseEvent: ClickLinkMouseEvent): void {
		if (this.hasTriggerKeyOnMouseDown) {
			this._onExecute.fire(mouseEvent);
		}
	}

	private onEditorKeyDown(e: ClickLinkKeyboardEvent): void {
		if (
			this.lastMouseMoveEvent
			&& (
				e.keyCodeIsTriggerKey // User just pressed Ctrl/Cmd (normal goto definition)
				|| (e.keyCodeIsSideBySideKey && e.hasTriggerModifier) // User pressed Ctrl/Cmd+Alt (goto definition to the side)
			)
		) {
			this._onMouseMoveOrRelevantKeyDown.fire([this.lastMouseMoveEvent, e]);
		} else if (e.hasTriggerModifier) {
			this._onCancel.fire(); // remove decorations if user holds another key with ctrl/cmd to prevent accident goto declaration
		}
	}

	private onEditorKeyUp(e: ClickLinkKeyboardEvent): void {
		if (e.keyCodeIsTriggerKey) {
			this._onCancel.fire();
		}
	}

	private resetHandler(): void {
		this.lastMouseMoveEvent = null;
		this.hasTriggerKeyOnMouseDown = false;
		this._onCancel.fire();
	}
}
