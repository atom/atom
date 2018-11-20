/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as nls from 'vs/nls';
import { KeyMod, KeyChord, KeyCode } from 'vs/base/common/keyCodes';
import { Range } from 'vs/editor/common/core/range';
import { EditorContextKeys } from 'vs/editor/common/editorContextKeys';
import { ServicesAccessor, registerEditorAction, EditorAction, IActionOptions } from 'vs/editor/browser/editorExtensions';
import { ContextKeyExpr } from 'vs/platform/contextkey/common/contextkey';
import { IDebugService, CONTEXT_IN_DEBUG_MODE, CONTEXT_DEBUG_STATE, State, REPL_ID, VIEWLET_ID, IDebugEditorContribution, EDITOR_CONTRIBUTION_ID, BreakpointWidgetContext, IBreakpoint } from 'vs/workbench/parts/debug/common/debug';
import { IPanelService } from 'vs/workbench/services/panel/common/panelService';
import { IViewletService } from 'vs/workbench/services/viewlet/browser/viewlet';
import { ICodeEditor } from 'vs/editor/browser/editorBrowser';
import { IEditorService } from 'vs/workbench/services/editor/common/editorService';
import { openBreakpointSource } from 'vs/workbench/parts/debug/browser/breakpointsView';
import { KeybindingWeight } from 'vs/platform/keybinding/common/keybindingsRegistry';
import { PanelFocusContext } from 'vs/workbench/browser/parts/panel/panelPart';
import { MenuRegistry, MenuId } from 'vs/platform/actions/common/actions';

export const TOGGLE_BREAKPOINT_ID = 'editor.debug.action.toggleBreakpoint';
class ToggleBreakpointAction extends EditorAction {
	constructor() {
		super({
			id: TOGGLE_BREAKPOINT_ID,
			label: nls.localize('toggleBreakpointAction', "Debug: Toggle Breakpoint"),
			alias: 'Debug: Toggle Breakpoint',
			precondition: null,
			kbOpts: {
				kbExpr: EditorContextKeys.editorTextFocus,
				primary: KeyCode.F9,
				weight: KeybindingWeight.EditorContrib
			}
		});
	}

	public run(accessor: ServicesAccessor, editor: ICodeEditor): Promise<any> {
		const debugService = accessor.get(IDebugService);

		const position = editor.getPosition();
		const modelUri = editor.getModel().uri;
		const bps = debugService.getModel().getBreakpoints({ lineNumber: position.lineNumber, uri: modelUri });

		if (bps.length) {
			return Promise.all(bps.map(bp => debugService.removeBreakpoints(bp.getId())));
		}
		if (debugService.getConfigurationManager().canSetBreakpointsIn(editor.getModel())) {
			return debugService.addBreakpoints(modelUri, [{ lineNumber: position.lineNumber }], 'debugEditorActions.toggleBreakpointAction');
		}

		return Promise.resolve(null);
	}
}

export const TOGGLE_CONDITIONAL_BREAKPOINT_ID = 'editor.debug.action.conditionalBreakpoint';
class ConditionalBreakpointAction extends EditorAction {

	constructor() {
		super({
			id: TOGGLE_CONDITIONAL_BREAKPOINT_ID,
			label: nls.localize('conditionalBreakpointEditorAction', "Debug: Add Conditional Breakpoint..."),
			alias: 'Debug: Add Conditional Breakpoint...',
			precondition: null
		});
	}

	public run(accessor: ServicesAccessor, editor: ICodeEditor): void {
		const debugService = accessor.get(IDebugService);

		const { lineNumber, column } = editor.getPosition();
		if (debugService.getConfigurationManager().canSetBreakpointsIn(editor.getModel())) {
			editor.getContribution<IDebugEditorContribution>(EDITOR_CONTRIBUTION_ID).showBreakpointWidget(lineNumber, column);
		}
	}
}

export const TOGGLE_LOG_POINT_ID = 'editor.debug.action.toggleLogPoint';
class LogPointAction extends EditorAction {

	constructor() {
		super({
			id: TOGGLE_LOG_POINT_ID,
			label: nls.localize('logPointEditorAction', "Debug: Add Logpoint..."),
			alias: 'Debug: Add Logpoint...',
			precondition: null
		});
	}

