/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import { alert } from 'vs/base/browser/ui/aria/aria';
import { createCancelablePromise } from 'vs/base/common/async';
import { CancellationToken } from 'vs/base/common/cancellation';
import { KeyChord, KeyCode, KeyMod } from 'vs/base/common/keyCodes';
import * as platform from 'vs/base/common/platform';
import { ICodeEditor } from 'vs/editor/browser/editorBrowser';
import { EditorAction, IActionOptions, registerEditorAction, ServicesAccessor } from 'vs/editor/browser/editorExtensions';
import { ICodeEditorService } from 'vs/editor/browser/services/codeEditorService';
import * as corePosition from 'vs/editor/common/core/position';
import { Range } from 'vs/editor/common/core/range';
import { EditorContextKeys } from 'vs/editor/common/editorContextKeys';
import { ITextModel, IWordAtPosition } from 'vs/editor/common/model';
import { DefinitionLink, Location } from 'vs/editor/common/modes';
import { MessageController } from 'vs/editor/contrib/message/messageController';
import { PeekContext } from 'vs/editor/contrib/referenceSearch/peekViewWidget';
import { ReferencesController } from 'vs/editor/contrib/referenceSearch/referencesController';
import { ReferencesModel } from 'vs/editor/contrib/referenceSearch/referencesModel';
import * as nls from 'vs/nls';
import { MenuId, MenuRegistry } from 'vs/platform/actions/common/actions';
import { ContextKeyExpr } from 'vs/platform/contextkey/common/contextkey';
import { KeybindingWeight } from 'vs/platform/keybinding/common/keybindingsRegistry';
import { INotificationService } from 'vs/platform/notification/common/notification';
import { IProgressService } from 'vs/platform/progress/common/progress';
import { getDefinitionsAtPosition, getImplementationsAtPosition, getTypeDefinitionsAtPosition, getDeclarationsAtPosition } from './goToDefinition';


export class DefinitionActionConfig {

	constructor(
		public readonly openToSide = false,
		public readonly openInPeek = false,
		public readonly filterCurrent = true,
		public readonly showMessage = true,
	) {
		//
	}
}

export class DefinitionAction extends EditorAction {

	private _configuration: DefinitionActionConfig;

	constructor(configuration: DefinitionActionConfig, opts: IActionOptions) {
		super(opts);
		this._configuration = configuration;
	}

	public run(accessor: ServicesAccessor, editor: ICodeEditor): Thenable<void> {
		const notificationService = accessor.get(INotificationService);
		const editorService = accessor.get(ICodeEditorService);
		const progressService = accessor.get(IProgressService);

		const model = editor.getModel();
		const pos = editor.getPosition();

		const definitionPromise = this._getTargetLocationForPosition(model, pos, CancellationToken.None).then(references => {

			if (model.isDisposed() || editor.getModel() !== model) {
				// new model, no more model
				return;
			}

			// * remove falsy references
			// * find reference at the current pos
			let idxOfCurrent = -1;
			const result: DefinitionLink[] = [];
			for (let i = 0; i < references.length; i++) {
				let reference = references[i];
				if (!reference || !reference.range) {
					continue;
				}
				let { uri, range } = reference;
				let newLen = result.push({
					uri,
					range
				});
				if (this._configuration.filterCurrent
					&& uri.toString() === model.uri.toString()
					&& Range.containsPosition(range, pos)
					&& idxOfCurrent === -1
				) {
					idxOfCurrent = newLen - 1;
				}
			}

			if (result.length === 0) {
				// no result -> show message
				if (this._configuration.showMessage) {
					const info = model.getWordAtPosition(pos);
					MessageController.get(editor).showMessage(this._getNoResultFoundMessage(info), pos);
				}
			} else if (result.length === 1 && idxOfCurrent !== -1) {
				// only the position at which we are -> adjust selection
				let [current] = result;
				this._openReference(editor, editorService, current, false);

			} else {
				// handle multile results
				this._onResult(editorService, editor, new ReferencesModel(result));
			}

		}, (err) => {
			// report an error
			notificationService.error(err);
		});

		progressService.showWhile(definitionPromise, 250);
		return definitionPromise;
	}

	protected _getTargetLocationForPosition(model: ITextModel, position: corePosition.Position, token: CancellationToken): Thenable<DefinitionLink[]> {
		return getDefinitionsAtPosition(model, position, token);
	}

	protected _getNoResultFoundMessage(info?: IWordAtPosition): string {
		return info && info.word
			? nls.localize('noResultWord', "No definition found for '{0}'", info.word)
			: nls.localize('generic.noResults', "No definition found");
	}

