/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import 'vs/css!./inputBox';

import * as nls from 'vs/nls';
import * as Bal from 'vs/base/browser/browser';
import * as dom from 'vs/base/browser/dom';
import { RenderOptions, renderFormattedText, renderText } from 'vs/base/browser/htmlContentRenderer';
import * as aria from 'vs/base/browser/ui/aria/aria';
import { IAction } from 'vs/base/common/actions';
import { ActionBar } from 'vs/base/browser/ui/actionbar/actionbar';
import { IContextViewProvider, AnchorAlignment } from 'vs/base/browser/ui/contextview/contextview';
import { Event, Emitter } from 'vs/base/common/event';
import { Widget } from 'vs/base/browser/ui/widget';
import { Color } from 'vs/base/common/color';
import { mixin } from 'vs/base/common/objects';
import { HistoryNavigator } from 'vs/base/common/history';
import { IHistoryNavigationWidget } from 'vs/base/browser/history';

const $ = dom.$;

export interface IInputOptions extends IInputBoxStyles {
	placeholder?: string;
	ariaLabel?: string;
	type?: string;
	validationOptions?: IInputValidationOptions;
	flexibleHeight?: boolean;
	actions?: IAction[];
}

export interface IInputBoxStyles {
	inputBackground?: Color;
	inputForeground?: Color;
	inputBorder?: Color;
	inputValidationInfoBorder?: Color;
	inputValidationInfoBackground?: Color;
	inputValidationInfoForeground?: Color;
	inputValidationWarningBorder?: Color;
	inputValidationWarningBackground?: Color;
	inputValidationWarningForeground?: Color;
	inputValidationErrorBorder?: Color;
	inputValidationErrorBackground?: Color;
	inputValidationErrorForeground?: Color;
}

export interface IInputValidator {
	(value: string): IMessage;
}

export interface IMessage {
	content: string;
	formatContent?: boolean; // defaults to false
	type?: MessageType;
}

export interface IInputValidationOptions {
	validation: IInputValidator;
}

export const enum MessageType {
	INFO = 1,
	WARNING = 2,
	ERROR = 3
}

export interface IRange {
	start: number;
	end: number;
}

const defaultOpts = {
	inputBackground: Color.fromHex('#3C3C3C'),
	inputForeground: Color.fromHex('#CCCCCC'),
	inputValidationInfoBorder: Color.fromHex('#55AAFF'),
	inputValidationInfoBackground: Color.fromHex('#063B49'),
	inputValidationWarningBorder: Color.fromHex('#B89500'),
	inputValidationWarningBackground: Color.fromHex('#352A05'),
	inputValidationErrorBorder: Color.fromHex('#BE1100'),
	inputValidationErrorBackground: Color.fromHex('#5A1D1D')
};

export class InputBox extends Widget {
	private contextViewProvider: IContextViewProvider;
	element: HTMLElement;
	private input: HTMLInputElement;
	private mirror: HTMLElement;
	private actionbar: ActionBar;
	private options: IInputOptions;
	private message: IMessage;
	private placeholder: string;
	private ariaLabel: string;
	private validation: IInputValidator;
	private state = 'idle';
	private cachedHeight: number;

	private inputBackground: Color;
	private inputForeground: Color;
	private inputBorder: Color;

	private inputValidationInfoBorder: Color;
	private inputValidationInfoBackground: Color;
	private inputValidationInfoForeground: Color;
	private inputValidationWarningBorder: Color;
	private inputValidationWarningBackground: Color;
	private inputValidationWarningForeground: Color;
	private inputValidationErrorBorder: Color;
	private inputValidationErrorBackground: Color;
	private inputValidationErrorForeground: Color;

	private _onDidChange = this._register(new Emitter<string>());
	public readonly onDidChange: Event<string> = this._onDidChange.event;

	private _onDidHeightChange = this._register(new Emitter<number>());
	public readonly onDidHeightChange: Event<number> = this._onDidHeightChange.event;

