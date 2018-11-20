/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import { Position } from 'vs/editor/common/core/position';
import { Range } from 'vs/editor/common/core/range';
import { ViewportData } from 'vs/editor/common/viewLayout/viewLinesViewportData';
import { IViewLayout, ViewModelDecoration } from 'vs/editor/common/viewModel/viewModel';

export interface IViewLines {
	linesVisibleRangesForRange(range: Range, includeNewLines: boolean): LineVisibleRanges[] | null;
	visibleRangeForPosition(position: Position): HorizontalRange | null;
}

export abstract class RestrictedRenderingContext {
	_restrictedRenderingContextBrand: void;

	public readonly viewportData: ViewportData;

	public readonly scrollWidth: number;
	public readonly scrollHeight: number;

	public readonly visibleRange: Range;
	public readonly bigNumbersDelta: number;

	public readonly scrollTop: number;
	public readonly scrollLeft: number;

	public readonly viewportWidth: number;
	public readonly viewportHeight: number;

	private readonly _viewLayout: IViewLayout;

	constructor(viewLayout: IViewLayout, viewportData: ViewportData) {
		this._viewLayout = viewLayout;
		this.viewportData = viewportData;

		this.scrollWidth = this._viewLayout.getScrollWidth();
		this.scrollHeight = this._viewLayout.getScrollHeight();

		this.visibleRange = this.viewportData.visibleRange;
		this.bigNumbersDelta = this.viewportData.bigNumbersDelta;

		const vInfo = this._viewLayout.getCurrentViewport();
		this.scrollTop = vInfo.top;
		this.scrollLeft = vInfo.left;
		this.viewportWidth = vInfo.width;
		this.viewportHeight = vInfo.height;
	}

	public getScrolledTopFromAbsoluteTop(absoluteTop: number): number {
		return absoluteTop - this.scrollTop;
	}

	public getVerticalOffsetForLineNumber(lineNumber: number): number {
		return this._viewLayout.getVerticalOffsetForLineNumber(lineNumber);
	}

	public getDecorationsInViewport(): ViewModelDecoration[] {
		return this.viewportData.getDecorationsInViewport();
	}

}

export class RenderingContext extends RestrictedRenderingContext {
	_renderingContextBrand: void;

	private readonly _viewLines: IViewLines;

	constructor(viewLayout: IViewLayout, viewportData: ViewportData, viewLines: IViewLines) {
		super(viewLayout, viewportData);
		this._viewLines = viewLines;
	}

	public linesVisibleRangesForRange(range: Range, includeNewLines: boolean): LineVisibleRanges[] | null {
		return this._viewLines.linesVisibleRangesForRange(range, includeNewLines);
	}

	public visibleRangeForPosition(position: Position): HorizontalRange | null {
		return this._viewLines.visibleRangeForPosition(position);
	}
}

export class LineVisibleRanges {
	_lineVisibleRangesBrand: void;

	public lineNumber: number;
	public ranges: HorizontalRange[];

	constructor(lineNumber: number, ranges: HorizontalRange[]) {
		this.lineNumber = lineNumber;
		this.ranges = ranges;
	}
}

export class HorizontalRange {
	_horizontalRangeBrand: void;

	public left: number;
	public width: number;

	constructor(left: number, width: number) {
		this.left = Math.round(left);
		this.width = Math.round(width);
	}

	public toString(): string {
		return `[${this.left},${this.width}]`;
	}
}
