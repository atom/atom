/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import { KeyCode, KeyMod } from 'vs/base/common/keyCodes';
import { dispose, IDisposable } from 'vs/base/common/lifecycle';
import { repeat } from 'vs/base/common/strings';
import { ICodeEditor } from 'vs/editor/browser/editorBrowser';
import { EditorCommand, registerEditorCommand, registerEditorContribution } from 'vs/editor/browser/editorExtensions';
import { Range } from 'vs/editor/common/core/range';
import { Selection } from 'vs/editor/common/core/selection';
import { IEditorContribution } from 'vs/editor/common/editorCommon';
import { EditorContextKeys } from 'vs/editor/common/editorContextKeys';
import { CompletionItem, CompletionItemKind } from 'vs/editor/common/modes';
import { Choice } from 'vs/editor/contrib/snippet/snippetParser';
import { showSimpleSuggestions } from 'vs/editor/contrib/suggest/suggest';
import { ContextKeyExpr, IContextKey, IContextKeyService, RawContextKey } from 'vs/platform/contextkey/common/contextkey';
import { KeybindingWeight } from 'vs/platform/keybinding/common/keybindingsRegistry';
import { ILogService } from 'vs/platform/log/common/log';
import { SnippetSession } from './snippetSession';

export class SnippetController2 implements IEditorContribution {

	static get(editor: ICodeEditor): SnippetController2 {
		return editor.getContribution<SnippetController2>('snippetController2');
	}

	static InSnippetMode = new RawContextKey('inSnippetMode', false);
	static HasNextTabstop = new RawContextKey('hasNextTabstop', false);
	static HasPrevTabstop = new RawContextKey('hasPrevTabstop', false);

	private readonly _inSnippet: IContextKey<boolean>;
	private readonly _hasNextTabstop: IContextKey<boolean>;
	private readonly _hasPrevTabstop: IContextKey<boolean>;

	private _session: SnippetSession;
	private _snippetListener: IDisposable[] = [];
	private _modelVersionId: number;
	private _currentChoice: Choice;

	constructor(
		private readonly _editor: ICodeEditor,
		@ILogService private readonly _logService: ILogService,
		@IContextKeyService contextKeyService: IContextKeyService
	) {
		this._inSnippet = SnippetController2.InSnippetMode.bindTo(contextKeyService);
		this._hasNextTabstop = SnippetController2.HasNextTabstop.bindTo(contextKeyService);
		this._hasPrevTabstop = SnippetController2.HasPrevTabstop.bindTo(contextKeyService);
	}

	dispose(): void {
		this._inSnippet.reset();
		this._hasPrevTabstop.reset();
		this._hasNextTabstop.reset();
		dispose(this._session);
	}

	getId(): string {
		return 'snippetController2';
	}

	insert(
		template: string,
		overwriteBefore: number = 0, overwriteAfter: number = 0,
		undoStopBefore: boolean = true, undoStopAfter: boolean = true,
		adjustWhitespace: boolean = true,
	): void {
		// this is here to find out more about the yet-not-understood
		// error that sometimes happens when we fail to inserted a nested
		// snippet
		try {
			this._doInsert(template, overwriteBefore, overwriteAfter, undoStopBefore, undoStopAfter, adjustWhitespace);

		} catch (e) {
			this.cancel();
			this._logService.error(e);
			this._logService.error('snippet_error');
			this._logService.error('insert_template=', template);
			this._logService.error('existing_template=', this._session ? this._session._logInfo() : '<no_session>');
		}
	}

	private _doInsert(
		template: string,
		overwriteBefore: number = 0, overwriteAfter: number = 0,
		undoStopBefore: boolean = true, undoStopAfter: boolean = true,
		adjustWhitespace: boolean = true,
	): void {

		// don't listen while inserting the snippet
		// as that is the inflight state causing cancelation
		this._snippetListener = dispose(this._snippetListener);

		if (undoStopBefore) {
			this._editor.getModel().pushStackElement();
		}

		if (!this._session) {
			this._modelVersionId = this._editor.getModel().getAlternativeVersionId();
			this._session = new SnippetSession(this._editor, template, overwriteBefore, overwriteAfter, adjustWhitespace);
			this._session.insert();
		} else {
			this._session.merge(template, overwriteBefore, overwriteAfter, adjustWhitespace);
		}

		if (undoStopAfter) {
			this._editor.getModel().pushStackElement();
		}

		this._updateState();

		this._snippetListener = [
			this._editor.onDidChangeModelContent(e => e.isFlush && this.cancel()),
			this._editor.onDidChangeModel(() => this.cancel()),
			this._editor.onDidChangeCursorSelection(() => this._updateState())
		];
	}

