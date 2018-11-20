/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import { CancelablePromise, createCancelablePromise, TimeoutTimer } from 'vs/base/common/async';
import { Emitter, Event } from 'vs/base/common/event';
import { dispose, IDisposable } from 'vs/base/common/lifecycle';
import { URI } from 'vs/base/common/uri';
import { ICodeEditor } from 'vs/editor/browser/editorBrowser';
import { Position } from 'vs/editor/common/core/position';
import { Range } from 'vs/editor/common/core/range';
import { Selection } from 'vs/editor/common/core/selection';
import { CodeAction, CodeActionProviderRegistry } from 'vs/editor/common/modes';
import { IContextKey, IContextKeyService, RawContextKey } from 'vs/platform/contextkey/common/contextkey';
import { IMarkerService } from 'vs/platform/markers/common/markers';
import { IProgressService } from 'vs/platform/progress/common/progress';
import { getCodeActions } from './codeAction';
import { CodeActionTrigger } from './codeActionTrigger';

export const SUPPORTED_CODE_ACTIONS = new RawContextKey<string>('supportedCodeAction', '');

export class CodeActionOracle {

	private _disposables: IDisposable[] = [];
	private readonly _autoTriggerTimer = new TimeoutTimer();

	constructor(
		private _editor: ICodeEditor,
		private readonly _markerService: IMarkerService,
		private _signalChange: (e: CodeActionsComputeEvent) => any,
		private readonly _delay: number = 250,
		private readonly _progressService?: IProgressService,
	) {
		this._disposables.push(
			this._markerService.onMarkerChanged(e => this._onMarkerChanges(e)),
			this._editor.onDidChangeCursorPosition(() => this._onCursorChange()),
		);
	}

	dispose(): void {
		this._disposables = dispose(this._disposables);
		this._autoTriggerTimer.cancel();
	}

	trigger(trigger: CodeActionTrigger) {
		const selection = this._getRangeOfSelectionUnlessWhitespaceEnclosed(trigger);
		return this._createEventAndSignalChange(trigger, selection);
	}

	private _onMarkerChanges(resources: URI[]): void {
		const model = this._editor.getModel();
		if (!model) {
			return;
		}

		if (resources.some(resource => resource.toString() === model.uri.toString())) {
			this._autoTriggerTimer.cancelAndSet(() => {
				this.trigger({ type: 'auto' });
			}, this._delay);
		}
	}

	private _onCursorChange(): void {
		this._autoTriggerTimer.cancelAndSet(() => {
			this.trigger({ type: 'auto' });
		}, this._delay);
	}

	private _getRangeOfMarker(selection: Selection): Range | undefined {
		const model = this._editor.getModel();
		if (!model) {
			return undefined;
		}
		for (const marker of this._markerService.read({ resource: model.uri })) {
			if (Range.intersectRanges(marker, selection)) {
				return Range.lift(marker);
			}
		}
		return undefined;
	}

	private _getRangeOfSelectionUnlessWhitespaceEnclosed(trigger: CodeActionTrigger): Selection | undefined {
		if (!this._editor.hasModel()) {
			return undefined;
		}
		const model = this._editor.getModel();
		const selection = this._editor.getSelection();
		if (selection.isEmpty() && trigger.type === 'auto') {
			const { lineNumber, column } = selection.getPosition();
			const line = model.getLineContent(lineNumber);
			if (line.length === 0) {
				// empty line
				return undefined;
			} else if (column === 1) {
				// look only right
				if (/\s/.test(line[0])) {
					return undefined;
				}
			} else if (column === model.getLineMaxColumn(lineNumber)) {
				// look only left
				if (/\s/.test(line[line.length - 1])) {
					return undefined;
				}
			} else {
				// look left and right
				if (/\s/.test(line[column - 2]) && /\s/.test(line[column - 1])) {
					return undefined;
				}
			}
		}
		return selection ? selection : undefined;
	}

	private _createEventAndSignalChange(trigger: CodeActionTrigger, selection: Selection | undefined): Thenable<CodeAction[] | undefined> {
		if (!selection) {
			// cancel
			this._signalChange({
				trigger,
				rangeOrSelection: undefined,
				position: undefined,
				actions: undefined,
			});
			return Promise.resolve(undefined);
		} else {
			const model = this._editor.getModel();
			if (!model) {
				// cancel
				this._signalChange({
					trigger,
					rangeOrSelection: undefined,
					position: undefined,
					actions: undefined,
				});
				return Promise.resolve(undefined);
			}

			const markerRange = this._getRangeOfMarker(selection);
			const position = markerRange ? markerRange.getStartPosition() : selection.getStartPosition();
			const actions = createCancelablePromise(token => getCodeActions(model, selection, trigger, token));

			if (this._progressService && trigger.type === 'manual') {
				this._progressService.showWhile(actions, 250);
			}

			this._signalChange({
				trigger,
				rangeOrSelection: selection,
				position,
				actions
			});
			return actions;
		}
	}
}

export interface CodeActionsComputeEvent {
	trigger: CodeActionTrigger;
	rangeOrSelection: Range | Selection | undefined;
	position: Position | undefined;
	actions: CancelablePromise<CodeAction[]> | undefined;
}

export class CodeActionModel {

	private _editor: ICodeEditor;
	private _markerService: IMarkerService;
	private _codeActionOracle?: CodeActionOracle;
	private _onDidChangeFixes = new Emitter<CodeActionsComputeEvent>();
	private _disposables: IDisposable[] = [];
	private readonly _supportedCodeActions: IContextKey<string>;

	constructor(editor: ICodeEditor, markerService: IMarkerService, contextKeyService: IContextKeyService, private readonly _progressService: IProgressService) {
		this._editor = editor;
		this._markerService = markerService;

		this._supportedCodeActions = SUPPORTED_CODE_ACTIONS.bindTo(contextKeyService);

		this._disposables.push(this._editor.onDidChangeModel(() => this._update()));
		this._disposables.push(this._editor.onDidChangeModelLanguage(() => this._update()));
		this._disposables.push(CodeActionProviderRegistry.onDidChange(this._update, this));

		this._update();
	}

	dispose(): void {
		this._disposables = dispose(this._disposables);
		dispose(this._codeActionOracle);
	}

	get onDidChangeFixes(): Event<CodeActionsComputeEvent> {
		return this._onDidChangeFixes.event;
	}

	private _update(): void {

		if (this._codeActionOracle) {
			this._codeActionOracle.dispose();
			this._codeActionOracle = undefined;
			this._onDidChangeFixes.fire(undefined);
		}

		const model = this._editor.getModel();
		if (model
			&& CodeActionProviderRegistry.has(model)
			&& !this._editor.getConfiguration().readOnly) {

			const supportedActions: string[] = [];
			for (const provider of CodeActionProviderRegistry.all(model)) {
				if (Array.isArray(provider.providedCodeActionKinds)) {
					supportedActions.push(...provider.providedCodeActionKinds);
				}
			}

			this._supportedCodeActions.set(supportedActions.join(' '));

			this._codeActionOracle = new CodeActionOracle(this._editor, this._markerService, p => this._onDidChangeFixes.fire(p), undefined, this._progressService);
			this._codeActionOracle.trigger({ type: 'auto' });
		} else {
			this._supportedCodeActions.reset();
		}
	}

	trigger(trigger: CodeActionTrigger): Thenable<CodeAction[] | undefined> {
		if (this._codeActionOracle) {
			return this._codeActionOracle.trigger(trigger);
		}
		return Promise.resolve(undefined);
	}
}