	protected _getMetaTitle(model: ReferencesModel): string {
		return model.references.length > 1 && nls.localize('meta.title', " – {0} definitions", model.references.length);
	}

	private _onResult(editorService: ICodeEditorService, editor: ICodeEditor, model: ReferencesModel) {

		const msg = model.getAriaMessage();
		alert(msg);

		if (this._configuration.openInPeek) {
			this._openInPeek(editorService, editor, model);
		} else {
			let next = model.nearestReference(editor.getModel().uri, editor.getPosition());
			this._openReference(editor, editorService, next, this._configuration.openToSide).then(editor => {
				if (editor && model.references.length > 1) {
					this._openInPeek(editorService, editor, model);
				} else {
					model.dispose();
				}
			});
		}
	}

	private _openReference(editor: ICodeEditor, editorService: ICodeEditorService, reference: Location, sideBySide: boolean): Thenable<ICodeEditor> {
		return editorService.openCodeEditor({
			resource: reference.uri,
			options: {
				selection: Range.collapseToStart(reference.range),
				revealIfOpened: true,
				revealInCenterIfOutsideViewport: true
			}
		}, editor, sideBySide);
	}

	private _openInPeek(editorService: ICodeEditorService, target: ICodeEditor, model: ReferencesModel) {
		let controller = ReferencesController.get(target);
		if (controller) {
			controller.toggleWidget(target.getSelection(), createCancelablePromise(_ => Promise.resolve(model)), {
				getMetaTitle: (model) => {
					return this._getMetaTitle(model);
				},
				onGoto: (reference) => {
					controller.closeWidget();
					return this._openReference(target, editorService, reference, false);
				}
			});
		} else {
			model.dispose();
		}
	}
}

const goToDeclarationKb = platform.isWeb
	? KeyMod.CtrlCmd | KeyCode.F12
	: KeyCode.F12;

export class GoToDefinitionAction extends DefinitionAction {

	public static readonly ID = 'editor.action.goToDeclaration';

	constructor() {
		super(new DefinitionActionConfig(), {
			id: GoToDefinitionAction.ID,
			label: nls.localize('actions.goToDecl.label', "Go to Definition"),
			alias: 'Go to Definition',
			precondition: ContextKeyExpr.and(
				EditorContextKeys.hasDefinitionProvider,
				EditorContextKeys.isInEmbeddedEditor.toNegated()),
			kbOpts: {
				kbExpr: EditorContextKeys.editorTextFocus,
				primary: goToDeclarationKb,
				weight: KeybindingWeight.EditorContrib
			},
			menuOpts: {
				group: 'navigation',
				order: 1.1
			}
		});
	}
}

export class OpenDefinitionToSideAction extends DefinitionAction {

	public static readonly ID = 'editor.action.openDeclarationToTheSide';

	constructor() {
		super(new DefinitionActionConfig(true), {
			id: OpenDefinitionToSideAction.ID,
			label: nls.localize('actions.goToDeclToSide.label', "Open Definition to the Side"),
			alias: 'Open Definition to the Side',
			precondition: ContextKeyExpr.and(
				EditorContextKeys.hasDefinitionProvider,
				EditorContextKeys.isInEmbeddedEditor.toNegated()),
			kbOpts: {
				kbExpr: EditorContextKeys.editorTextFocus,
				primary: KeyChord(KeyMod.CtrlCmd | KeyCode.KEY_K, goToDeclarationKb),
				weight: KeybindingWeight.EditorContrib
			}
		});
	}
}

export class PeekDefinitionAction extends DefinitionAction {
	constructor() {
		super(new DefinitionActionConfig(void 0, true, false), {
			id: 'editor.action.previewDeclaration',
			label: nls.localize('actions.previewDecl.label', "Peek Definition"),
			alias: 'Peek Definition',
			precondition: ContextKeyExpr.and(
				EditorContextKeys.hasDefinitionProvider,
				PeekContext.notInPeekEditor,
				EditorContextKeys.isInEmbeddedEditor.toNegated()),
			kbOpts: {
				kbExpr: EditorContextKeys.editorTextFocus,
				primary: KeyMod.Alt | KeyCode.F12,
				linux: { primary: KeyMod.CtrlCmd | KeyMod.Shift | KeyCode.F10 },
				weight: KeybindingWeight.EditorContrib
			},
			menuOpts: {
				group: 'navigation',
				order: 1.2
			}
		});
	}
}