	constructor(container: HTMLElement, contextViewProvider: IContextViewProvider, options?: IInputOptions) {
		super();

		this.contextViewProvider = contextViewProvider;
		this.options = options || Object.create(null);
		mixin(this.options, defaultOpts, false);
		this.message = null;
		this.cachedHeight = null;
		this.placeholder = this.options.placeholder || '';
		this.ariaLabel = this.options.ariaLabel || '';

		this.inputBackground = this.options.inputBackground;
		this.inputForeground = this.options.inputForeground;
		this.inputBorder = this.options.inputBorder;

		this.inputValidationInfoBorder = this.options.inputValidationInfoBorder;
		this.inputValidationInfoBackground = this.options.inputValidationInfoBackground;
		this.inputValidationInfoForeground = this.options.inputValidationInfoForeground;
		this.inputValidationWarningBorder = this.options.inputValidationWarningBorder;
		this.inputValidationWarningBackground = this.options.inputValidationWarningBackground;
		this.inputValidationWarningForeground = this.options.inputValidationWarningForeground;
		this.inputValidationErrorBorder = this.options.inputValidationErrorBorder;
		this.inputValidationErrorBackground = this.options.inputValidationErrorBackground;
		this.inputValidationErrorForeground = this.options.inputValidationErrorForeground;

		if (this.options.validationOptions) {
			this.validation = this.options.validationOptions.validation;
		}

		this.element = dom.append(container, $('.monaco-inputbox.idle'));

		let tagName = this.options.flexibleHeight ? 'textarea' : 'input';

		let wrapper = dom.append(this.element, $('.wrapper'));
		this.input = <HTMLInputElement>dom.append(wrapper, $(tagName + '.input'));
		this.input.setAttribute('autocorrect', 'off');
		this.input.setAttribute('autocapitalize', 'off');
		this.input.setAttribute('spellcheck', 'false');

		this.onfocus(this.input, () => dom.addClass(this.element, 'synthetic-focus'));
		this.onblur(this.input, () => dom.removeClass(this.element, 'synthetic-focus'));

		if (this.options.flexibleHeight) {
			this.mirror = dom.append(wrapper, $('div.mirror'));
		} else {
			this.input.type = this.options.type || 'text';
			this.input.setAttribute('wrap', 'off');
		}

		if (this.ariaLabel) {
			this.input.setAttribute('aria-label', this.ariaLabel);
		}

		if (this.placeholder) {
			this.setPlaceHolder(this.placeholder);
		}

		this.oninput(this.input, () => this.onValueChange());
		this.onblur(this.input, () => this.onBlur());
		this.onfocus(this.input, () => this.onFocus());

		// Add placeholder shim for IE because IE decides to hide the placeholder on focus (we dont want that!)
		if (this.placeholder && Bal.isIE) {
			this.onclick(this.input, (e) => {
				dom.EventHelper.stop(e, true);
				this.input.focus();
			});
		}

		setTimeout(() => {
			if (!this.input) {
				return;
			}

			this.updateMirror();
		}, 0);

		// Support actions
		if (this.options.actions) {
			this.actionbar = this._register(new ActionBar(this.element));
			this.actionbar.push(this.options.actions, { icon: true, label: false });
		}

		this.applyStyles();
	}

	private onBlur(): void {
		this._hideMessage();
	}

	private onFocus(): void {
		this._showMessage();
	}

	public setPlaceHolder(placeHolder: string): void {
		if (this.input) {
			this.input.setAttribute('placeholder', placeHolder);
			this.input.title = placeHolder;
		}
	}

	public setAriaLabel(label: string): void {
		this.ariaLabel = label;

		if (this.input) {
			if (label) {
				this.input.setAttribute('aria-label', this.ariaLabel);
			} else {
				this.input.removeAttribute('aria-label');
			}
		}
	}

	public get inputElement(): HTMLInputElement {
		return this.input;
	}

	public get value(): string {
		return this.input.value;
	}

	public set value(newValue: string) {
		if (this.input.value !== newValue) {
			this.input.value = newValue;
			this.onValueChange();
		}
	}

	public get height(): number {
		return this.cachedHeight === null ? dom.getTotalHeight(this.element) : this.cachedHeight;
	}

	public focus(): void {
		this.input.focus();
	}

	public blur(): void {
		this.input.blur();
	}

	public hasFocus(): boolean {
		return document.activeElement === this.input;
	}

	public select(range: IRange | null = null): void {
		this.input.select();

		if (range) {
			this.input.setSelectionRange(range.start, range.end);
		}
	}

	public enable(): void {
		this.input.removeAttribute('disabled');
	}

	public disable(): void {
		this.input.disabled = true;
		this._hideMessage();
	}

