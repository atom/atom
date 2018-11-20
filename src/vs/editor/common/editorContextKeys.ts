/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import { ContextKeyExpr, RawContextKey } from 'vs/platform/contextkey/common/contextkey';

export namespace EditorContextKeys {
	/**
	 * A context key that is set when the editor's text has focus (cursor is blinking).
	 */
	export const editorTextFocus = new RawContextKey<boolean>('editorTextFocus', false);
	/**
	 * A context key that is set when the editor's text or an editor's widget has focus.
	 */
	export const focus = new RawContextKey<boolean>('editorFocus', false);

	/**
	 * A context key that is set when any editor input has focus (regular editor, repl input...).
	 */
	export const textInputFocus = new RawContextKey<boolean>('textInputFocus', false);

	export const readOnly = new RawContextKey<boolean>('editorReadonly', false);
	export const writable: ContextKeyExpr = readOnly.toNegated();
	export const hasNonEmptySelection = new RawContextKey<boolean>('editorHasSelection', false);
	export const hasOnlyEmptySelection: ContextKeyExpr = hasNonEmptySelection.toNegated();
	export const hasMultipleSelections = new RawContextKey<boolean>('editorHasMultipleSelections', false);
	export const hasSingleSelection: ContextKeyExpr = hasMultipleSelections.toNegated();
	export const tabMovesFocus = new RawContextKey<boolean>('editorTabMovesFocus', false);
	export const tabDoesNotMoveFocus: ContextKeyExpr = tabMovesFocus.toNegated();
	export const isInEmbeddedEditor = new RawContextKey<boolean>('isInEmbeddedEditor', false);
	export const canUndo = new RawContextKey<boolean>('canUndo', false);
	export const canRedo = new RawContextKey<boolean>('canRedo', false);

	// -- mode context keys
	export const languageId = new RawContextKey<string>('editorLangId', '');
	export const hasCompletionItemProvider = new RawContextKey<boolean>('editorHasCompletionItemProvider', false);
	export const hasCodeActionsProvider = new RawContextKey<boolean>('editorHasCodeActionsProvider', false);
	export const hasCodeLensProvider = new RawContextKey<boolean>('editorHasCodeLensProvider', false);
	export const hasDefinitionProvider = new RawContextKey<boolean>('editorHasDefinitionProvider', false);
	export const hasDeclarationProvider = new RawContextKey<boolean>('editorHasDeclarationProvider', false);
	export const hasImplementationProvider = new RawContextKey<boolean>('editorHasImplementationProvider', false);
	export const hasTypeDefinitionProvider = new RawContextKey<boolean>('editorHasTypeDefinitionProvider', false);
	export const hasHoverProvider = new RawContextKey<boolean>('editorHasHoverProvider', false);
	export const hasDocumentHighlightProvider = new RawContextKey<boolean>('editorHasDocumentHighlightProvider', false);
	export const hasDocumentSymbolProvider = new RawContextKey<boolean>('editorHasDocumentSymbolProvider', false);
	export const hasReferenceProvider = new RawContextKey<boolean>('editorHasReferenceProvider', false);
	export const hasRenameProvider = new RawContextKey<boolean>('editorHasRenameProvider', false);
	export const hasDocumentFormattingProvider = new RawContextKey<boolean>('editorHasDocumentFormattingProvider', false);
	export const hasDocumentSelectionFormattingProvider = new RawContextKey<boolean>('editorHasDocumentSelectionFormattingProvider', false);
	export const hasSignatureHelpProvider = new RawContextKey<boolean>('editorHasSignatureHelpProvider', false);
}
