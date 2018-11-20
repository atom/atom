/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import 'vs/css!./media/keybindings';
import * as nls from 'vs/nls';
import { OS } from 'vs/base/common/platform';
import { Disposable, dispose, toDisposable, IDisposable } from 'vs/base/common/lifecycle';
import { Event, Emitter } from 'vs/base/common/event';
import { KeybindingLabel } from 'vs/base/browser/ui/keybindingLabel/keybindingLabel';
import { Widget } from 'vs/base/browser/ui/widget';
import { ResolvedKeybinding, KeyCode } from 'vs/base/common/keyCodes';
import * as dom from 'vs/base/browser/dom';
import { IKeyboardEvent, StandardKeyboardEvent } from 'vs/base/browser/keyboardEvent';
import { FastDomNode, createFastDomNode } from 'vs/base/browser/fastDomNode';
import { IKeybindingService } from 'vs/platform/keybinding/common/keybinding';
import { IContextViewService } from 'vs/platform/contextview/browser/contextView';
import { IInstantiationService } from 'vs/platform/instantiation/common/instantiation';
import { ICodeEditor, IOverlayWidget, IOverlayWidgetPosition } from 'vs/editor/browser/editorBrowser';
import { attachInputBoxStyler, attachStylerCallback } from 'vs/platform/theme/common/styler';
import { IThemeService } from 'vs/platform/theme/common/themeService';
import { editorWidgetBackground, widgetShadow } from 'vs/platform/theme/common/colorRegistry';
import { ScrollType } from 'vs/editor/common/editorCommon';
import { SearchWidget, SearchOptions } from 'vs/workbench/parts/preferences/browser/preferencesWidgets';

export interface KeybindingsSearchOptions extends SearchOptions {
	recordEnter?: boolean;
	quoteRecordedKeys?: boolean;
}

export class KeybindingsSearchWidget extends SearchWidget {

	private _firstPart: ResolvedKeybinding;
	private _chordPart: ResolvedKeybinding;
	private _inputValue: string;

	private recordDisposables: IDisposable[] = [];

	private _onKeybinding = this._register(new Emitter<[ResolvedKeybinding, ResolvedKeybinding]>());
	public readonly onKeybinding: Event<[ResolvedKeybinding, ResolvedKeybinding]> = this._onKeybinding.event;

	private _onEnter = this._register(new Emitter<void>());
	public readonly onEnter: Event<void> = this._onEnter.event;

	private _onEscape = this._register(new Emitter<void>());
	public readonly onEscape: Event<void> = this._onEscape.event;

	private _onBlur = this._register(new Emitter<void>());
	public readonly onBlur: Event<void> = this._onBlur.event;

	constructor(parent: HTMLElement, options: SearchOptions,
		@IContextViewService contextViewService: IContextViewService,
		@IKeybindingService private keybindingService: IKeybindingService,
		@IInstantiationService instantiationService: IInstantiationService,
		@IThemeService themeService: IThemeService
	) {
		super(parent, options, contextViewService, instantiationService, themeService);
		this._register(attachInputBoxStyler(this.inputBox, themeService));
		this._register(toDisposable(() => this.stopRecordingKeys()));

		this._reset();
	}

	clear(): void {
		this._reset();
		super.clear();
	}

	startRecordingKeys(): void {
		this.recordDisposables.push(dom.addDisposableListener(this.inputBox.inputElement, dom.EventType.KEY_DOWN, (e: KeyboardEvent) => this._onKeyDown(new StandardKeyboardEvent(e))));
		this.recordDisposables.push(dom.addDisposableListener(this.inputBox.inputElement, dom.EventType.BLUR, () => this._onBlur.fire()));
		this.recordDisposables.push(dom.addDisposableListener(this.inputBox.inputElement, dom.EventType.INPUT, () => {
			// Prevent other characters from showing up
			this.setInputValue(this._inputValue);
		}));
	}

	stopRecordingKeys(): void {
		this._reset();
		dispose(this.recordDisposables);
	}

	public setInputValue(value: string): void {
		this._inputValue = value;
		this.inputBox.value = this._inputValue;
	}

	public focus(): void {
		this.inputBox.focus();
	}

	private _reset() {
		this._firstPart = null;
		this._chordPart = null;
	}