	public setEnabled(enabled: boolean): void {
		if (enabled) {
			this.enable();
		} else {
			this.disable();
		}
	}

	public get width(): number {
		return dom.getTotalWidth(this.input);
	}

	public set width(width: number) {
		this.input.style.width = width + 'px';
	}

	public showMessage(message: IMessage, force?: boolean): void {
		this.message = message;

		dom.removeClass(this.element, 'idle');
		dom.removeClass(this.element, 'info');
		dom.removeClass(this.element, 'warning');
		dom.removeClass(this.element, 'error');
		dom.addClass(this.element, this.classForType(message.type));

		const styles = this.stylesForType(this.message.type);
		this.element.style.border = styles.border ? `1px solid ${styles.border}` : null;

		// ARIA Support
		let alertText: string;
		if (message.type === MessageType.ERROR) {
			alertText = nls.localize('alertErrorMessage', "Error: {0}", message.content);
		} else if (message.type === MessageType.WARNING) {
			alertText = nls.localize('alertWarningMessage', "Warning: {0}", message.content);
		} else {
			alertText = nls.localize('alertInfoMessage', "Info: {0}", message.content);
		}

		aria.alert(alertText);

		if (this.hasFocus() || force) {
			this._showMessage();
		}
	}

	public hideMessage(): void {
		this.message = null;

		dom.removeClass(this.element, 'info');
		dom.removeClass(this.element, 'warning');
		dom.removeClass(this.element, 'error');
		dom.addClass(this.element, 'idle');

		this._hideMessage();
		this.applyStyles();
	}

	public isInputValid(): boolean {
		return !!this.validation && !this.validation(this.value);
	}

	public validate(): boolean {
		let errorMsg: IMessage | null = null;

		if (this.validation) {
			errorMsg = this.validation(this.value);

			if (errorMsg) {
				this.inputElement.setAttribute('aria-invalid', 'true');
				this.showMessage(errorMsg);
			}
			else if (this.inputElement.hasAttribute('aria-invalid')) {
				this.inputElement.removeAttribute('aria-invalid');
				this.hideMessage();
			}
		}

		return !errorMsg;
	}

	private stylesForType(type: MessageType): { border: Color; background: Color; foreground: Color } {
		switch (type) {
			case MessageType.INFO: return { border: this.inputValidationInfoBorder, background: this.inputValidationInfoBackground, foreground: this.inputValidationInfoForeground };
			case MessageType.WARNING: return { border: this.inputValidationWarningBorder, background: this.inputValidationWarningBackground, foreground: this.inputValidationWarningForeground };
			default: return { border: this.inputValidationErrorBorder, background: this.inputValidationErrorBackground, foreground: this.inputValidationErrorForeground };
		}
	}

	private classForType(type: MessageType): string {
		switch (type) {
			case MessageType.INFO: return 'info';
			case MessageType.WARNING: return 'warning';
			default: return 'error';
		}
	}

	private _showMessage(): void {
		if (!this.contextViewProvider || !this.message) {
			return;
		}

		let div: HTMLElement;
		let layout = () => div.style.width = dom.getTotalWidth(this.element) + 'px';

		this.state = 'open';

		this.contextViewProvider.showContextView({
			getAnchor: () => this.element,
			anchorAlignment: AnchorAlignment.RIGHT,
			render: (container: HTMLElement) => {
				div = dom.append(container, $('.monaco-inputbox-container'));
				layout();

				const renderOptions: RenderOptions = {
					inline: true,
					className: 'monaco-inputbox-message'
				};

				const spanElement = (this.message.formatContent
					? renderFormattedText(this.message.content, renderOptions)
					: renderText(this.message.content, renderOptions));
				dom.addClass(spanElement, this.classForType(this.message.type));

				const styles = this.stylesForType(this.message.type);
				spanElement.style.backgroundColor = styles.background ? styles.background.toString() : null;
				spanElement.style.color = styles.foreground ? styles.foreground.toString() : null;
				spanElement.style.border = styles.border ? `1px solid ${styles.border}` : null;

				dom.append(div, spanElement);

				return null;
			},
			layout: layout
		});
	}

	private _hideMessage(): void {
		if (!this.contextViewProvider || this.state !== 'open') {
			return;
		}

		this.state = 'idle';

		this.contextViewProvider.hideContextView();
	}

