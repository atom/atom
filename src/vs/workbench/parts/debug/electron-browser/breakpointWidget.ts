/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import 'vs/css!../browser/media/breakpointWidget';
import * as nls from 'vs/nls';
import { KeyCode, KeyMod } from 'vs/base/common/keyCodes';
import { SelectBox } from 'vs/base/browser/ui/selectBox/selectBox';
import * as lifecycle from 'vs/base/common/lifecycle';
import * as dom from 'vs/base/browser/dom';
import { Position, IPosition } from 'vs/editor/common/core/position';
import { ICodeEditor } from 'vs/editor/browser/editorBrowser';
import { ZoneWidget } from 'vs/editor/contrib/zoneWidget/zoneWidget';
import { IContextViewService } from 'vs/platform/contextview/browser/contextView';
import { IDebugService, IBreakpoint, BreakpointWidgetContext as Context, CONTEXT_BREAKPOINT_WIDGET_VISIBLE, DEBUG_SCHEME, IDebugEditorContribution, EDITOR_CONTRIBUTION_ID, CONTEXT_IN_BREAKPOINT_WIDGET } from 'vs/workbench/parts/debug/common/debug';
import { attachSelectBoxStyler } from 'vs/platform/theme/common/styler';
import { IThemeService } from 'vs/platform/theme/common/themeService';
import { createDecorator, IInstantiationService } from 'vs/platform/instantiation/common/instantiation';
import { IContextKeyService } from 'vs/platform/contextkey/common/contextkey';
import { ServicesAccessor, EditorCommand, registerEditorCommand } from 'vs/editor/browser/editorExtensions';
import { EditorContextKeys } from 'vs/editor/common/editorContextKeys';
import { IModelService } from 'vs/editor/common/services/modelService';
import { URI as uri } from 'vs/base/common/uri';
import { CompletionProviderRegistry, CompletionList, CompletionContext } from 'vs/editor/common/modes';
import { CancellationToken } from 'vs/base/common/cancellation';
import { ITextModel } from 'vs/editor/common/model';
import { provideSuggestionItems } from 'vs/editor/contrib/suggest/suggest';
import { ICodeEditorService } from 'vs/editor/browser/services/codeEditorService';
import { transparent, editorForeground } from 'vs/platform/theme/common/colorRegistry';
import { ServiceCollection } from 'vs/platform/instantiation/common/serviceCollection';
import { IDecorationOptions } from 'vs/editor/common/editorCommon';
import { CodeEditorWidget } from 'vs/editor/browser/widget/codeEditorWidget';
import { KeybindingWeight } from 'vs/platform/keybinding/common/keybindingsRegistry';
import { getSimpleCodeEditorWidgetOptions } from 'vs/workbench/parts/codeEditor/electron-browser/simpleEditorOptions';
import { getSimpleEditorOptions } from 'vs/workbench/parts/codeEditor/browser/simpleEditorOptions';
import { IRange, Range } from 'vs/editor/common/core/range';

const $ = dom.$;
const IPrivateBreakpointWidgetService = createDecorator<IPrivateBreakpointWidgetService>('privateBreakopintWidgetService');
export interface IPrivateBreakpointWidgetService {
	_serviceBrand: any;
	close(success: boolean): void;
}
const DECORATION_KEY = 'breakpointwidgetdecoration';

export class BreakpointWidget extends ZoneWidget implements IPrivateBreakpointWidgetService {
	public _serviceBrand: any;

	private selectContainer: HTMLElement;
	private input: CodeEditorWidget;
	private toDispose: lifecycle.IDisposable[];
	private conditionInput = '';
	private hitCountInput = '';
	private logMessageInput = '';
	private breakpoint: IBreakpoint;

	constructor(editor: ICodeEditor, private lineNumber: number, private context: Context,
		@IContextViewService private contextViewService: IContextViewService,
		@IDebugService private debugService: IDebugService,
		@IThemeService private themeService: IThemeService,
		@IContextKeyService private contextKeyService: IContextKeyService,
		@IInstantiationService private instantiationService: IInstantiationService,
		@IModelService private modelService: IModelService,
		@ICodeEditorService private codeEditorService: ICodeEditorService,
	) {
		super(editor, { showFrame: true, showArrow: false, frameWidth: 1 });

		this.toDispose = [];
		const uri = this.editor.getModel().uri;
		const breakpoints = this.debugService.getModel().getBreakpoints({ lineNumber: this.lineNumber, uri });
		this.breakpoint = breakpoints.length ? breakpoints[0] : undefined;

		if (this.context === undefined) {
			if (this.breakpoint && !this.breakpoint.condition && !this.breakpoint.hitCondition && this.breakpoint.logMessage) {
				this.context = Context.LOG_MESSAGE;
			} else if (this.breakpoint && !this.breakpoint.condition && this.breakpoint.hitCondition) {
				this.context = Context.HIT_COUNT;
			} else {
				this.context = Context.CONDITION;
			}
		}

		this.toDispose.push(this.debugService.getModel().onDidChangeBreakpoints(e => {
			if (this.breakpoint && e && e.removed && e.removed.indexOf(this.breakpoint) >= 0) {
				this.dispose();
			}
		}));
		this.codeEditorService.registerDecorationType(DECORATION_KEY, {});

		this.create();
	}