	private _onKeyDown(keyboardEvent: IKeyboardEvent): void {
		keyboardEvent.preventDefault();
		keyboardEvent.stopPropagation();
		const options = this.options as KeybindingsSearchOptions;
		if (!options.recordEnter && keyboardEvent.equals(KeyCode.Enter)) {
			this._onEnter.fire();
			return;
		}
		if (keyboardEvent.equals(KeyCode.Escape)) {
			this._onEscape.fire();
			return;
		}
		this.printKeybinding(keyboardEvent);
	}

	private printKeybinding(keyboardEvent: IKeyboardEvent): void {
		const keybinding = this.keybindingService.resolveKeyboardEvent(keyboardEvent);
		const info = `code: ${keyboardEvent.browserEvent.code}, keyCode: ${keyboardEvent.browserEvent.keyCode}, key: ${keyboardEvent.browserEvent.key} => UI: ${keybinding.getAriaLabel()}, user settings: ${keybinding.getUserSettingsLabel()}, dispatch: ${keybinding.getDispatchParts()[0]}`;
		const options = this.options as KeybindingsSearchOptions;

		const hasFirstPart = (this._firstPart && this._firstPart.getDispatchParts()[0] !== null);
		const hasChordPart = (this._chordPart && this._chordPart.getDispatchParts()[0] !== null);
		if (hasFirstPart && hasChordPart) {
			// Reset
			this._firstPart = keybinding;
			this._chordPart = null;
		} else if (!hasFirstPart) {
			this._firstPart = keybinding;
		} else {
			this._chordPart = keybinding;
		}

		let value = '';
		if (this._firstPart) {
			value = this._firstPart.getUserSettingsLabel();
		}
		if (this._chordPart) {
			value = value + ' ' + this._chordPart.getUserSettingsLabel();
		}
		this.setInputValue(options.quoteRecordedKeys ? `"${value}"` : value);

		this.inputBox.inputElement.title = info;
		this._onKeybinding.fire([this._firstPart, this._chordPart]);
	}
}

export class DefineKeybindingWidget extends Widget {

	private static readonly WIDTH = 400;
	private static readonly HEIGHT = 110;

	private _domNode: FastDomNode<HTMLElement>;
	private _keybindingInputWidget: KeybindingsSearchWidget;
	private _outputNode: HTMLElement;
	private _showExistingKeybindingsNode: HTMLElement;

	private _firstPart: ResolvedKeybinding | null = null;
	private _chordPart: ResolvedKeybinding | null = null;
	private _isVisible: boolean = false;

	private _onHide = this._register(new Emitter<void>());

	private _onDidChange = this._register(new Emitter<String>());
	public onDidChange: Event<String> = this._onDidChange.event;

	private _onShowExistingKeybindings = this._register(new Emitter<String>());
	public readonly onShowExistingKeybidings: Event<String> = this._onShowExistingKeybindings.event;

	constructor(
		parent: HTMLElement,
		@IInstantiationService private instantiationService: IInstantiationService,
		@IThemeService private themeService: IThemeService
	) {
		super();
		this.create();
		if (parent) {
			dom.append(parent, this._domNode.domNode);
		}
	}

	get domNode(): HTMLElement {
		return this._domNode.domNode;
	}

	define(): Promise<string> {
		this._keybindingInputWidget.clear();
		return new Promise<string>((c) => {
			if (!this._isVisible) {
				this._isVisible = true;
				this._domNode.setDisplay('block');

				this._firstPart = null;
				this._chordPart = null;
				this._keybindingInputWidget.setInputValue('');
				dom.clearNode(this._outputNode);
				dom.clearNode(this._showExistingKeybindingsNode);
				this._keybindingInputWidget.focus();
			}
			const disposable = this._onHide.event(() => {
				c(this.getUserSettingsLabel());
				disposable.dispose();
			});
		});
	}

	layout(layout: dom.Dimension): void {
		let top = Math.round((layout.height - DefineKeybindingWidget.HEIGHT) / 2);
		this._domNode.setTop(top);

		let left = Math.round((layout.width - DefineKeybindingWidget.WIDTH) / 2);
		this._domNode.setLeft(left);
	}

	printExisting(numberOfExisting: number): void {
		if (numberOfExisting > 0) {
			const existingElement = dom.$('span.existingText');
			const text = numberOfExisting === 1 ? nls.localize('defineKeybinding.oneExists', "1 existing command has this keybinding", numberOfExisting) : nls.localize('defineKeybinding.existing', "{0} existing commands have this keybinding", numberOfExisting);
			dom.append(existingElement, document.createTextNode(text));
			this._showExistingKeybindingsNode.appendChild(existingElement);
			existingElement.onmousedown = (e) => { e.preventDefault(); };
			existingElement.onmouseup = (e) => { e.preventDefault(); };
			existingElement.onclick = () => { this._onShowExistingKeybindings.fire(this.getUserSettingsLabel()); };
		}
	}