	private onValueChange(): void {
		this._onDidChange.fire(this.value);

		this.validate();
		this.updateMirror();

		if (this.state === 'open') {
			this.contextViewProvider.layout();
		}
	}

	private updateMirror(): void {
		if (!this.mirror) {
			return;
		}

		const value = this.value || this.placeholder;
		let lastCharCode = value.charCodeAt(value.length - 1);
		let suffix = lastCharCode === 10 ? ' ' : '';
		this.mirror.textContent = value + suffix;
		this.layout();
	}

	public style(styles: IInputBoxStyles): void {
		this.inputBackground = styles.inputBackground;
		this.inputForeground = styles.inputForeground;
		this.inputBorder = styles.inputBorder;

		this.inputValidationInfoBackground = styles.inputValidationInfoBackground;
		this.inputValidationInfoForeground = styles.inputValidationInfoForeground;
		this.inputValidationInfoBorder = styles.inputValidationInfoBorder;
		this.inputValidationWarningBackground = styles.inputValidationWarningBackground;
		this.inputValidationWarningForeground = styles.inputValidationWarningForeground;
		this.inputValidationWarningBorder = styles.inputValidationWarningBorder;
		this.inputValidationErrorBackground = styles.inputValidationErrorBackground;
		this.inputValidationErrorForeground = styles.inputValidationErrorForeground;
		this.inputValidationErrorBorder = styles.inputValidationErrorBorder;

		this.applyStyles();
	}

	protected applyStyles(): void {
		if (this.element) {
			const background = this.inputBackground ? this.inputBackground.toString() : null;
			const foreground = this.inputForeground ? this.inputForeground.toString() : null;
			const border = this.inputBorder ? this.inputBorder.toString() : null;

			this.element.style.backgroundColor = background;
			this.element.style.color = foreground;
			this.input.style.backgroundColor = background;
			this.input.style.color = foreground;

			this.element.style.borderWidth = border ? '1px' : null;
			this.element.style.borderStyle = border ? 'solid' : null;
			this.element.style.borderColor = border;
		}
	}

	public layout(): void {
		if (!this.mirror) {
			return;
		}

		const previousHeight = this.cachedHeight;
		this.cachedHeight = dom.getTotalHeight(this.mirror);

		if (previousHeight !== this.cachedHeight) {
			this.input.style.height = this.cachedHeight + 'px';
			this._onDidHeightChange.fire(this.cachedHeight);
		}
	}

	public dispose(): void {
		this._hideMessage();

		this.element = null;
		this.input = null;
		this.contextViewProvider = null;
		this.message = null;
		this.placeholder = null;
		this.ariaLabel = null;
		this.validation = null;
		this.state = null;
		this.actionbar = null;

		super.dispose();
	}
}

export interface IHistoryInputOptions extends IInputOptions {
	history: string[];
}

export class HistoryInputBox extends InputBox implements IHistoryNavigationWidget {

	private readonly history: HistoryNavigator<string>;

	constructor(container: HTMLElement, contextViewProvider: IContextViewProvider, options: IHistoryInputOptions) {
		super(container, contextViewProvider, options);
		this.history = new HistoryNavigator<string>(options.history, 100);
	}

	public addToHistory(): void {
		if (this.value && this.value !== this.getCurrentValue()) {
			this.history.add(this.value);
		}
	}

	public getHistory(): string[] {
		return this.history.getHistory();
	}

	public showNextValue(): void {
		if (!this.history.has(this.value)) {
			this.addToHistory();
		}

		let next = this.getNextValue();
		if (next) {
			next = next === this.value ? this.getNextValue() : next;
		}

		if (next) {
			this.value = next;
			aria.status(this.value);
		}
	}

	public showPreviousValue(): void {
		if (!this.history.has(this.value)) {
			this.addToHistory();
		}

		let previous = this.getPreviousValue();
		if (previous) {
			previous = previous === this.value ? this.getPreviousValue() : previous;
		}

		if (previous) {
			this.value = previous;
			aria.status(this.value);
		}
	}

	public clearHistory(): void {
		this.history.clear();
	}

	private getCurrentValue(): string {
		let currentValue = this.history.current();
		if (!currentValue) {
			currentValue = this.history.last();
			this.history.next();
		}
		return currentValue;
	}

	private getPreviousValue(): string {
		return this.history.previous() || this.history.first();
	}

	private getNextValue(): string {
		return this.history.next() || this.history.last();
	}
}