export class DeclarationAction extends DefinitionAction {

	protected _getTargetLocationForPosition(model: ITextModel, position: corePosition.Position, token: CancellationToken): Thenable<DefinitionLink[]> {
		return getDeclarationsAtPosition(model, position, token);
	}

	protected _getNoResultFoundMessage(info?: IWordAtPosition): string {
		return info && info.word
			? nls.localize('decl.noResultWord', "No declaration found for '{0}'", info.word)
			: nls.localize('decl.generic.noResults', "No declaration found");
	}

	protected _getMetaTitle(model: ReferencesModel): string {
		return model.references.length > 1 && nls.localize('decl.meta.title', " – {0} declarations", model.references.length);
	}
}

export class GoToDeclarationAction extends DeclarationAction {

	public static readonly ID = 'editor.action.goToRealDeclaration';

	constructor() {
		super(new DefinitionActionConfig(), {
			id: GoToDeclarationAction.ID,
			label: nls.localize('actions.goToDeclaration.label', "Go to Declaration"),
			alias: 'Go to Declaration',
			precondition: ContextKeyExpr.and(
				EditorContextKeys.hasDeclarationProvider,
				EditorContextKeys.isInEmbeddedEditor.toNegated()),
			kbOpts: {
				kbExpr: EditorContextKeys.editorTextFocus,
				primary: KeyMod.CtrlCmd | KeyCode.F12,
				weight: KeybindingWeight.EditorContrib
			},
			menuOpts: {
				group: 'navigation',
				order: 1.3
			}
		});
	}

	protected _getNoResultFoundMessage(info?: IWordAtPosition): string {
		return info && info.word
			? nls.localize('decl.noResultWord', "No declaration found for '{0}'", info.word)
			: nls.localize('decl.generic.noResults', "No declaration found");
	}

	protected _getMetaTitle(model: ReferencesModel): string {
		return model.references.length > 1 && nls.localize('decl.meta.title', " – {0} declarations", model.references.length);
	}
}

export class PeekDeclarationAction extends DeclarationAction {
	constructor() {
		super(new DefinitionActionConfig(void 0, true, false), {
			id: 'editor.action.peekDeclaration',
			label: nls.localize('actions.peekDecl.label', "Peek Declaration"),
			alias: 'Peek Declaration',
			precondition: ContextKeyExpr.and(
				EditorContextKeys.hasDeclarationProvider,
				PeekContext.notInPeekEditor,
				EditorContextKeys.isInEmbeddedEditor.toNegated()),
			kbOpts: {
				kbExpr: EditorContextKeys.editorTextFocus,
				primary: KeyMod.Alt | KeyCode.F12,
				linux: { primary: KeyMod.CtrlCmd | KeyMod.Shift | KeyCode.F10 },
				weight: KeybindingWeight.EditorContrib
			},
			menuOpts: {
				group: 'navigation',
				order: 1.31
			}
		});
	}
}

export class ImplementationAction extends DefinitionAction {
	protected _getTargetLocationForPosition(model: ITextModel, position: corePosition.Position, token: CancellationToken): Thenable<DefinitionLink[]> {
		return getImplementationsAtPosition(model, position, token);
	}

	protected _getNoResultFoundMessage(info?: IWordAtPosition): string {
		return info && info.word
			? nls.localize('goToImplementation.noResultWord', "No implementation found for '{0}'", info.word)
			: nls.localize('goToImplementation.generic.noResults', "No implementation found");
	}

	protected _getMetaTitle(model: ReferencesModel): string {
		return model.references.length > 1 && nls.localize('meta.implementations.title', " – {0} implementations", model.references.length);
	}
}

export class GoToImplementationAction extends ImplementationAction {

	public static readonly ID = 'editor.action.goToImplementation';

	constructor() {
		super(new DefinitionActionConfig(), {
			id: GoToImplementationAction.ID,
			label: nls.localize('actions.goToImplementation.label', "Go to Implementation"),
			alias: 'Go to Implementation',
			precondition: ContextKeyExpr.and(
				EditorContextKeys.hasImplementationProvider,
				EditorContextKeys.isInEmbeddedEditor.toNegated()),
			kbOpts: {
				kbExpr: EditorContextKeys.editorTextFocus,
				primary: KeyMod.CtrlCmd | KeyCode.F12,
				weight: KeybindingWeight.EditorContrib
			}
		});
	}
}

export class PeekImplementationAction extends ImplementationAction {

	public static readonly ID = 'editor.action.peekImplementation';

