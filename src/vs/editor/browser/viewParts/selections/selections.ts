/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import 'vs/css!./selections';
import * as browser from 'vs/base/browser/browser';
import { DynamicViewOverlay } from 'vs/editor/browser/view/dynamicViewOverlay';
import { Range } from 'vs/editor/common/core/range';
import { HorizontalRange, LineVisibleRanges, RenderingContext } from 'vs/editor/common/view/renderingContext';
import { ViewContext } from 'vs/editor/common/view/viewContext';
import * as viewEvents from 'vs/editor/common/view/viewEvents';
import { editorInactiveSelection, editorSelectionBackground, editorSelectionForeground } from 'vs/platform/theme/common/colorRegistry';
import { registerThemingParticipant } from 'vs/platform/theme/common/themeService';

const enum CornerStyle {
	EXTERN,
	INTERN,
	FLAT
}

interface IVisibleRangeEndPointStyle {
	top: CornerStyle;
	bottom: CornerStyle;
}

class HorizontalRangeWithStyle {
	public left: number;
	public width: number;
	public startStyle: IVisibleRangeEndPointStyle | null;
	public endStyle: IVisibleRangeEndPointStyle | null;

	constructor(other: HorizontalRange) {
		this.left = other.left;
		this.width = other.width;
		this.startStyle = null;
		this.endStyle = null;
	}
}

class LineVisibleRangesWithStyle {
	public lineNumber: number;
	public ranges: HorizontalRangeWithStyle[];

	constructor(lineNumber: number, ranges: HorizontalRangeWithStyle[]) {
		this.lineNumber = lineNumber;
		this.ranges = ranges;
	}
}

function toStyledRange(item: HorizontalRange): HorizontalRangeWithStyle {
	return new HorizontalRangeWithStyle(item);
}

function toStyled(item: LineVisibleRanges): LineVisibleRangesWithStyle {
	return new LineVisibleRangesWithStyle(item.lineNumber, item.ranges.map(toStyledRange));
}

// TODO@Alex: Remove this once IE11 fixes Bug #524217
// The problem in IE11 is that it does some sort of auto-zooming to accomodate for displays with different pixel density.
// Unfortunately, this auto-zooming is buggy around dealing with rounded borders
const isIEWithZoomingIssuesNearRoundedBorders = browser.isEdgeOrIE;


export class SelectionsOverlay extends DynamicViewOverlay {

	private static readonly SELECTION_CLASS_NAME = 'selected-text';
	private static readonly SELECTION_TOP_LEFT = 'top-left-radius';
	private static readonly SELECTION_BOTTOM_LEFT = 'bottom-left-radius';
	private static readonly SELECTION_TOP_RIGHT = 'top-right-radius';
	private static readonly SELECTION_BOTTOM_RIGHT = 'bottom-right-radius';
	private static readonly EDITOR_BACKGROUND_CLASS_NAME = 'monaco-editor-background';

	private static readonly ROUNDED_PIECE_WIDTH = 10;

	private _context: ViewContext;
	private _lineHeight: number;
	private _roundedSelection: boolean;
	private _typicalHalfwidthCharacterWidth: number;
	private _selections: Range[];
	private _renderResult: string[] | null;

