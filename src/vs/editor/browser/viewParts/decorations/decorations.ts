/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import 'vs/css!./decorations';
import { DynamicViewOverlay } from 'vs/editor/browser/view/dynamicViewOverlay';
import { Range } from 'vs/editor/common/core/range';
import { HorizontalRange, RenderingContext } from 'vs/editor/common/view/renderingContext';
import { ViewContext } from 'vs/editor/common/view/viewContext';
import * as viewEvents from 'vs/editor/common/view/viewEvents';
import { ViewModelDecoration } from 'vs/editor/common/viewModel/viewModel';

export class DecorationsOverlay extends DynamicViewOverlay {

	private _context: ViewContext;
	private _lineHeight: number;
	private _typicalHalfwidthCharacterWidth: number;
	private _renderResult: string[] | null;

	constructor(context: ViewContext) {
		super();
		this._context = context;
		this._lineHeight = this._context.configuration.editor.lineHeight;
		this._typicalHalfwidthCharacterWidth = this._context.configuration.editor.fontInfo.typicalHalfwidthCharacterWidth;
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
		if (e.lineHeight) {
			this._lineHeight = this._context.configuration.editor.lineHeight;
		}
		if (e.fontInfo) {
			this._typicalHalfwidthCharacterWidth = this._context.configuration.editor.fontInfo.typicalHalfwidthCharacterWidth;
		}
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
		return e.scrollTopChanged || e.scrollWidthChanged;
	}
	public onZonesChanged(e: viewEvents.ViewZonesChangedEvent): boolean {
		return true;
	}
	// --- end event handlers

	public prepareRender(ctx: RenderingContext): void {
		let _decorations = ctx.getDecorationsInViewport();

		// Keep only decorations with `className`
		let decorations: ViewModelDecoration[] = [], decorationsLen = 0;
		for (let i = 0, len = _decorations.length; i < len; i++) {
			let d = _decorations[i];
			if (d.options.className) {
				decorations[decorationsLen++] = d;
			}
		}

		// Sort decorations for consistent render output
		decorations = decorations.sort((a, b) => {
			if (a.options.zIndex! < b.options.zIndex!) {
				return -1;
			}
			if (a.options.zIndex! > b.options.zIndex!) {
				return 1;
			}
			const aClassName = a.options.className!;
			const bClassName = b.options.className!;

			if (aClassName < bClassName) {
				return -1;
			}
			if (aClassName > bClassName) {
				return 1;
			}

			return Range.compareRangesUsingStarts(a.range, b.range);
		});

		let visibleStartLineNumber = ctx.visibleRange.startLineNumber;
		let visibleEndLineNumber = ctx.visibleRange.endLineNumber;
		let output: string[] = [];
		for (let lineNumber = visibleStartLineNumber; lineNumber <= visibleEndLineNumber; lineNumber++) {
			let lineIndex = lineNumber - visibleStartLineNumber;
			output[lineIndex] = '';
		}

		// Render first whole line decorations and then regular decorations
		this._renderWholeLineDecorations(ctx, decorations, output);
		this._renderNormalDecorations(ctx, decorations, output);
		this._renderResult = output;
	}

	private _renderWholeLineDecorations(ctx: RenderingContext, decorations: ViewModelDecoration[], output: string[]): void {
		let lineHeight = String(this._lineHeight);
		let visibleStartLineNumber = ctx.visibleRange.startLineNumber;
		let visibleEndLineNumber = ctx.visibleRange.endLineNumber;

		for (let i = 0, lenI = decorations.length; i < lenI; i++) {
			let d = decorations[i];

			if (!d.options.isWholeLine) {
				continue;
			}

			let decorationOutput = (
				'<div class="cdr '
				+ d.options.className
				+ '" style="left:0;width:100%;height:'
				+ lineHeight
				+ 'px;"></div>'
			);

			let startLineNumber = Math.max(d.range.startLineNumber, visibleStartLineNumber);
			let endLineNumber = Math.min(d.range.endLineNumber, visibleEndLineNumber);
			for (let j = startLineNumber; j <= endLineNumber; j++) {
				let lineIndex = j - visibleStartLineNumber;
				output[lineIndex] += decorationOutput;
			}
		}
	}