	private _updateState(): void {
		if (!this._session) {
			// canceled in the meanwhile
			return;
		}

		if (this._modelVersionId === this._editor.getModel().getAlternativeVersionId()) {
			// undo until the 'before' state happened
			// and makes use cancel snippet mode
			return this.cancel();
		}

		if (!this._session.hasPlaceholder) {
			// don't listen for selection changes and don't
			// update context keys when the snippet is plain text
			return this.cancel();
		}

		if (this._session.isAtLastPlaceholder || !this._session.isSelectionWithinPlaceholders()) {
			return this.cancel();
		}

		this._inSnippet.set(true);
		this._hasPrevTabstop.set(!this._session.isAtFirstPlaceholder);
		this._hasNextTabstop.set(!this._session.isAtLastPlaceholder);

		this._handleChoice();
	}

	private _handleChoice(): void {
		const { choice } = this._session;
		if (!choice) {
			this._currentChoice = undefined;
			return;
		}
		if (this._currentChoice !== choice) {
			this._currentChoice = choice;

			this._editor.setSelections(this._editor.getSelections()
				.map(s => Selection.fromPositions(s.getStartPosition()))
			);

			const [first] = choice.options;

			showSimpleSuggestions(this._editor, choice.options.map((option, i) => {

				// let before = choice.options.slice(0, i);
				// let after = choice.options.slice(i);

				return <CompletionItem>{
					kind: CompletionItemKind.Value,
					label: option.value,
					insertText: option.value,
					// insertText: `\${1|${after.concat(before).join(',')}|}$0`,
					// snippetType: 'textmate',
					sortText: repeat('a', i),
					range: Range.fromPositions(this._editor.getPosition(), this._editor.getPosition().delta(0, first.value.length))
				};
			}));
		}
	}

	finish(): void {
		while (this._inSnippet.get()) {
			this.next();
		}
	}

	cancel(): void {
		this._inSnippet.reset();
		this._hasPrevTabstop.reset();
		this._hasNextTabstop.reset();
		dispose(this._snippetListener);
		dispose(this._session);
		this._session = undefined;
		this._modelVersionId = -1;
	}

	prev(): void {
		this._session.prev();
		this._updateState();
	}

	next(): void {
		this._session.next();
		this._updateState();
	}

	isInSnippet(): boolean {
		return this._inSnippet.get();
	}

	getSessionEnclosingRange(): Range {
		if (this._session) {
			return this._session.getEnclosingRange();
		}
		return undefined;
	}
}


registerEditorContribution(SnippetController2);

const CommandCtor = EditorCommand.bindToContribution<SnippetController2>(SnippetController2.get);

registerEditorCommand(new CommandCtor({
	id: 'jumpToNextSnippetPlaceholder',
	precondition: ContextKeyExpr.and(SnippetController2.InSnippetMode, SnippetController2.HasNextTabstop),
	handler: ctrl => ctrl.next(),
	kbOpts: {
		weight: KeybindingWeight.EditorContrib + 30,
		kbExpr: EditorContextKeys.editorTextFocus,
		primary: KeyCode.Tab
	}
}));
registerEditorCommand(new CommandCtor({
	id: 'jumpToPrevSnippetPlaceholder',
	precondition: ContextKeyExpr.and(SnippetController2.InSnippetMode, SnippetController2.HasPrevTabstop),
	handler: ctrl => ctrl.prev(),
	kbOpts: {
		weight: KeybindingWeight.EditorContrib + 30,
		kbExpr: EditorContextKeys.editorTextFocus,
		primary: KeyMod.Shift | KeyCode.Tab
	}
}));
registerEditorCommand(new CommandCtor({
	id: 'leaveSnippet',
	precondition: SnippetController2.InSnippetMode,
	handler: ctrl => ctrl.cancel(),
	kbOpts: {
		weight: KeybindingWeight.EditorContrib + 30,
		kbExpr: EditorContextKeys.editorTextFocus,
		primary: KeyCode.Escape,
		secondary: [KeyMod.Shift | KeyCode.Escape]
	}
}));

registerEditorCommand(new CommandCtor({
	id: 'acceptSnippet',
	precondition: SnippetController2.InSnippetMode,
	handler: ctrl => ctrl.finish(),
	// kbOpts: {
	// 	weight: KeybindingWeight.EditorContrib + 30,
	// 	kbExpr: EditorContextKeys.textFocus,
	// 	primary: KeyCode.Enter,
	// }
}));