	constructor(context: ViewContext) {
		super();
		this._context = context;
		this._lineHeight = this._context.configuration.editor.lineHeight;
		this._roundedSelection = this._context.configuration.editor.viewInfo.roundedSelection;
		this._typicalHalfwidthCharacterWidth = this._context.configuration.editor.fontInfo.typicalHalfwidthCharacterWidth;
		this._selections = [];
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
		if (e.viewInfo) {
			this._roundedSelection = this._context.configuration.editor.viewInfo.roundedSelection;
		}
		if (e.fontInfo) {
			this._typicalHalfwidthCharacterWidth = this._context.configuration.editor.fontInfo.typicalHalfwidthCharacterWidth;
		}
		return true;
	}
	public onCursorStateChanged(e: viewEvents.ViewCursorStateChangedEvent): boolean {
		this._selections = e.selections.slice(0);
		return true;
	}
	public onDecorationsChanged(e: viewEvents.ViewDecorationsChangedEvent): boolean {
		// true for inline decorations that can end up relayouting text
		return true;//e.inlineDecorationsChanged;
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

	private _visibleRangesHaveGaps(linesVisibleRanges: LineVisibleRangesWithStyle[]): boolean {

		for (let i = 0, len = linesVisibleRanges.length; i < len; i++) {
			let lineVisibleRanges = linesVisibleRanges[i];

			if (lineVisibleRanges.ranges.length > 1) {
				// There are two ranges on the same line
				return true;
			}
		}

		return false;
	}

	private _enrichVisibleRangesWithStyle(viewport: Range, linesVisibleRanges: LineVisibleRangesWithStyle[], previousFrame: LineVisibleRangesWithStyle[] | null): void {
		const epsilon = this._typicalHalfwidthCharacterWidth / 4;
		let previousFrameTop: HorizontalRangeWithStyle | null = null;
		let previousFrameBottom: HorizontalRangeWithStyle | null = null;

		if (previousFrame && previousFrame.length > 0 && linesVisibleRanges.length > 0) {

			let topLineNumber = linesVisibleRanges[0].lineNumber;
			if (topLineNumber === viewport.startLineNumber) {
				for (let i = 0; !previousFrameTop && i < previousFrame.length; i++) {
					if (previousFrame[i].lineNumber === topLineNumber) {
						previousFrameTop = previousFrame[i].ranges[0];
					}
				}
			}

			let bottomLineNumber = linesVisibleRanges[linesVisibleRanges.length - 1].lineNumber;
			if (bottomLineNumber === viewport.endLineNumber) {
				for (let i = previousFrame.length - 1; !previousFrameBottom && i >= 0; i--) {
					if (previousFrame[i].lineNumber === bottomLineNumber) {
						previousFrameBottom = previousFrame[i].ranges[0];
					}
				}
			}

			if (previousFrameTop && !previousFrameTop.startStyle) {
				previousFrameTop = null;
			}
			if (previousFrameBottom && !previousFrameBottom.startStyle) {
				previousFrameBottom = null;
			}
		}

		for (let i = 0, len = linesVisibleRanges.length; i < len; i++) {
			// We know for a fact that there is precisely one range on each line
			let curLineRange = linesVisibleRanges[i].ranges[0];
			let curLeft = curLineRange.left;
			let curRight = curLineRange.left + curLineRange.width;

			let startStyle = {
				top: CornerStyle.EXTERN,
				bottom: CornerStyle.EXTERN
			};

			let endStyle = {
				top: CornerStyle.EXTERN,
				bottom: CornerStyle.EXTERN
			};

			if (i > 0) {
				// Look above
				let prevLeft = linesVisibleRanges[i - 1].ranges[0].left;
				let prevRight = linesVisibleRanges[i - 1].ranges[0].left + linesVisibleRanges[i - 1].ranges[0].width;

				if (abs(curLeft - prevLeft) < epsilon) {
					startStyle.top = CornerStyle.FLAT;
				} else if (curLeft > prevLeft) {
					startStyle.top = CornerStyle.INTERN;
				}

				if (abs(curRight - prevRight) < epsilon) {
					endStyle.top = CornerStyle.FLAT;
				} else if (prevLeft < curRight && curRight < prevRight) {
					endStyle.top = CornerStyle.INTERN;
				}
			} else if (previousFrameTop) {
				// Accept some hick-ups near the viewport edges to save on repaints
				startStyle.top = previousFrameTop.startStyle!.top;
				endStyle.top = previousFrameTop.endStyle!.top;
			}

			if (i + 1 < len) {
				// Look below
				let nextLeft = linesVisibleRanges[i + 1].ranges[0].left;
				let nextRight = linesVisibleRanges[i + 1].ranges[0].left + linesVisibleRanges[i + 1].ranges[0].width;

				if (abs(curLeft - nextLeft) < epsilon) {
					startStyle.bottom = CornerStyle.FLAT;
				} else if (nextLeft < curLeft && curLeft < nextRight) {
					startStyle.bottom = CornerStyle.INTERN;
				}

				if (abs(curRight - nextRight) < epsilon) {
					endStyle.bottom = CornerStyle.FLAT;
				} else if (curRight < nextRight) {
					endStyle.bottom = CornerStyle.INTERN;
				}
			} else if (previousFrameBottom) {
				// Accept some hick-ups near the viewport edges to save on repaints
				startStyle.bottom = previousFrameBottom.startStyle!.bottom;
				endStyle.bottom = previousFrameBottom.endStyle!.bottom;
			}

			curLineRange.startStyle = startStyle;
			curLineRange.endStyle = endStyle;
		}
	}

	private _getVisibleRangesWithStyle(selection: Range, ctx: RenderingContext, previousFrame: LineVisibleRangesWithStyle[] | null): LineVisibleRangesWithStyle[] {
		let _linesVisibleRanges = ctx.linesVisibleRangesForRange(selection, true) || [];
		let linesVisibleRanges = _linesVisibleRanges.map(toStyled);
		let visibleRangesHaveGaps = this._visibleRangesHaveGaps(linesVisibleRanges);

		if (!isIEWithZoomingIssuesNearRoundedBorders && !visibleRangesHaveGaps && this._roundedSelection) {
			this._enrichVisibleRangesWithStyle(ctx.visibleRange, linesVisibleRanges, previousFrame);
		}

		// The visible ranges are sorted TOP-BOTTOM and LEFT-RIGHT
		return linesVisibleRanges;
	}

	private _createSelectionPiece(top: number, height: string, className: string, left: number, width: number): string {
		return (
			'<div class="cslr '
			+ className
			+ '" style="top:'
			+ top.toString()
			+ 'px;left:'
			+ left.toString()
			+ 'px;width:'
			+ width.toString()
			+ 'px;height:'
			+ height
			+ 'px;"></div>'
		);
	}

	private _actualRenderOneSelection(output2: string[], visibleStartLineNumber: number, hasMultipleSelections: boolean, visibleRanges: LineVisibleRangesWithStyle[]): void {
		let visibleRangesHaveStyle = (visibleRanges.length > 0 && visibleRanges[0].ranges[0].startStyle);
		let fullLineHeight = (this._lineHeight).toString();
		let reducedLineHeight = (this._lineHeight - 1).toString();

		let firstLineNumber = (visibleRanges.length > 0 ? visibleRanges[0].lineNumber : 0);
		let lastLineNumber = (visibleRanges.length > 0 ? visibleRanges[visibleRanges.length - 1].lineNumber : 0);

		for (let i = 0, len = visibleRanges.length; i < len; i++) {
			let lineVisibleRanges = visibleRanges[i];
			let lineNumber = lineVisibleRanges.lineNumber;
			let lineIndex = lineNumber - visibleStartLineNumber;

			let lineHeight = hasMultipleSelections ? (lineNumber === lastLineNumber || lineNumber === firstLineNumber ? reducedLineHeight : fullLineHeight) : fullLineHeight;
			let top = hasMultipleSelections ? (lineNumber === firstLineNumber ? 1 : 0) : 0;

			let lineOutput = '';

			for (let j = 0, lenJ = lineVisibleRanges.ranges.length; j < lenJ; j++) {
				let visibleRange = lineVisibleRanges.ranges[j];

				if (visibleRangesHaveStyle) {
					const startStyle = visibleRange.startStyle!;
					const endStyle = visibleRange.endStyle!;
					if (startStyle.top === CornerStyle.INTERN || startStyle.bottom === CornerStyle.INTERN) {
						// Reverse rounded corner to the left

						// First comes the selection (blue layer)
						lineOutput += this._createSelectionPiece(top, lineHeight, SelectionsOverlay.SELECTION_CLASS_NAME, visibleRange.left - SelectionsOverlay.ROUNDED_PIECE_WIDTH, SelectionsOverlay.ROUNDED_PIECE_WIDTH);

						// Second comes the background (white layer) with inverse border radius
						let className = SelectionsOverlay.EDITOR_BACKGROUND_CLASS_NAME;
						if (startStyle.top === CornerStyle.INTERN) {
							className += ' ' + SelectionsOverlay.SELECTION_TOP_RIGHT;
						}
						if (startStyle.bottom === CornerStyle.INTERN) {
							className += ' ' + SelectionsOverlay.SELECTION_BOTTOM_RIGHT;
						}
						lineOutput += this._createSelectionPiece(top, lineHeight, className, visibleRange.left - SelectionsOverlay.ROUNDED_PIECE_WIDTH, SelectionsOverlay.ROUNDED_PIECE_WIDTH);
					}
					if (endStyle.top === CornerStyle.INTERN || endStyle.bottom === CornerStyle.INTERN) {
						// Reverse rounded corner to the right

						// First comes the selection (blue layer)
						lineOutput += this._createSelectionPiece(top, lineHeight, SelectionsOverlay.SELECTION_CLASS_NAME, visibleRange.left + visibleRange.width, SelectionsOverlay.ROUNDED_PIECE_WIDTH);

						// Second comes the background (white layer) with inverse border radius
						let className = SelectionsOverlay.EDITOR_BACKGROUND_CLASS_NAME;
						if (endStyle.top === CornerStyle.INTERN) {
							className += ' ' + SelectionsOverlay.SELECTION_TOP_LEFT;
						}
						if (endStyle.bottom === CornerStyle.INTERN) {
							className += ' ' + SelectionsOverlay.SELECTION_BOTTOM_LEFT;
						}
						lineOutput += this._createSelectionPiece(top, lineHeight, className, visibleRange.left + visibleRange.width, SelectionsOverlay.ROUNDED_PIECE_WIDTH);
					}
				}

				let className = SelectionsOverlay.SELECTION_CLASS_NAME;
				if (visibleRangesHaveStyle) {
					const startStyle = visibleRange.startStyle!;
					const endStyle = visibleRange.endStyle!;
					if (startStyle.top === CornerStyle.EXTERN) {
						className += ' ' + SelectionsOverlay.SELECTION_TOP_LEFT;
					}
					if (startStyle.bottom === CornerStyle.EXTERN) {
						className += ' ' + SelectionsOverlay.SELECTION_BOTTOM_LEFT;
					}
					if (endStyle.top === CornerStyle.EXTERN) {
						className += ' ' + SelectionsOverlay.SELECTION_TOP_RIGHT;
					}
					if (endStyle.bottom === CornerStyle.EXTERN) {
						className += ' ' + SelectionsOverlay.SELECTION_BOTTOM_RIGHT;
					}
				}
				lineOutput += this._createSelectionPiece(top, lineHeight, className, visibleRange.left, visibleRange.width);
			}

			output2[lineIndex] += lineOutput;
		}
	}

	private _previousFrameVisibleRangesWithStyle: (LineVisibleRangesWithStyle[] | null)[] = [];
	public prepareRender(ctx: RenderingContext): void {

		let output: string[] = [];
		let visibleStartLineNumber = ctx.visibleRange.startLineNumber;
		let visibleEndLineNumber = ctx.visibleRange.endLineNumber;
		for (let lineNumber = visibleStartLineNumber; lineNumber <= visibleEndLineNumber; lineNumber++) {
			let lineIndex = lineNumber - visibleStartLineNumber;
			output[lineIndex] = '';
		}

		let thisFrameVisibleRangesWithStyle: (LineVisibleRangesWithStyle[] | null)[] = [];
		for (let i = 0, len = this._selections.length; i < len; i++) {
			let selection = this._selections[i];
			if (selection.isEmpty()) {
				thisFrameVisibleRangesWithStyle[i] = null;
				continue;
			}

			let visibleRangesWithStyle = this._getVisibleRangesWithStyle(selection, ctx, this._previousFrameVisibleRangesWithStyle[i]);
			thisFrameVisibleRangesWithStyle[i] = visibleRangesWithStyle;
			this._actualRenderOneSelection(output, visibleStartLineNumber, this._selections.length > 1, visibleRangesWithStyle);
		}

		this._previousFrameVisibleRangesWithStyle = thisFrameVisibleRangesWithStyle;
		this._renderResult = output;
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

registerThemingParticipant((theme, collector) => {
	const editorSelectionColor = theme.getColor(editorSelectionBackground);
	if (editorSelectionColor) {
		collector.addRule(`.monaco-editor .focused .selected-text { background-color: ${editorSelectionColor}; }`);
	}
	const editorInactiveSelectionColor = theme.getColor(editorInactiveSelection);
	if (editorInactiveSelectionColor) {
		collector.addRule(`.monaco-editor .selected-text { background-color: ${editorInactiveSelectionColor}; }`);
	}
	const editorSelectionForegroundColor = theme.getColor(editorSelectionForeground);
	if (editorSelectionForegroundColor) {
		collector.addRule(`.monaco-editor .view-line span.inline-selected-text { color: ${editorSelectionForegroundColor}; }`);
	}
});

function abs(n: number): number {
	return n < 0 ? -n : n;
}