/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as dom from 'vs/base/browser/dom';
import { CaseSensitiveCheckbox, RegexCheckbox, WholeWordsCheckbox } from 'vs/base/browser/ui/findinput/findInputCheckboxes';
import { Widget } from 'vs/base/browser/ui/widget';
import { RunOnceScheduler } from 'vs/base/common/async';
import { ICodeEditor, IOverlayWidget, IOverlayWidgetPosition, OverlayWidgetPositionPreference } from 'vs/editor/browser/editorBrowser';
import { FIND_IDS } from 'vs/editor/contrib/find/findModel';
import { FindReplaceState } from 'vs/editor/contrib/find/findState';
import { IKeybindingService } from 'vs/platform/keybinding/common/keybinding';
import { contrastBorder, editorWidgetBackground, inputActiveOptionBorder, widgetShadow } from 'vs/platform/theme/common/colorRegistry';
import { ITheme, IThemeService, registerThemingParticipant } from 'vs/platform/theme/common/themeService';

export class FindOptionsWidget extends Widget implements IOverlayWidget {

	private static readonly ID = 'editor.contrib.findOptionsWidget';

	private _editor: ICodeEditor;
	private _state: FindReplaceState;
	private _keybindingService: IKeybindingService;

	private _domNode: HTMLElement;
	private regex: RegexCheckbox;
	private wholeWords: WholeWordsCheckbox;
	private caseSensitive: CaseSensitiveCheckbox;

	constructor(
		editor: ICodeEditor,
		state: FindReplaceState,
		keybindingService: IKeybindingService,
		themeService: IThemeService
	) {
		super();

		this._editor = editor;
		this._state = state;
		this._keybindingService = keybindingService;

		this._domNode = document.createElement('div');
		this._domNode.className = 'findOptionsWidget';
		this._domNode.style.display = 'none';
		this._domNode.style.top = '10px';
		this._domNode.setAttribute('role', 'presentation');
		this._domNode.setAttribute('aria-hidden', 'true');

		let inputActiveOptionBorderColor = themeService.getTheme().getColor(inputActiveOptionBorder);

		this.caseSensitive = this._register(new CaseSensitiveCheckbox({
			appendTitle: this._keybindingLabelFor(FIND_IDS.ToggleCaseSensitiveCommand),
			isChecked: this._state.matchCase,
			inputActiveOptionBorder: inputActiveOptionBorderColor
		}));
		this._domNode.appendChild(this.caseSensitive.domNode);
		this._register(this.caseSensitive.onChange(() => {
			this._state.change({
				matchCase: this.caseSensitive.checked
			}, false);
		}));

		this.wholeWords = this._register(new WholeWordsCheckbox({
			appendTitle: this._keybindingLabelFor(FIND_IDS.ToggleWholeWordCommand),
			isChecked: this._state.wholeWord,
			inputActiveOptionBorder: inputActiveOptionBorderColor
		}));
		this._domNode.appendChild(this.wholeWords.domNode);
		this._register(this.wholeWords.onChange(() => {
			this._state.change({
				wholeWord: this.wholeWords.checked
			}, false);
		}));

		this.regex = this._register(new RegexCheckbox({
			appendTitle: this._keybindingLabelFor(FIND_IDS.ToggleRegexCommand),
			isChecked: this._state.isRegex,
			inputActiveOptionBorder: inputActiveOptionBorderColor
		}));
		this._domNode.appendChild(this.regex.domNode);
		this._register(this.regex.onChange(() => {
			this._state.change({
				isRegex: this.regex.checked
			}, false);
		}));

		this._editor.addOverlayWidget(this);

		this._register(this._state.onFindReplaceStateChange((e) => {
			let somethingChanged = false;
			if (e.isRegex) {
				this.regex.checked = this._state.isRegex;
				somethingChanged = true;
			}
			if (e.wholeWord) {
				this.wholeWords.checked = this._state.wholeWord;
				somethingChanged = true;
			}
			if (e.matchCase) {
				this.caseSensitive.checked = this._state.matchCase;
				somethingChanged = true;
			}
			if (!this._state.isRevealed && somethingChanged) {
				this._revealTemporarily();
			}
		}));

		this._register(dom.addDisposableNonBubblingMouseOutListener(this._domNode, (e) => this._onMouseOut()));
		this._register(dom.addDisposableListener(this._domNode, 'mouseover', (e) => this._onMouseOver()));

		this._applyTheme(themeService.getTheme());
		this._register(themeService.onThemeChange(this._applyTheme.bind(this)));
	}

	private _keybindingLabelFor(actionId: string): string {
		let kb = this._keybindingService.lookupKeybinding(actionId);
		if (!kb) {
			return '';
		}
		return ` (${kb.getLabel()})`;
	}

	public dispose(): void {
		this._editor.removeOverlayWidget(this);
		super.dispose();
	}

	// ----- IOverlayWidget API

	public getId(): string {
		return FindOptionsWidget.ID;
	}

	public getDomNode(): HTMLElement {
		return this._domNode;
	}

	public getPosition(): IOverlayWidgetPosition {
		return {
			preference: OverlayWidgetPositionPreference.TOP_RIGHT_CORNER
		};
	}

	public highlightFindOptions(): void {
		this._revealTemporarily();
	}

	private _hideSoon = this._register(new RunOnceScheduler(() => this._hide(), 2000));

	private _revealTemporarily(): void {
		this._show();
		this._hideSoon.schedule();
	}

	private _onMouseOut(): void {
		this._hideSoon.schedule();
	}

	private _onMouseOver(): void {
		this._hideSoon.cancel();
	}

	private _isVisible: boolean = false;

	private _show(): void {
		if (this._isVisible) {
			return;
		}
		this._isVisible = true;
		this._domNode.style.display = 'block';
	}

	private _hide(): void {
		if (!this._isVisible) {
			return;
		}
		this._isVisible = false;
		this._domNode.style.display = 'none';
	}

	private _applyTheme(theme: ITheme) {
		let inputStyles = { inputActiveOptionBorder: theme.getColor(inputActiveOptionBorder) };
		this.caseSensitive.style(inputStyles);
		this.wholeWords.style(inputStyles);
		this.regex.style(inputStyles);
	}
}


registerThemingParticipant((theme, collector) => {
	const widgetBackground = theme.getColor(editorWidgetBackground);
	if (widgetBackground) {
		collector.addRule(`.monaco-editor .findOptionsWidget { background-color: ${widgetBackground}; }`);
	}

	const widgetShadowColor = theme.getColor(widgetShadow);
	if (widgetShadowColor) {
		collector.addRule(`.monaco-editor .findOptionsWidget { box-shadow: 0 2px 8px ${widgetShadowColor}; }`);
	}

	const hcBorder = theme.getColor(contrastBorder);
	if (hcBorder) {
		collector.addRule(`.monaco-editor .findOptionsWidget { border: 2px solid ${hcBorder}; }`);
	}
});