	private get placeholder(): string {
		switch (this.context) {
			case Context.LOG_MESSAGE:
				return nls.localize('breakpointWidgetLogMessagePlaceholder', "Message to log when breakpoint is hit. Expressions within {} are interpolated. 'Enter' to accept, 'esc' to cancel.");
			case Context.HIT_COUNT:
				return nls.localize('breakpointWidgetHitCountPlaceholder', "Break when hit count condition is met. 'Enter' to accept, 'esc' to cancel.");
			default:
				return nls.localize('breakpointWidgetExpressionPlaceholder', "Break when expression evaluates to true. 'Enter' to accept, 'esc' to cancel.");
		}
	}

	private getInputValue(breakpoint: IBreakpoint): string {
		switch (this.context) {
			case Context.LOG_MESSAGE:
				return breakpoint && breakpoint.logMessage ? breakpoint.logMessage : this.logMessageInput;
			case Context.HIT_COUNT:
				return breakpoint && breakpoint.hitCondition ? breakpoint.hitCondition : this.hitCountInput;
			default:
				return breakpoint && breakpoint.condition ? breakpoint.condition : this.conditionInput;
		}
	}

	private rememberInput(): void {
		const value = this.input.getModel().getValue();
		switch (this.context) {
			case Context.LOG_MESSAGE:
				this.logMessageInput = value;
				break;
			case Context.HIT_COUNT:
				this.hitCountInput = value;
				break;
			default:
				this.conditionInput = value;
		}
	}

	public show(rangeOrPos: IRange | IPosition, heightInLines: number) {
		const lineNum = this.input.getModel().getLineCount();
		super.show(rangeOrPos, lineNum + 1);
	}

	public fitHeightToContent() {
		const lineNum = this.input.getModel().getLineCount();
		this._relayout(lineNum + 1);
	}

	protected _fillContainer(container: HTMLElement): void {
		this.setCssClass('breakpoint-widget');
		const selectBox = new SelectBox([nls.localize('expression', "Expression"), nls.localize('hitCount', "Hit Count"), nls.localize('logMessage', "Log Message")], this.context, this.contextViewService, null, { ariaLabel: nls.localize('breakpointType', 'Breakpoint Type') });
		this.toDispose.push(attachSelectBoxStyler(selectBox, this.themeService));
		this.selectContainer = $('.breakpoint-select-container');
		selectBox.render(dom.append(container, this.selectContainer));
		selectBox.onDidSelect(e => {
			this.rememberInput();
			this.context = e.index;

			const value = this.getInputValue(this.breakpoint);
			this.input.getModel().setValue(value);
		});

		this.createBreakpointInput(dom.append(container, $('.inputContainer')));

		this.input.getModel().setValue(this.getInputValue(this.breakpoint));
		this.toDispose.push(this.input.getModel().onDidChangeContent(() => {
			this.fitHeightToContent();
		}));
		this.input.setPosition({ lineNumber: 1, column: this.input.getModel().getLineMaxColumn(1) });
		// Due to an electron bug we have to do the timeout, otherwise we do not get focus
		setTimeout(() => this.input.focus(), 100);
	}

	public close(success: boolean): void {
		if (success) {
			// if there is already a breakpoint on this location - remove it.

			let condition = this.breakpoint && this.breakpoint.condition;
			let hitCondition = this.breakpoint && this.breakpoint.hitCondition;
			let logMessage = this.breakpoint && this.breakpoint.logMessage;
			this.rememberInput();

			if (this.conditionInput || this.context === Context.CONDITION) {
				condition = this.conditionInput;
			}
			if (this.hitCountInput || this.context === Context.HIT_COUNT) {
				hitCondition = this.hitCountInput;
			}
			if (this.logMessageInput || this.context === Context.LOG_MESSAGE) {
				logMessage = this.logMessageInput;
			}

			if (this.breakpoint) {
				this.debugService.updateBreakpoints(this.breakpoint.uri, {
					[this.breakpoint.getId()]: {
						condition,
						hitCondition,
						logMessage
					}
				}, false);
			} else {
				this.debugService.addBreakpoints(this.editor.getModel().uri, [{
					lineNumber: this.lineNumber,
					enabled: true,
					condition,
					hitCondition,
					logMessage
				}], `breakpointWidget`);
			}
		}

		this.dispose();
	}

	protected _doLayout(heightInPixel: number, widthInPixel: number): void {
		this.input.layout({ height: heightInPixel, width: widthInPixel - 113 });
	}