	private create(): void {
		this._domNode = createFastDomNode(document.createElement('div'));
		this._domNode.setDisplay('none');
		this._domNode.setClassName('defineKeybindingWidget');
		this._domNode.setWidth(DefineKeybindingWidget.WIDTH);
		this._domNode.setHeight(DefineKeybindingWidget.HEIGHT);

		const message = nls.localize('defineKeybinding.initial', "Press desired key combination and then press ENTER.");
		dom.append(this._domNode.domNode, dom.$('.message', null, message));

		this._register(attachStylerCallback(this.themeService, { editorWidgetBackground, widgetShadow }, colors => {
			if (colors.editorWidgetBackground) {
				this._domNode.domNode.style.backgroundColor = colors.editorWidgetBackground.toString();
			} else {
				this._domNode.domNode.style.backgroundColor = null;
			}

			if (colors.widgetShadow) {
				this._domNode.domNode.style.boxShadow = `0 2px 8px ${colors.widgetShadow}`;
			} else {
				this._domNode.domNode.style.boxShadow = null;
			}
		}));

		this._keybindingInputWidget = this._register(this.instantiationService.createInstance(KeybindingsSearchWidget, this._domNode.domNode, { ariaLabel: message }));
		this._keybindingInputWidget.startRecordingKeys();
		this._register(this._keybindingInputWidget.onKeybinding(keybinding => this.onKeybinding(keybinding)));
		this._register(this._keybindingInputWidget.onEnter(() => this.hide()));
		this._register(this._keybindingInputWidget.onEscape(() => this.onCancel()));
		this._register(this._keybindingInputWidget.onBlur(() => this.onCancel()));

		this._outputNode = dom.append(this._domNode.domNode, dom.$('.output'));
		this._showExistingKeybindingsNode = dom.append(this._domNode.domNode, dom.$('.existing'));
	}

	private onKeybinding(keybinding: [ResolvedKeybinding, ResolvedKeybinding]): void {
		const [firstPart, chordPart] = keybinding;
		this._firstPart = firstPart;
		this._chordPart = chordPart;
		dom.clearNode(this._outputNode);
		dom.clearNode(this._showExistingKeybindingsNode);
		new KeybindingLabel(this._outputNode, OS).set(this._firstPart, null);
		if (this._chordPart) {
			this._outputNode.appendChild(document.createTextNode(nls.localize('defineKeybinding.chordsTo', "chord to")));
			new KeybindingLabel(this._outputNode, OS).set(this._chordPart, null);
		}
		const label = this.getUserSettingsLabel();
		if (label) {
			this._onDidChange.fire(label);
		}
	}

	private getUserSettingsLabel(): string {
		let label = null;
		if (this._firstPart) {
			label = this._firstPart.getUserSettingsLabel();
			if (this._chordPart) {
				label = label + ' ' + this._chordPart.getUserSettingsLabel();
			}
		}
		return label;
	}

	private onCancel(): void {
		this._firstPart = null;
		this._chordPart = null;
		this.hide();
	}

	private hide(): void {
		this._domNode.setDisplay('none');
		this._isVisible = false;
		this._onHide.fire();
	}
}

export class DefineKeybindingOverlayWidget extends Disposable implements IOverlayWidget {

	private static readonly ID = 'editor.contrib.defineKeybindingWidget';

	private readonly _widget: DefineKeybindingWidget;

	constructor(private _editor: ICodeEditor,
		@IInstantiationService instantiationService: IInstantiationService
	) {
		super();

		this._widget = instantiationService.createInstance(DefineKeybindingWidget, null);
		this._editor.addOverlayWidget(this);
	}

	public getId(): string {
		return DefineKeybindingOverlayWidget.ID;
	}

	public getDomNode(): HTMLElement {
		return this._widget.domNode;
	}

	public getPosition(): IOverlayWidgetPosition {
		return {
			preference: null
		};
	}

	public dispose(): void {
		this._editor.removeOverlayWidget(this);
		super.dispose();
	}

	public start(): Promise<string> {
		this._editor.revealPositionInCenterIfOutsideViewport(this._editor.getPosition(), ScrollType.Smooth);
		const layoutInfo = this._editor.getLayoutInfo();
		this._widget.layout(new dom.Dimension(layoutInfo.width, layoutInfo.height));
		return this._widget.define();
	}
}
