/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import 'vs/css!../browser/media/exceptionWidget';
import * as nls from 'vs/nls';
import * as dom from 'vs/base/browser/dom';
import { ZoneWidget } from 'vs/editor/contrib/zoneWidget/zoneWidget';
import { ICodeEditor } from 'vs/editor/browser/editorBrowser';
import { IExceptionInfo } from 'vs/workbench/parts/debug/common/debug';
import { RunOnceScheduler } from 'vs/base/common/async';
import { IThemeService, ITheme } from 'vs/platform/theme/common/themeService';
import { Color } from 'vs/base/common/color';
import { registerColor } from 'vs/platform/theme/common/colorRegistry';
import { IInstantiationService } from 'vs/platform/instantiation/common/instantiation';
import { LinkDetector } from 'vs/workbench/parts/debug/browser/linkDetector';
const $ = dom.$;

// theming

export const debugExceptionWidgetBorder = registerColor('debugExceptionWidget.border', { dark: '#a31515', light: '#a31515', hc: '#a31515' }, nls.localize('debugExceptionWidgetBorder', 'Exception widget border color.'));
export const debugExceptionWidgetBackground = registerColor('debugExceptionWidget.background', { dark: '#420b0d', light: '#f1dfde', hc: '#420b0d' }, nls.localize('debugExceptionWidgetBackground', 'Exception widget background color.'));

export class ExceptionWidget extends ZoneWidget {

	private _backgroundColor: Color;

	constructor(editor: ICodeEditor, private exceptionInfo: IExceptionInfo,
		@IThemeService themeService: IThemeService,
		@IInstantiationService private instantiationService: IInstantiationService
	) {
		super(editor, { showFrame: true, showArrow: true, frameWidth: 1, className: 'exception-widget-container' });

		this._backgroundColor = Color.white;

		this._applyTheme(themeService.getTheme());
		this._disposables.push(themeService.onThemeChange(this._applyTheme.bind(this)));


		this.create();
		const onDidLayoutChangeScheduler = new RunOnceScheduler(() => this._doLayout(undefined, undefined), 50);
		this._disposables.push(this.editor.onDidLayoutChange(() => onDidLayoutChangeScheduler.schedule()));
		this._disposables.push(onDidLayoutChangeScheduler);
	}

	private _applyTheme(theme: ITheme): void {
		this._backgroundColor = theme.getColor(debugExceptionWidgetBackground);
		const frameColor = theme.getColor(debugExceptionWidgetBorder);
		this.style({
			arrowColor: frameColor,
			frameColor: frameColor
		}); // style() will trigger _applyStyles
	}

	protected _applyStyles(): void {
		if (this.container) {
			this.container.style.backgroundColor = this._backgroundColor.toString();
		}
		super._applyStyles();
	}

	protected _fillContainer(container: HTMLElement): void {
		this.setCssClass('exception-widget');
		// Set the font size and line height to the one from the editor configuration.
		const fontInfo = this.editor.getConfiguration().fontInfo;
		this.container.style.fontSize = `${fontInfo.fontSize}px`;
		this.container.style.lineHeight = `${fontInfo.lineHeight}px`;

		let title = $('.title');
		title.textContent = this.exceptionInfo.id ? nls.localize('exceptionThrownWithId', 'Exception has occurred: {0}', this.exceptionInfo.id) : nls.localize('exceptionThrown', 'Exception has occurred.');
		dom.append(container, title);

		if (this.exceptionInfo.description) {
			let description = $('.description');
			description.textContent = this.exceptionInfo.description;
			dom.append(container, description);
		}

		if (this.exceptionInfo.details && this.exceptionInfo.details.stackTrace) {
			let stackTrace = $('.stack-trace');
			const linkDetector = this.instantiationService.createInstance(LinkDetector);
			const linkedStackTrace = linkDetector.handleLinks(this.exceptionInfo.details.stackTrace);
			typeof linkedStackTrace === 'string' ? stackTrace.textContent = linkedStackTrace : stackTrace.appendChild(linkedStackTrace);
			dom.append(container, stackTrace);
		}
	}

	protected _doLayout(heightInPixel: number, widthInPixel: number): void {
		// Reload the height with respect to the exception text content and relayout it to match the line count.
		this.container.style.height = 'initial';

		const lineHeight = this.editor.getConfiguration().lineHeight;
		const arrowHeight = Math.round(lineHeight / 3);
		const computedLinesNumber = Math.ceil((this.container.offsetHeight + arrowHeight) / lineHeight);

		this._relayout(computedLinesNumber);
	}
}
