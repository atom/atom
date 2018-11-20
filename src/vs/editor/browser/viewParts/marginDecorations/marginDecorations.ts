/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import 'vs/css!./marginDecorations';
import { DecorationToRender, DedupOverlay } from 'vs/editor/browser/viewParts/glyphMargin/glyphMargin';
import { RenderingContext } from 'vs/editor/common/view/renderingContext';
import { ViewContext } from 'vs/editor/common/view/viewContext';
import * as viewEvents from 'vs/editor/common/view/viewEvents';

export class MarginViewLineDecorationsOverlay extends DedupOverlay {
	private _context: ViewContext;
	private _renderResult: string[] | null;

	constructor(context: ViewContext) {
		super();
		this._context = context;
		this._renderResult = null;
		this._context.addEventHandler(this);
	}

	public dispose(): void {
		this._context.removeEventHandler(this);
		this._renderResult = null;
		super.dispose();
	}

	// --- begin event handlers

	public onConfigurationChanged(e: viewEvents.ViewConfigurationChangedEvent): boolean {
		return true;
	}
	public onDecorationsChanged(e: viewEvents.ViewDecorationsChangedEvent): boolean {
		return true;
	}
	public onFlushed(e: viewEvents.ViewFlushedEvent): boolean {
		return true;
	}
	public onLinesChanged(e: viewEvents.ViewLinesChangedEvent): boolean {
		return true;
	}
	public onLinesDeleted(e: viewEvents.ViewLinesDeletedEvent): boolean {
		return true;
	}
	public onLinesInserted(e: viewEvents.ViewLinesInsertedEvent): boolean {
		return true;
	}
	public onScrollChanged(e: viewEvents.ViewScrollChangedEvent): boolean {
		return e.scrollTopChanged;
	}
	public onZonesChanged(e: viewEvents.ViewZonesChangedEvent): boolean {
		return true;
	}

	// --- end event handlers

	protected _getDecorations(ctx: RenderingContext): DecorationToRender[] {
		let decorations = ctx.getDecorationsInViewport();
		let r: DecorationToRender[] = [], rLen = 0;
		for (let i = 0, len = decorations.length; i < len; i++) {
			let d = decorations[i];
			let marginClassName = d.options.marginClassName;
			if (marginClassName) {
				r[rLen++] = new DecorationToRender(d.range.startLineNumber, d.range.endLineNumber, marginClassName);
			}
		}
		return r;
	}

	public prepareRender(ctx: RenderingContext): void {
		let visibleStartLineNumber = ctx.visibleRange.startLineNumber;
		let visibleEndLineNumber = ctx.visibleRange.endLineNumber;
		let toRender = this._render(visibleStartLineNumber, visibleEndLineNumber, this._getDecorations(ctx));

		let output: string[] = [];
		for (let lineNumber = visibleStartLineNumber; lineNumber <= visibleEndLineNumber; lineNumber++) {
			let lineIndex = lineNumber - visibleStartLineNumber;
			let classNames = toRender[lineIndex];
			let lineOutput = '';
			for (let i = 0, len = classNames.length; i < len; i++) {
				lineOutput += '<div class="cmdr ' + classNames[i] + '" style=""></div>';
			}
			output[lineIndex] = lineOutput;
		}

		this._renderResult = output;
	}

	public render(startLineNumber: number, lineNumber: number): string {
		if (!this._renderResult) {
			return '';
		}
		return this._renderResult[lineNumber - startLineNumber];
	}
}