	public run(accessor: ServicesAccessor, editor: ICodeEditor): void {
		const debugService = accessor.get(IDebugService);

		const { lineNumber, column } = editor.getPosition();
		if (debugService.getConfigurationManager().canSetBreakpointsIn(editor.getModel())) {
			editor.getContribution<IDebugEditorContribution>(EDITOR_CONTRIBUTION_ID).showBreakpointWidget(lineNumber, column, BreakpointWidgetContext.LOG_MESSAGE);
		}
	}
}

class RunToCursorAction extends EditorAction {

	public static ID = 'editor.debug.action.runToCursor';
	public static LABEL = nls.localize('runToCursor', "Run to Cursor");

	constructor() {
		super({
			id: RunToCursorAction.ID,
			label: RunToCursorAction.LABEL,
			alias: 'Debug: Run to Cursor',
			precondition: ContextKeyExpr.and(CONTEXT_IN_DEBUG_MODE, PanelFocusContext.toNegated(), CONTEXT_DEBUG_STATE.isEqualTo('stopped'), EditorContextKeys.editorTextFocus),
			menuOpts: {
				group: 'debug',
				order: 2
			}
		});
	}

	public run(accessor: ServicesAccessor, editor: ICodeEditor): Promise<void> {
		const debugService = accessor.get(IDebugService);
		const focusedSession = debugService.getViewModel().focusedSession;
		if (debugService.state !== State.Stopped || !focusedSession) {
			return Promise.resolve(null);
		}

		let breakpointToRemove: IBreakpoint;
		const oneTimeListener = focusedSession.onDidChangeState(() => {
			const state = focusedSession.state;
			if (state === State.Stopped || state === State.Inactive) {
				if (breakpointToRemove) {
					debugService.removeBreakpoints(breakpointToRemove.getId());
				}
				oneTimeListener.dispose();
			}
		});

		const position = editor.getPosition();
		const uri = editor.getModel().uri;
		const bpExists = !!(debugService.getModel().getBreakpoints({ column: position.column, lineNumber: position.lineNumber, uri }).length);
		return (bpExists ? Promise.resolve(null) : <Promise<any>>debugService.addBreakpoints(uri, [{ lineNumber: position.lineNumber, column: position.column }], 'debugEditorActions.runToCursorAction')).then((breakpoints) => {
			if (breakpoints && breakpoints.length) {
				breakpointToRemove = breakpoints[0];
			}
			debugService.getViewModel().focusedThread.continue();
		});
	}
}

class SelectionToReplAction extends EditorAction {

	constructor() {
		super({
			id: 'editor.debug.action.selectionToRepl',
			label: nls.localize('debugEvaluate', "Debug: Evaluate"),
			alias: 'Debug: Evaluate',
			precondition: ContextKeyExpr.and(EditorContextKeys.hasNonEmptySelection, CONTEXT_IN_DEBUG_MODE, EditorContextKeys.editorTextFocus),
			menuOpts: {
				group: 'debug',
				order: 0
			}
		});
	}

	public run(accessor: ServicesAccessor, editor: ICodeEditor): Promise<void> {
		const debugService = accessor.get(IDebugService);
		const panelService = accessor.get(IPanelService);

		const text = editor.getModel().getValueInRange(editor.getSelection());
		const viewModel = debugService.getViewModel();
		const session = viewModel.focusedSession;
		return session.addReplExpression(viewModel.focusedStackFrame, text)
			.then(() => panelService.openPanel(REPL_ID, true))
			.then(_ => void 0);
	}
}

class SelectionToWatchExpressionsAction extends EditorAction {

	constructor() {
		super({
			id: 'editor.debug.action.selectionToWatch',
			label: nls.localize('debugAddToWatch', "Debug: Add to Watch"),
			alias: 'Debug: Add to Watch',
			precondition: ContextKeyExpr.and(EditorContextKeys.hasNonEmptySelection, CONTEXT_IN_DEBUG_MODE, EditorContextKeys.editorTextFocus),
			menuOpts: {
				group: 'debug',
				order: 1
			}
		});
	}

	public run(accessor: ServicesAccessor, editor: ICodeEditor): Thenable<void> {
		const debugService = accessor.get(IDebugService);
		const viewletService = accessor.get(IViewletService);

		const text = editor.getModel().getValueInRange(editor.getSelection());
		return viewletService.openViewlet(VIEWLET_ID).then(() => debugService.addWatchExpression(text));
	}
}

class ShowDebugHoverAction extends EditorAction {