	private createBreakpointInput(container: HTMLElement): void {
		const scopedContextKeyService = this.contextKeyService.createScoped(container);
		this.toDispose.push(scopedContextKeyService);

		const scopedInstatiationService = this.instantiationService.createChild(new ServiceCollection(
			[IContextKeyService, scopedContextKeyService], [IPrivateBreakpointWidgetService, this]));

		const options = getSimpleEditorOptions();
		const codeEditorWidgetOptions = getSimpleCodeEditorWidgetOptions();
		this.input = scopedInstatiationService.createInstance(CodeEditorWidget, container, options, codeEditorWidgetOptions);
		CONTEXT_IN_BREAKPOINT_WIDGET.bindTo(scopedContextKeyService).set(true);
		const model = this.modelService.createModel('', null, uri.parse(`${DEBUG_SCHEME}:${this.editor.getId()}:breakpointinput`), true);
		this.input.setModel(model);
		this.toDispose.push(model);
		const setDecorations = () => {
			const value = this.input.getModel().getValue();
			const decorations = !!value ? [] : this.createDecorations();
			this.input.setDecorations(DECORATION_KEY, decorations);
		};
		this.input.getModel().onDidChangeContent(() => setDecorations());
		this.themeService.onThemeChange(() => setDecorations());

		this.toDispose.push(CompletionProviderRegistry.register({ scheme: DEBUG_SCHEME, hasAccessToAllModels: true }, {
			provideCompletionItems: (model: ITextModel, position: Position, _context: CompletionContext, token: CancellationToken): Thenable<CompletionList> => {
				let suggestionsPromise: Promise<CompletionList>;
				if (this.context === Context.CONDITION || this.context === Context.LOG_MESSAGE && this.isCurlyBracketOpen()) {
					suggestionsPromise = provideSuggestionItems(this.editor.getModel(), new Position(this.lineNumber, 1), 'none', undefined, _context, token).then(suggestions => {

						let overwriteBefore = 0;
						if (this.context === Context.CONDITION) {
							overwriteBefore = position.column - 1;
						} else {
							// Inside the currly brackets, need to count how many useful characters are behind the position so they would all be taken into account
							const value = this.input.getModel().getValue();
							while ((position.column - 2 - overwriteBefore >= 0) && value[position.column - 2 - overwriteBefore] !== '{' && value[position.column - 2 - overwriteBefore] !== ' ') {
								overwriteBefore++;
							}
						}

						return {
							suggestions: suggestions.map(s => {
								s.suggestion.range = Range.fromPositions(position.delta(0, -overwriteBefore), position);
								return s.suggestion;
							})
						};
					});
				} else {
					suggestionsPromise = Promise.resolve({ suggestions: [] });
				}

				return suggestionsPromise;
			}
		}));
	}

	private createDecorations(): IDecorationOptions[] {
		return [{
			range: {
				startLineNumber: 0,
				endLineNumber: 0,
				startColumn: 0,
				endColumn: 1
			},
			renderOptions: {
				after: {
					contentText: this.placeholder,
					color: transparent(editorForeground, 0.4)(this.themeService.getTheme()).toString()
				}
			}
		}];
	}

	private isCurlyBracketOpen(): boolean {
		const value = this.input.getModel().getValue();
		for (let i = this.input.getPosition().column - 2; i >= 0; i--) {
			if (value[i] === '{') {
				return true;
			}

			if (value[i] === '}') {
				return false;
			}
		}

		return false;
	}

	public dispose(): void {
		super.dispose();
		this.input.dispose();
		lifecycle.dispose(this.toDispose);
		setTimeout(() => this.editor.focus(), 0);
	}
}

class AcceptBreakpointWidgetInputAction extends EditorCommand {

	constructor() {
		super({
			id: 'breakpointWidget.action.acceptInput',
			precondition: CONTEXT_BREAKPOINT_WIDGET_VISIBLE,
			kbOpts: {
				kbExpr: CONTEXT_IN_BREAKPOINT_WIDGET,
				primary: KeyCode.Enter,
				weight: KeybindingWeight.EditorContrib
			}
		});
	}

	public runEditorCommand(accessor: ServicesAccessor, editor: ICodeEditor): void {
		accessor.get(IPrivateBreakpointWidgetService).close(true);
	}
}

class CloseBreakpointWidgetCommand extends EditorCommand {

	constructor() {
		super({
			id: 'closeBreakpointWidget',
			precondition: CONTEXT_BREAKPOINT_WIDGET_VISIBLE,
			kbOpts: {
				kbExpr: EditorContextKeys.textInputFocus,
				primary: KeyCode.Escape,
				secondary: [KeyMod.Shift | KeyCode.Escape],
				weight: KeybindingWeight.EditorContrib
			}
		});
	}

	public runEditorCommand(accessor: ServicesAccessor, editor: ICodeEditor, args: any): void {
		const debugContribution = editor.getContribution<IDebugEditorContribution>(EDITOR_CONTRIBUTION_ID);
		if (debugContribution) {
			// if focus is in outer editor we need to use the debug contribution to close
			return debugContribution.closeBreakpointWidget();
		}

		accessor.get(IPrivateBreakpointWidgetService).close(false);
	}
}

registerEditorCommand(new AcceptBreakpointWidgetInputAction());
registerEditorCommand(new CloseBreakpointWidgetCommand());