	constructor() {
		super(new DefinitionActionConfig(false, true, false), {
			id: PeekImplementationAction.ID,
			label: nls.localize('actions.peekImplementation.label', "Peek Implementation"),
			alias: 'Peek Implementation',
			precondition: ContextKeyExpr.and(
				EditorContextKeys.hasImplementationProvider,
				EditorContextKeys.isInEmbeddedEditor.toNegated()),
			kbOpts: {
				kbExpr: EditorContextKeys.editorTextFocus,
				primary: KeyMod.CtrlCmd | KeyMod.Shift | KeyCode.F12,
				weight: KeybindingWeight.EditorContrib
			}
		});
	}
}

export class TypeDefinitionAction extends DefinitionAction {
	protected _getTargetLocationForPosition(model: ITextModel, position: corePosition.Position, token: CancellationToken): Thenable<DefinitionLink[]> {
		return getTypeDefinitionsAtPosition(model, position, token);
	}

	protected _getNoResultFoundMessage(info?: IWordAtPosition): string {
		return info && info.word
			? nls.localize('goToTypeDefinition.noResultWord', "No type definition found for '{0}'", info.word)
			: nls.localize('goToTypeDefinition.generic.noResults', "No type definition found");
	}

	protected _getMetaTitle(model: ReferencesModel): string {
		return model.references.length > 1 && nls.localize('meta.typeDefinitions.title', " – {0} type definitions", model.references.length);
	}
}

export class GoToTypeDefinitionAction extends TypeDefinitionAction {

	public static readonly ID = 'editor.action.goToTypeDefinition';

	constructor() {
		super(new DefinitionActionConfig(), {
			id: GoToTypeDefinitionAction.ID,
			label: nls.localize('actions.goToTypeDefinition.label', "Go to Type Definition"),
			alias: 'Go to Type Definition',
			precondition: ContextKeyExpr.and(
				EditorContextKeys.hasTypeDefinitionProvider,
				EditorContextKeys.isInEmbeddedEditor.toNegated()),
			kbOpts: {
				kbExpr: EditorContextKeys.editorTextFocus,
				primary: 0,
				weight: KeybindingWeight.EditorContrib
			},
			menuOpts: {
				group: 'navigation',
				order: 1.4
			}
		});
	}
}

export class PeekTypeDefinitionAction extends TypeDefinitionAction {

	public static readonly ID = 'editor.action.peekTypeDefinition';

	constructor() {
		super(new DefinitionActionConfig(false, true, false), {
			id: PeekTypeDefinitionAction.ID,
			label: nls.localize('actions.peekTypeDefinition.label', "Peek Type Definition"),
			alias: 'Peek Type Definition',
			precondition: ContextKeyExpr.and(
				EditorContextKeys.hasTypeDefinitionProvider,
				EditorContextKeys.isInEmbeddedEditor.toNegated()),
			kbOpts: {
				kbExpr: EditorContextKeys.editorTextFocus,
				primary: 0,
				weight: KeybindingWeight.EditorContrib
			}
		});
	}
}

registerEditorAction(GoToDefinitionAction);
registerEditorAction(OpenDefinitionToSideAction);
registerEditorAction(PeekDefinitionAction);
registerEditorAction(GoToDeclarationAction);
registerEditorAction(PeekDeclarationAction);
registerEditorAction(GoToImplementationAction);
registerEditorAction(PeekImplementationAction);
registerEditorAction(GoToTypeDefinitionAction);
registerEditorAction(PeekTypeDefinitionAction);

// Go to menu
MenuRegistry.appendMenuItem(MenuId.MenubarGoMenu, {
	group: 'z_go_to',
	command: {
		id: 'editor.action.goToDeclaration',
		title: nls.localize({ key: 'miGotoDefinition', comment: ['&& denotes a mnemonic'] }, "Go to &&Definition")
	},
	order: 4
});

MenuRegistry.appendMenuItem(MenuId.MenubarGoMenu, {
	group: 'z_go_to',
	command: {
		id: 'editor.action.goToTypeDefinition',
		title: nls.localize({ key: 'miGotoTypeDefinition', comment: ['&& denotes a mnemonic'] }, "Go to &&Type Definition")
	},
	order: 5
});

MenuRegistry.appendMenuItem(MenuId.MenubarGoMenu, {
	group: 'z_go_to',
	command: {
		id: 'editor.action.goToImplementation',
		title: nls.localize({ key: 'miGotoImplementation', comment: ['&& denotes a mnemonic'] }, "Go to &&Implementation")
	},
	order: 6
});