	constructor() {
		super({
			id: 'editor.debug.action.showDebugHover',
			label: nls.localize('showDebugHover', "Debug: Show Hover"),
			alias: 'Debug: Show Hover',
			precondition: CONTEXT_IN_DEBUG_MODE,
			kbOpts: {
				kbExpr: EditorContextKeys.editorTextFocus,
				primary: KeyChord(KeyMod.CtrlCmd | KeyCode.KEY_K, KeyMod.CtrlCmd | KeyCode.KEY_I),
				weight: KeybindingWeight.EditorContrib
			}
		});
	}

	public run(accessor: ServicesAccessor, editor: ICodeEditor): Promise<void> {
		const position = editor.getPosition();
		const word = editor.getModel().getWordAtPosition(position);
		if (!word) {
			return Promise.resolve(null);
		}

		const range = new Range(position.lineNumber, position.column, position.lineNumber, word.endColumn);
		return editor.getContribution<IDebugEditorContribution>(EDITOR_CONTRIBUTION_ID).showHover(range, true);
	}
}

class GoToBreakpointAction extends EditorAction {
	constructor(private isNext: boolean, opts: IActionOptions) {
		super(opts);
	}

	public run(accessor: ServicesAccessor, editor: ICodeEditor, args: any): Thenable<any> {
		const debugService = accessor.get(IDebugService);
		const editorService = accessor.get(IEditorService);
		const currentUri = editor.getModel().uri;
		const currentLine = editor.getPosition().lineNumber;
		//Breakpoints returned from `getBreakpoints` are already sorted.
		const allEnabledBreakpoints = debugService.getModel().getBreakpoints({ enabledOnly: true });

		//Try to find breakpoint in current file
		let moveBreakpoint =
			this.isNext
				? allEnabledBreakpoints.filter(bp => bp.uri.toString() === currentUri.toString() && bp.lineNumber > currentLine).shift()
				: allEnabledBreakpoints.filter(bp => bp.uri.toString() === currentUri.toString() && bp.lineNumber < currentLine).pop();

		//Try to find breakpoints in following files
		if (!moveBreakpoint) {
			moveBreakpoint =
				this.isNext
					? allEnabledBreakpoints.filter(bp => bp.uri.toString() > currentUri.toString()).shift()
					: allEnabledBreakpoints.filter(bp => bp.uri.toString() < currentUri.toString()).pop();
		}

		//Move to first or last possible breakpoint
		if (!moveBreakpoint && allEnabledBreakpoints.length) {
			moveBreakpoint = this.isNext ? allEnabledBreakpoints[0] : allEnabledBreakpoints[allEnabledBreakpoints.length - 1];
		}

		if (moveBreakpoint) {
			return openBreakpointSource(moveBreakpoint, false, true, debugService, editorService);
		}

		return Promise.resolve(null);
	}
}

class GoToNextBreakpointAction extends GoToBreakpointAction {
	constructor() {
		super(true, {
			id: 'editor.debug.action.goToNextBreakpoint',
			label: nls.localize('goToNextBreakpoint', "Debug: Go To Next Breakpoint"),
			alias: 'Debug: Go To Next Breakpoint',
			precondition: null
		});
	}
}

class GoToPreviousBreakpointAction extends GoToBreakpointAction {
	constructor() {
		super(false, {
			id: 'editor.debug.action.goToPreviousBreakpoint',
			label: nls.localize('goToPreviousBreakpoint', "Debug: Go To Previous Breakpoint"),
			alias: 'Debug: Go To Previous Breakpoint',
			precondition: null
		});
	}
}

registerEditorAction(ToggleBreakpointAction);
registerEditorAction(ConditionalBreakpointAction);
registerEditorAction(LogPointAction);
registerEditorAction(RunToCursorAction);
registerEditorAction(SelectionToReplAction);
registerEditorAction(SelectionToWatchExpressionsAction);
registerEditorAction(ShowDebugHoverAction);
registerEditorAction(GoToNextBreakpointAction);
registerEditorAction(GoToPreviousBreakpointAction);
MenuRegistry.appendMenuItem(MenuId.CommandPalette, {
	command: {
		id: RunToCursorAction.ID,
		title: RunToCursorAction.LABEL,
		category: 'Debug'
	},
	group: 'debug',
	when: ContextKeyExpr.and(CONTEXT_IN_DEBUG_MODE, CONTEXT_DEBUG_STATE.isEqualTo('stopped')),
});