	private _renderNormalDecorations(ctx: RenderingContext, decorations: ViewModelDecoration[], output: string[]): void {
		const lineHeight = String(this._lineHeight);
		const visibleStartLineNumber = ctx.visibleRange.startLineNumber;

		let prevClassName: string | null = null;
		let prevShowIfCollapsed: boolean = false;
		let prevRange: Range | null = null;

		for (let i = 0, lenI = decorations.length; i < lenI; i++) {
			const d = decorations[i];

			if (d.options.isWholeLine) {
				continue;
			}

			const className = d.options.className!;
			const showIfCollapsed = Boolean(d.options.showIfCollapsed);

			let range = d.range;
			if (showIfCollapsed && range.endColumn === 1 && range.endLineNumber !== range.startLineNumber) {
				range = new Range(range.startLineNumber, range.startColumn, range.endLineNumber - 1, this._context.model.getLineMaxColumn(range.endLineNumber - 1));
			}

			if (prevClassName === className && prevShowIfCollapsed === showIfCollapsed && Range.areIntersectingOrTouching(prevRange!, range)) {
				// merge into previous decoration
				prevRange = Range.plusRange(prevRange!, range);
				continue;
			}

			// flush previous decoration
			if (prevClassName !== null) {
				this._renderNormalDecoration(ctx, prevRange!, prevClassName, prevShowIfCollapsed, lineHeight, visibleStartLineNumber, output);
			}

			prevClassName = className;
			prevShowIfCollapsed = showIfCollapsed;
			prevRange = range;
		}

		if (prevClassName !== null) {
			this._renderNormalDecoration(ctx, prevRange!, prevClassName, prevShowIfCollapsed, lineHeight, visibleStartLineNumber, output);
		}
	}

	private _renderNormalDecoration(ctx: RenderingContext, range: Range, className: string, showIfCollapsed: boolean, lineHeight: string, visibleStartLineNumber: number, output: string[]): void {
		let linesVisibleRanges = ctx.linesVisibleRangesForRange(range, /*TODO@Alex*/className === 'findMatch');
		if (!linesVisibleRanges) {
			return;
		}

		for (let j = 0, lenJ = linesVisibleRanges.length; j < lenJ; j++) {
			let lineVisibleRanges = linesVisibleRanges[j];
			const lineIndex = lineVisibleRanges.lineNumber - visibleStartLineNumber;

			if (showIfCollapsed && lineVisibleRanges.ranges.length === 1) {
				const singleVisibleRange = lineVisibleRanges.ranges[0];
				if (singleVisibleRange.width === 0) {
					// collapsed range case => make the decoration visible by faking its width
					lineVisibleRanges.ranges[0] = new HorizontalRange(singleVisibleRange.left, this._typicalHalfwidthCharacterWidth);
				}
			}

			for (let k = 0, lenK = lineVisibleRanges.ranges.length; k < lenK; k++) {
				const visibleRange = lineVisibleRanges.ranges[k];
				const decorationOutput = (
					'<div class="cdr '
					+ className
					+ '" style="left:'
					+ String(visibleRange.left)
					+ 'px;width:'
					+ String(visibleRange.width)
					+ 'px;height:'
					+ lineHeight
					+ 'px;"></div>'
				);
				output[lineIndex] += decorationOutput;
			}
		}
	}

	public render(startLineNumber: number, lineNumber: number): string {
		if (!this._renderResult) {
			return '';
		}
		let lineIndex = lineNumber - startLineNumber;
		if (lineIndex < 0 || lineIndex >= this._renderResult.length) {
			return '';
		}
		return this._renderResult[lineIndex];
	}
}
