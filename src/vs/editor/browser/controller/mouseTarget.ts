/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as browser from 'vs/base/browser/browser';
import { IPointerHandlerHelper } from 'vs/editor/browser/controller/mouseHandler';
import { IMouseTarget, MouseTargetType } from 'vs/editor/browser/editorBrowser';
import { ClientCoordinates, EditorMouseEvent, EditorPagePosition, PageCoordinates } from 'vs/editor/browser/editorDom';
import { PartFingerprint, PartFingerprints } from 'vs/editor/browser/view/viewPart';
import { ViewLine } from 'vs/editor/browser/viewParts/lines/viewLine';
import { IViewCursorRenderData } from 'vs/editor/browser/viewParts/viewCursors/viewCursor';
import { EditorLayoutInfo } from 'vs/editor/common/config/editorOptions';
import { Position } from 'vs/editor/common/core/position';
import { Range as EditorRange } from 'vs/editor/common/core/range';
import { HorizontalRange } from 'vs/editor/common/view/renderingContext';
import { ViewContext } from 'vs/editor/common/view/viewContext';
import { IViewModel } from 'vs/editor/common/viewModel/viewModel';

export interface IViewZoneData {
	viewZoneId: number;
	positionBefore: Position | null;
	positionAfter: Position | null;
	position: Position;
	afterLineNumber: number;
}

export interface IMarginData {
	isAfterLines: boolean;
	glyphMarginLeft: number;
	glyphMarginWidth: number;
	lineNumbersWidth: number;
	offsetX: number;
}

export interface IEmptyContentData {
	isAfterLines: boolean;
	horizontalDistanceToText?: number;
}

interface IETextRange {
	boundingHeight: number;
	boundingLeft: number;
	boundingTop: number;
	boundingWidth: number;
	htmlText: string;
	offsetLeft: number;
	offsetTop: number;
	text: string;
	collapse(start?: boolean): void;
	compareEndPoints(how: string, sourceRange: IETextRange): number;
	duplicate(): IETextRange;
	execCommand(cmdID: string, showUI?: boolean, value?: any): boolean;
	execCommandShowHelp(cmdID: string): boolean;
	expand(Unit: string): boolean;
	findText(string: string, count?: number, flags?: number): boolean;
	getBookmark(): string;
	getBoundingClientRect(): ClientRect;
	getClientRects(): ClientRectList;
	inRange(range: IETextRange): boolean;
	isEqual(range: IETextRange): boolean;
	move(unit: string, count?: number): number;
	moveEnd(unit: string, count?: number): number;
	moveStart(unit: string, count?: number): number;
	moveToBookmark(bookmark: string): boolean;
	moveToElementText(element: Element): void;
	moveToPoint(x: number, y: number): void;
	parentElement(): Element;
	pasteHTML(html: string): void;
	queryCommandEnabled(cmdID: string): boolean;
	queryCommandIndeterm(cmdID: string): boolean;
	queryCommandState(cmdID: string): boolean;
	queryCommandSupported(cmdID: string): boolean;
	queryCommandText(cmdID: string): string;
	queryCommandValue(cmdID: string): any;
	scrollIntoView(fStart?: boolean): void;
	select(): void;
	setEndPoint(how: string, SourceRange: IETextRange): void;
}

declare var IETextRange: {
	prototype: IETextRange;
	new(): IETextRange;
};

interface IHitTestResult {
	position: Position | null;
	hitTarget: Element | null;
}

export class MouseTarget implements IMouseTarget {

	public readonly element: Element | null;
	public readonly type: MouseTargetType;
	public readonly mouseColumn: number;
	public readonly position: Position | null;
	public readonly range: EditorRange | null;
	public readonly detail: any;

	constructor(element: Element | null, type: MouseTargetType, mouseColumn: number = 0, position: Position | null = null, range: EditorRange | null = null, detail: any = null) {
		this.element = element;
		this.type = type;
		this.mouseColumn = mouseColumn;
		this.position = position;
		if (!range && position) {
			range = new EditorRange(position.lineNumber, position.column, position.lineNumber, position.column);
		}
		this.range = range;
		this.detail = detail;
	}

	private static _typeToString(type: MouseTargetType): string {
		if (type === MouseTargetType.TEXTAREA) {
			return 'TEXTAREA';
		}
		if (type === MouseTargetType.GUTTER_GLYPH_MARGIN) {
			return 'GUTTER_GLYPH_MARGIN';
		}
		if (type === MouseTargetType.GUTTER_LINE_NUMBERS) {
			return 'GUTTER_LINE_NUMBERS';
		}
		if (type === MouseTargetType.GUTTER_LINE_DECORATIONS) {
			return 'GUTTER_LINE_DECORATIONS';
		}
		if (type === MouseTargetType.GUTTER_VIEW_ZONE) {
			return 'GUTTER_VIEW_ZONE';
		}
		if (type === MouseTargetType.CONTENT_TEXT) {
			return 'CONTENT_TEXT';
		}
		if (type === MouseTargetType.CONTENT_EMPTY) {
			return 'CONTENT_EMPTY';
		}
		if (type === MouseTargetType.CONTENT_VIEW_ZONE) {
			return 'CONTENT_VIEW_ZONE';
		}
		if (type === MouseTargetType.CONTENT_WIDGET) {
			return 'CONTENT_WIDGET';
		}
		if (type === MouseTargetType.OVERVIEW_RULER) {
			return 'OVERVIEW_RULER';
		}
		if (type === MouseTargetType.SCROLLBAR) {
			return 'SCROLLBAR';
		}
		if (type === MouseTargetType.OVERLAY_WIDGET) {
			return 'OVERLAY_WIDGET';
		}
		return 'UNKNOWN';
	}

	public static toString(target: IMouseTarget): string {
		return this._typeToString(target.type) + ': ' + target.position + ' - ' + target.range + ' - ' + target.detail;
	}

	public toString(): string {
		return MouseTarget.toString(this);
	}
}

class ElementPath {

	public static isTextArea(path: Uint8Array): boolean {
		return (
			path.length === 2
			&& path[0] === PartFingerprint.OverflowGuard
			&& path[1] === PartFingerprint.TextArea
		);
	}

	public static isChildOfViewLines(path: Uint8Array): boolean {
		return (
			path.length >= 4
			&& path[0] === PartFingerprint.OverflowGuard
			&& path[3] === PartFingerprint.ViewLines
		);
	}

	public static isStrictChildOfViewLines(path: Uint8Array): boolean {
		return (
			path.length > 4
			&& path[0] === PartFingerprint.OverflowGuard
			&& path[3] === PartFingerprint.ViewLines
		);
	}

	public static isChildOfScrollableElement(path: Uint8Array): boolean {
		return (
			path.length >= 2
			&& path[0] === PartFingerprint.OverflowGuard
			&& path[1] === PartFingerprint.ScrollableElement
		);
	}

	public static isChildOfMinimap(path: Uint8Array): boolean {
		return (
			path.length >= 2
			&& path[0] === PartFingerprint.OverflowGuard
			&& path[1] === PartFingerprint.Minimap
		);
	}

	public static isChildOfContentWidgets(path: Uint8Array): boolean {
		return (
			path.length >= 4
			&& path[0] === PartFingerprint.OverflowGuard
			&& path[3] === PartFingerprint.ContentWidgets
		);
	}

	public static isChildOfOverflowingContentWidgets(path: Uint8Array): boolean {
		return (
			path.length >= 1
			&& path[0] === PartFingerprint.OverflowingContentWidgets
		);
	}

	public static isChildOfOverlayWidgets(path: Uint8Array): boolean {
		return (
			path.length >= 2
			&& path[0] === PartFingerprint.OverflowGuard
			&& path[1] === PartFingerprint.OverlayWidgets
		);
	}
}

export class HitTestContext {

	public readonly model: IViewModel;
	public readonly layoutInfo: EditorLayoutInfo;
	public readonly viewDomNode: HTMLElement;
	public readonly lineHeight: number;
	public readonly typicalHalfwidthCharacterWidth: number;
	public readonly lastViewCursorsRenderData: IViewCursorRenderData[];

	private readonly _context: ViewContext;
	private readonly _viewHelper: IPointerHandlerHelper;

	constructor(context: ViewContext, viewHelper: IPointerHandlerHelper, lastViewCursorsRenderData: IViewCursorRenderData[]) {
		this.model = context.model;
		this.layoutInfo = context.configuration.editor.layoutInfo;
		this.viewDomNode = viewHelper.viewDomNode;
		this.lineHeight = context.configuration.editor.lineHeight;
		this.typicalHalfwidthCharacterWidth = context.configuration.editor.fontInfo.typicalHalfwidthCharacterWidth;
		this.lastViewCursorsRenderData = lastViewCursorsRenderData;
		this._context = context;
		this._viewHelper = viewHelper;
	}

	public getZoneAtCoord(mouseVerticalOffset: number): IViewZoneData | null {
		return HitTestContext.getZoneAtCoord(this._context, mouseVerticalOffset);
	}

	public static getZoneAtCoord(context: ViewContext, mouseVerticalOffset: number): IViewZoneData | null {
		// The target is either a view zone or the empty space after the last view-line
		let viewZoneWhitespace = context.viewLayout.getWhitespaceAtVerticalOffset(mouseVerticalOffset);

		if (viewZoneWhitespace) {
			let viewZoneMiddle = viewZoneWhitespace.verticalOffset + viewZoneWhitespace.height / 2,
				lineCount = context.model.getLineCount(),
				positionBefore: Position | null = null,
				position: Position | null,
				positionAfter: Position | null = null;

			if (viewZoneWhitespace.afterLineNumber !== lineCount) {
				// There are more lines after this view zone
				positionAfter = new Position(viewZoneWhitespace.afterLineNumber + 1, 1);
			}
			if (viewZoneWhitespace.afterLineNumber > 0) {
				// There are more lines above this view zone
				positionBefore = new Position(viewZoneWhitespace.afterLineNumber, context.model.getLineMaxColumn(viewZoneWhitespace.afterLineNumber));
			}

			if (positionAfter === null) {
				position = positionBefore;
			} else if (positionBefore === null) {
				position = positionAfter;
			} else if (mouseVerticalOffset < viewZoneMiddle) {
				position = positionBefore;
			} else {
				position = positionAfter;
			}

			return {
				viewZoneId: viewZoneWhitespace.id,
				afterLineNumber: viewZoneWhitespace.afterLineNumber,
				positionBefore: positionBefore,
				positionAfter: positionAfter,
				position: position!
			};
		}
		return null;
	}

	public getFullLineRangeAtCoord(mouseVerticalOffset: number): { range: EditorRange; isAfterLines: boolean; } {
		if (this._context.viewLayout.isAfterLines(mouseVerticalOffset)) {
			// Below the last line
			let lineNumber = this._context.model.getLineCount();
			let maxLineColumn = this._context.model.getLineMaxColumn(lineNumber);
			return {
				range: new EditorRange(lineNumber, maxLineColumn, lineNumber, maxLineColumn),
				isAfterLines: true
			};
		}

		let lineNumber = this._context.viewLayout.getLineNumberAtVerticalOffset(mouseVerticalOffset);
		let maxLineColumn = this._context.model.getLineMaxColumn(lineNumber);
		return {
			range: new EditorRange(lineNumber, 1, lineNumber, maxLineColumn),
			isAfterLines: false
		};
	}

	public getLineNumberAtVerticalOffset(mouseVerticalOffset: number): number {
		return this._context.viewLayout.getLineNumberAtVerticalOffset(mouseVerticalOffset);
	}

	public isAfterLines(mouseVerticalOffset: number): boolean {
		return this._context.viewLayout.isAfterLines(mouseVerticalOffset);
	}

	public getVerticalOffsetForLineNumber(lineNumber: number): number {
		return this._context.viewLayout.getVerticalOffsetForLineNumber(lineNumber);
	}

	public findAttribute(element: Element, attr: string): string | null {
		return HitTestContext._findAttribute(element, attr, this._viewHelper.viewDomNode);
	}

	private static _findAttribute(element: Element, attr: string, stopAt: Element): string | null {
		while (element && element !== document.body) {
			if (element.hasAttribute && element.hasAttribute(attr)) {
				return element.getAttribute(attr);
			}
			if (element === stopAt) {
				return null;
			}
			element = <Element>element.parentNode;
		}
		return null;
	}

	public getLineWidth(lineNumber: number): number {
		return this._viewHelper.getLineWidth(lineNumber);
	}

	public visibleRangeForPosition2(lineNumber: number, column: number): HorizontalRange | null {
		return this._viewHelper.visibleRangeForPosition2(lineNumber, column);
	}

	public getPositionFromDOMInfo(spanNode: HTMLElement, offset: number): Position | null {
		return this._viewHelper.getPositionFromDOMInfo(spanNode, offset);
	}

	public getCurrentScrollTop(): number {
		return this._context.viewLayout.getCurrentScrollTop();
	}

	public getCurrentScrollLeft(): number {
		return this._context.viewLayout.getCurrentScrollLeft();
	}
}

abstract class BareHitTestRequest {

	public readonly editorPos: EditorPagePosition;
	public readonly pos: PageCoordinates;
	public readonly mouseVerticalOffset: number;
	public readonly isInMarginArea: boolean;
	public readonly isInContentArea: boolean;
	public readonly mouseContentHorizontalOffset: number;

	protected readonly mouseColumn: number;

	constructor(ctx: HitTestContext, editorPos: EditorPagePosition, pos: PageCoordinates) {
		this.editorPos = editorPos;
		this.pos = pos;

		this.mouseVerticalOffset = Math.max(0, ctx.getCurrentScrollTop() + pos.y - editorPos.y);
		this.mouseContentHorizontalOffset = ctx.getCurrentScrollLeft() + pos.x - editorPos.x - ctx.layoutInfo.contentLeft;
		this.isInMarginArea = (pos.x - editorPos.x < ctx.layoutInfo.contentLeft && pos.x - editorPos.x >= ctx.layoutInfo.glyphMarginLeft);
		this.isInContentArea = !this.isInMarginArea;
		this.mouseColumn = Math.max(0, MouseTargetFactory._getMouseColumn(this.mouseContentHorizontalOffset, ctx.typicalHalfwidthCharacterWidth));
	}
}

class HitTestRequest extends BareHitTestRequest {
	private readonly _ctx: HitTestContext;
	public readonly target: Element | null;
	public readonly targetPath: Uint8Array;

	constructor(ctx: HitTestContext, editorPos: EditorPagePosition, pos: PageCoordinates, target: Element | null) {
		super(ctx, editorPos, pos);
		this._ctx = ctx;

		if (target) {
			this.target = target;
			this.targetPath = PartFingerprints.collect(target, ctx.viewDomNode);
		} else {
			this.target = null;
			this.targetPath = new Uint8Array(0);
		}
	}

	public toString(): string {
		return `pos(${this.pos.x},${this.pos.y}), editorPos(${this.editorPos.x},${this.editorPos.y}), mouseVerticalOffset: ${this.mouseVerticalOffset}, mouseContentHorizontalOffset: ${this.mouseContentHorizontalOffset}\n\ttarget: ${this.target ? (<HTMLElement>this.target).outerHTML : null}`;
	}

	public fulfill(type: MouseTargetType, position: Position | null = null, range: EditorRange | null = null, detail: any = null): MouseTarget {
		return new MouseTarget(this.target, type, this.mouseColumn, position, range, detail);
	}

	public withTarget(target: Element | null): HitTestRequest {
		return new HitTestRequest(this._ctx, this.editorPos, this.pos, target);
	}
}

interface ResolvedHitTestRequest extends HitTestRequest {
	readonly target: Element;
}

const EMPTY_CONTENT_AFTER_LINES: IEmptyContentData = { isAfterLines: true };

function createEmptyContentDataInLines(horizontalDistanceToText: number): IEmptyContentData {
	return {
		isAfterLines: false,
		horizontalDistanceToText: horizontalDistanceToText
	};
}

export class MouseTargetFactory {

	private _context: ViewContext;
	private _viewHelper: IPointerHandlerHelper;

	constructor(context: ViewContext, viewHelper: IPointerHandlerHelper) {
		this._context = context;
		this._viewHelper = viewHelper;
	}

	public mouseTargetIsWidget(e: EditorMouseEvent): boolean {
		let t = <Element>e.target;
		let path = PartFingerprints.collect(t, this._viewHelper.viewDomNode);

		// Is it a content widget?
		if (ElementPath.isChildOfContentWidgets(path) || ElementPath.isChildOfOverflowingContentWidgets(path)) {
			return true;
		}

		// Is it an overlay widget?
		if (ElementPath.isChildOfOverlayWidgets(path)) {
			return true;
		}

		return false;
	}

	public createMouseTarget(lastViewCursorsRenderData: IViewCursorRenderData[], editorPos: EditorPagePosition, pos: PageCoordinates, target: HTMLElement | null): IMouseTarget {
		const ctx = new HitTestContext(this._context, this._viewHelper, lastViewCursorsRenderData);
		const request = new HitTestRequest(ctx, editorPos, pos, target);
		try {
			let r = MouseTargetFactory._createMouseTarget(ctx, request, false);
			// console.log(r.toString());
			return r;
		} catch (err) {
			// console.log(err);
			return request.fulfill(MouseTargetType.UNKNOWN);
		}
	}

	private static _createMouseTarget(ctx: HitTestContext, request: HitTestRequest, domHitTestExecuted: boolean): MouseTarget {

		// console.log(`${domHitTestExecuted ? '=>' : ''}CAME IN REQUEST: ${request}`);

		// First ensure the request has a target
		if (request.target === null) {
			if (domHitTestExecuted) {
				// Still no target... and we have already executed hit test...
				return request.fulfill(MouseTargetType.UNKNOWN);
			}

			const hitTestResult = MouseTargetFactory._doHitTest(ctx, request);

			if (hitTestResult.position) {
				return MouseTargetFactory.createMouseTargetFromHitTestPosition(ctx, request, hitTestResult.position.lineNumber, hitTestResult.position.column);
			}

			return this._createMouseTarget(ctx, request.withTarget(hitTestResult.hitTarget), true);
		}

		// we know for a fact that request.target is not null
		const resolvedRequest = <ResolvedHitTestRequest>request;

		let result: MouseTarget | null = null;

		result = result || MouseTargetFactory._hitTestContentWidget(ctx, resolvedRequest);
		result = result || MouseTargetFactory._hitTestOverlayWidget(ctx, resolvedRequest);
		result = result || MouseTargetFactory._hitTestMinimap(ctx, resolvedRequest);
		result = result || MouseTargetFactory._hitTestScrollbarSlider(ctx, resolvedRequest);
		result = result || MouseTargetFactory._hitTestViewZone(ctx, resolvedRequest);
		result = result || MouseTargetFactory._hitTestMargin(ctx, resolvedRequest);
		result = result || MouseTargetFactory._hitTestViewCursor(ctx, resolvedRequest);
		result = result || MouseTargetFactory._hitTestTextArea(ctx, resolvedRequest);
		result = result || MouseTargetFactory._hitTestViewLines(ctx, resolvedRequest, domHitTestExecuted);
		result = result || MouseTargetFactory._hitTestScrollbar(ctx, resolvedRequest);

		return (result || request.fulfill(MouseTargetType.UNKNOWN));
	}

	private static _hitTestContentWidget(ctx: HitTestContext, request: ResolvedHitTestRequest): MouseTarget | null {
		// Is it a content widget?
		if (ElementPath.isChildOfContentWidgets(request.targetPath) || ElementPath.isChildOfOverflowingContentWidgets(request.targetPath)) {
			let widgetId = ctx.findAttribute(request.target, 'widgetId');
			if (widgetId) {
				return request.fulfill(MouseTargetType.CONTENT_WIDGET, null, null, widgetId);
			} else {
				return request.fulfill(MouseTargetType.UNKNOWN);
			}
		}
		return null;
	}

	private static _hitTestOverlayWidget(ctx: HitTestContext, request: ResolvedHitTestRequest): MouseTarget | null {
		// Is it an overlay widget?
		if (ElementPath.isChildOfOverlayWidgets(request.targetPath)) {
			let widgetId = ctx.findAttribute(request.target, 'widgetId');
			if (widgetId) {
				return request.fulfill(MouseTargetType.OVERLAY_WIDGET, null, null, widgetId);
			} else {
				return request.fulfill(MouseTargetType.UNKNOWN);
			}
		}
		return null;
	}

	private static _hitTestViewCursor(ctx: HitTestContext, request: ResolvedHitTestRequest): MouseTarget | null {

		if (request.target) {
			// Check if we've hit a painted cursor
			const lastViewCursorsRenderData = ctx.lastViewCursorsRenderData;

			for (let i = 0, len = lastViewCursorsRenderData.length; i < len; i++) {
				const d = lastViewCursorsRenderData[i];

				if (request.target === d.domNode) {
					return request.fulfill(MouseTargetType.CONTENT_TEXT, d.position);
				}
			}
		}

		if (request.isInContentArea) {
			// Edge has a bug when hit-testing the exact position of a cursor,
			// instead of returning the correct dom node, it returns the
			// first or last rendered view line dom node, therefore help it out
			// and first check if we are on top of a cursor

			const lastViewCursorsRenderData = ctx.lastViewCursorsRenderData;
			const mouseContentHorizontalOffset = request.mouseContentHorizontalOffset;
			const mouseVerticalOffset = request.mouseVerticalOffset;

			for (let i = 0, len = lastViewCursorsRenderData.length; i < len; i++) {
				const d = lastViewCursorsRenderData[i];

				if (mouseContentHorizontalOffset < d.contentLeft) {
					// mouse position is to the left of the cursor
					continue;
				}
				if (mouseContentHorizontalOffset > d.contentLeft + d.width) {
					// mouse position is to the right of the cursor
					continue;
				}

				const cursorVerticalOffset = ctx.getVerticalOffsetForLineNumber(d.position.lineNumber);

				if (
					cursorVerticalOffset <= mouseVerticalOffset
					&& mouseVerticalOffset <= cursorVerticalOffset + d.height
				) {
					return request.fulfill(MouseTargetType.CONTENT_TEXT, d.position);
				}
			}
		}

		return null;
	}

	private static _hitTestViewZone(ctx: HitTestContext, request: ResolvedHitTestRequest): MouseTarget | null {
		let viewZoneData = ctx.getZoneAtCoord(request.mouseVerticalOffset);
		if (viewZoneData) {
			let mouseTargetType = (request.isInContentArea ? MouseTargetType.CONTENT_VIEW_ZONE : MouseTargetType.GUTTER_VIEW_ZONE);
			return request.fulfill(mouseTargetType, viewZoneData.position, null, viewZoneData);
		}

		return null;
	}

	private static _hitTestTextArea(ctx: HitTestContext, request: ResolvedHitTestRequest): MouseTarget | null {
		// Is it the textarea?
		if (ElementPath.isTextArea(request.targetPath)) {
			return request.fulfill(MouseTargetType.TEXTAREA);
		}
		return null;
	}

	private static _hitTestMargin(ctx: HitTestContext, request: ResolvedHitTestRequest): MouseTarget | null {
		if (request.isInMarginArea) {
			let res = ctx.getFullLineRangeAtCoord(request.mouseVerticalOffset);
			let pos = res.range.getStartPosition();
			let offset = Math.abs(request.pos.x - request.editorPos.x);
			const detail: IMarginData = {
				isAfterLines: res.isAfterLines,
				glyphMarginLeft: ctx.layoutInfo.glyphMarginLeft,
				glyphMarginWidth: ctx.layoutInfo.glyphMarginWidth,
				lineNumbersWidth: ctx.layoutInfo.lineNumbersWidth,
				offsetX: offset
			};

			offset -= ctx.layoutInfo.glyphMarginLeft;

			if (offset <= ctx.layoutInfo.glyphMarginWidth) {
				// On the glyph margin
				return request.fulfill(MouseTargetType.GUTTER_GLYPH_MARGIN, pos, res.range, detail);
			}
			offset -= ctx.layoutInfo.glyphMarginWidth;

			if (offset <= ctx.layoutInfo.lineNumbersWidth) {
				// On the line numbers
				return request.fulfill(MouseTargetType.GUTTER_LINE_NUMBERS, pos, res.range, detail);
			}
			offset -= ctx.layoutInfo.lineNumbersWidth;

			// On the line decorations
			return request.fulfill(MouseTargetType.GUTTER_LINE_DECORATIONS, pos, res.range, detail);
		}
		return null;
	}

	private static _hitTestViewLines(ctx: HitTestContext, request: ResolvedHitTestRequest, domHitTestExecuted: boolean): MouseTarget | null {
		if (!ElementPath.isChildOfViewLines(request.targetPath)) {
			return null;
		}

		// Check if it is below any lines and any view zones
		if (ctx.isAfterLines(request.mouseVerticalOffset)) {
			// This most likely indicates it happened after the last view-line
			const lineCount = ctx.model.getLineCount();
			const maxLineColumn = ctx.model.getLineMaxColumn(lineCount);
			return request.fulfill(MouseTargetType.CONTENT_EMPTY, new Position(lineCount, maxLineColumn), void 0, EMPTY_CONTENT_AFTER_LINES);
		}

		if (domHitTestExecuted) {
			// Check if we are hitting a view-line (can happen in the case of inline decorations on empty lines)
			// See https://github.com/Microsoft/vscode/issues/46942
			if (ElementPath.isStrictChildOfViewLines(request.targetPath)) {
				const lineNumber = ctx.getLineNumberAtVerticalOffset(request.mouseVerticalOffset);
				if (ctx.model.getLineLength(lineNumber) === 0) {
					const lineWidth = ctx.getLineWidth(lineNumber);
					const detail = createEmptyContentDataInLines(request.mouseContentHorizontalOffset - lineWidth);
					return request.fulfill(MouseTargetType.CONTENT_EMPTY, new Position(lineNumber, 1), void 0, detail);
				}
			}

			// We have already executed hit test...
			return request.fulfill(MouseTargetType.UNKNOWN);
		}

		const hitTestResult = MouseTargetFactory._doHitTest(ctx, request);

		if (hitTestResult.position) {
			return MouseTargetFactory.createMouseTargetFromHitTestPosition(ctx, request, hitTestResult.position.lineNumber, hitTestResult.position.column);
		}

		return this._createMouseTarget(ctx, request.withTarget(hitTestResult.hitTarget), true);
	}

	private static _hitTestMinimap(ctx: HitTestContext, request: ResolvedHitTestRequest): MouseTarget | null {
		if (ElementPath.isChildOfMinimap(request.targetPath)) {
			const possibleLineNumber = ctx.getLineNumberAtVerticalOffset(request.mouseVerticalOffset);
			const maxColumn = ctx.model.getLineMaxColumn(possibleLineNumber);
			return request.fulfill(MouseTargetType.SCROLLBAR, new Position(possibleLineNumber, maxColumn));
		}
		return null;
	}

	private static _hitTestScrollbarSlider(ctx: HitTestContext, request: ResolvedHitTestRequest): MouseTarget | null {
		if (ElementPath.isChildOfScrollableElement(request.targetPath)) {
			if (request.target && request.target.nodeType === 1) {
				let className = request.target.className;
				if (className && /\b(slider|scrollbar)\b/.test(className)) {
					const possibleLineNumber = ctx.getLineNumberAtVerticalOffset(request.mouseVerticalOffset);
					const maxColumn = ctx.model.getLineMaxColumn(possibleLineNumber);
					return request.fulfill(MouseTargetType.SCROLLBAR, new Position(possibleLineNumber, maxColumn));
				}
			}
		}
		return null;
	}

	private static _hitTestScrollbar(ctx: HitTestContext, request: ResolvedHitTestRequest): MouseTarget | null {
		// Is it the overview ruler?
		// Is it a child of the scrollable element?
		if (ElementPath.isChildOfScrollableElement(request.targetPath)) {
			const possibleLineNumber = ctx.getLineNumberAtVerticalOffset(request.mouseVerticalOffset);
			const maxColumn = ctx.model.getLineMaxColumn(possibleLineNumber);
			return request.fulfill(MouseTargetType.SCROLLBAR, new Position(possibleLineNumber, maxColumn));
		}

		return null;
	}

	public getMouseColumn(editorPos: EditorPagePosition, pos: PageCoordinates): number {
		let layoutInfo = this._context.configuration.editor.layoutInfo;
		let mouseContentHorizontalOffset = this._context.viewLayout.getCurrentScrollLeft() + pos.x - editorPos.x - layoutInfo.contentLeft;
		return MouseTargetFactory._getMouseColumn(mouseContentHorizontalOffset, this._context.configuration.editor.fontInfo.typicalHalfwidthCharacterWidth);
	}

	public static _getMouseColumn(mouseContentHorizontalOffset: number, typicalHalfwidthCharacterWidth: number): number {
		if (mouseContentHorizontalOffset < 0) {
			return 1;
		}
		let chars = Math.round(mouseContentHorizontalOffset / typicalHalfwidthCharacterWidth);
		return (chars + 1);
	}

	private static createMouseTargetFromHitTestPosition(ctx: HitTestContext, request: HitTestRequest, lineNumber: number, column: number): MouseTarget {
		let pos = new Position(lineNumber, column);

		let lineWidth = ctx.getLineWidth(lineNumber);

		if (request.mouseContentHorizontalOffset > lineWidth) {
			if (browser.isEdge && pos.column === 1) {
				// See https://github.com/Microsoft/vscode/issues/10875
				const detail = createEmptyContentDataInLines(request.mouseContentHorizontalOffset - lineWidth);
				return request.fulfill(MouseTargetType.CONTENT_EMPTY, new Position(lineNumber, ctx.model.getLineMaxColumn(lineNumber)), void 0, detail);
			}
			const detail = createEmptyContentDataInLines(request.mouseContentHorizontalOffset - lineWidth);
			return request.fulfill(MouseTargetType.CONTENT_EMPTY, pos, void 0, detail);
		}

		const visibleRange = ctx.visibleRangeForPosition2(lineNumber, column);

		if (!visibleRange) {
			return request.fulfill(MouseTargetType.UNKNOWN, pos);
		}

		let columnHorizontalOffset = visibleRange.left;

		if (request.mouseContentHorizontalOffset === columnHorizontalOffset) {
			return request.fulfill(MouseTargetType.CONTENT_TEXT, pos);
		}

		// Let's define a, b, c and check if the offset is in between them...
		interface OffsetColumn { offset: number; column: number; }

		let points: OffsetColumn[] = [];
		points.push({ offset: visibleRange.left, column: column });
		if (column > 1) {
			const visibleRange = ctx.visibleRangeForPosition2(lineNumber, column - 1);
			if (visibleRange) {
				points.push({ offset: visibleRange.left, column: column - 1 });
			}
		}
		const lineMaxColumn = ctx.model.getLineMaxColumn(lineNumber);
		if (column < lineMaxColumn) {
			const visibleRange = ctx.visibleRangeForPosition2(lineNumber, column + 1);
			if (visibleRange) {
				points.push({ offset: visibleRange.left, column: column + 1 });
			}
		}

		points.sort((a, b) => a.offset - b.offset);

		for (let i = 1; i < points.length; i++) {
			const prev = points[i - 1];
			const curr = points[i];
			if (prev.offset <= request.mouseContentHorizontalOffset && request.mouseContentHorizontalOffset <= curr.offset) {
				const rng = new EditorRange(lineNumber, prev.column, lineNumber, curr.column);
				return request.fulfill(MouseTargetType.CONTENT_TEXT, pos, rng);
			}
		}
		return request.fulfill(MouseTargetType.CONTENT_TEXT, pos);
	}

	/**
	 * Most probably WebKit browsers and Edge
	 */
	private static _doHitTestWithCaretRangeFromPoint(ctx: HitTestContext, request: BareHitTestRequest): IHitTestResult {

		// In Chrome, especially on Linux it is possible to click between lines,
		// so try to adjust the `hity` below so that it lands in the center of a line
		let lineNumber = ctx.getLineNumberAtVerticalOffset(request.mouseVerticalOffset);
		let lineVerticalOffset = ctx.getVerticalOffsetForLineNumber(lineNumber);
		let lineCenteredVerticalOffset = lineVerticalOffset + Math.floor(ctx.lineHeight / 2);
		let adjustedPageY = request.pos.y + (lineCenteredVerticalOffset - request.mouseVerticalOffset);

		if (adjustedPageY <= request.editorPos.y) {
			adjustedPageY = request.editorPos.y + 1;
		}
		if (adjustedPageY >= request.editorPos.y + ctx.layoutInfo.height) {
			adjustedPageY = request.editorPos.y + ctx.layoutInfo.height - 1;
		}

		let adjustedPage = new PageCoordinates(request.pos.x, adjustedPageY);

		let r = this._actualDoHitTestWithCaretRangeFromPoint(ctx, adjustedPage.toClientCoordinates());
		if (r.position) {
			return r;
		}

		// Also try to hit test without the adjustment (for the edge cases that we are near the top or bottom)
		return this._actualDoHitTestWithCaretRangeFromPoint(ctx, request.pos.toClientCoordinates());
	}

	private static _actualDoHitTestWithCaretRangeFromPoint(ctx: HitTestContext, coords: ClientCoordinates): IHitTestResult {

		let range: Range = document.caretRangeFromPoint(coords.clientX, coords.clientY);

		if (!range || !range.startContainer) {
			return {
				position: null,
				hitTarget: null
			};
		}

		// Chrome always hits a TEXT_NODE, while Edge sometimes hits a token span
		let startContainer = range.startContainer;
		let hitTarget: HTMLElement | null = null;

		if (startContainer.nodeType === startContainer.TEXT_NODE) {
			// startContainer is expected to be the token text
			let parent1 = startContainer.parentNode; // expected to be the token span
			let parent2 = parent1 ? parent1.parentNode : null; // expected to be the view line container span
			let parent3 = parent2 ? parent2.parentNode : null; // expected to be the view line div
			let parent3ClassName = parent3 && parent3.nodeType === parent3.ELEMENT_NODE ? (<HTMLElement>parent3).className : null;

			if (parent3ClassName === ViewLine.CLASS_NAME) {
				let p = ctx.getPositionFromDOMInfo(<HTMLElement>parent1, range.startOffset);
				return {
					position: p,
					hitTarget: null
				};
			} else {
				hitTarget = <HTMLElement>startContainer.parentNode;
			}
		} else if (startContainer.nodeType === startContainer.ELEMENT_NODE) {
			// startContainer is expected to be the token span
			let parent1 = startContainer.parentNode; // expected to be the view line container span
			let parent2 = parent1 ? parent1.parentNode : null; // expected to be the view line div
			let parent2ClassName = parent2 && parent2.nodeType === parent2.ELEMENT_NODE ? (<HTMLElement>parent2).className : null;

			if (parent2ClassName === ViewLine.CLASS_NAME) {
				let p = ctx.getPositionFromDOMInfo(<HTMLElement>startContainer, (<HTMLElement>startContainer).textContent!.length);
				return {
					position: p,
					hitTarget: null
				};
			} else {
				hitTarget = <HTMLElement>startContainer;
			}
		}

		return {
			position: null,
			hitTarget: hitTarget
		};
	}

	/**
	 * Most probably Gecko
	 */
	private static _doHitTestWithCaretPositionFromPoint(ctx: HitTestContext, coords: ClientCoordinates): IHitTestResult {
		let hitResult: { offsetNode: Node; offset: number; } = (<any>document).caretPositionFromPoint(coords.clientX, coords.clientY);

		if (hitResult.offsetNode.nodeType === hitResult.offsetNode.TEXT_NODE) {
			// offsetNode is expected to be the token text
			let parent1 = hitResult.offsetNode.parentNode; // expected to be the token span
			let parent2 = parent1 ? parent1.parentNode : null; // expected to be the view line container span
			let parent3 = parent2 ? parent2.parentNode : null; // expected to be the view line div
			let parent3ClassName = parent3 && parent3.nodeType === parent3.ELEMENT_NODE ? (<HTMLElement>parent3).className : null;

			if (parent3ClassName === ViewLine.CLASS_NAME) {
				let p = ctx.getPositionFromDOMInfo(<HTMLElement>hitResult.offsetNode.parentNode, hitResult.offset);
				return {
					position: p,
					hitTarget: null
				};
			} else {
				return {
					position: null,
					hitTarget: <HTMLElement>hitResult.offsetNode.parentNode
				};
			}
		}

		return {
			position: null,
			hitTarget: <HTMLElement>hitResult.offsetNode
		};
	}

	/**
	 * Most probably IE
	 */
	private static _doHitTestWithMoveToPoint(ctx: HitTestContext, coords: ClientCoordinates): IHitTestResult {
		let resultPosition: Position | null = null;
		let resultHitTarget: Element | null = null;

		let textRange: IETextRange = (<any>document.body).createTextRange();
		try {
			textRange.moveToPoint(coords.clientX, coords.clientY);
		} catch (err) {
			return {
				position: null,
				hitTarget: null
			};
		}

		textRange.collapse(true);

		// Now, let's do our best to figure out what we hit :)
		let parentElement = textRange ? textRange.parentElement() : null;
		let parent1 = parentElement ? parentElement.parentNode : null;
		let parent2 = parent1 ? parent1.parentNode : null;

		let parent2ClassName = parent2 && parent2.nodeType === parent2.ELEMENT_NODE ? (<HTMLElement>parent2).className : '';

		if (parent2ClassName === ViewLine.CLASS_NAME) {
			let rangeToContainEntireSpan = textRange.duplicate();
			rangeToContainEntireSpan.moveToElementText(parentElement!);
			rangeToContainEntireSpan.setEndPoint('EndToStart', textRange);

			resultPosition = ctx.getPositionFromDOMInfo(<HTMLElement>parentElement, rangeToContainEntireSpan.text.length);
			// Move range out of the span node, IE doesn't like having many ranges in
			// the same spot and will act badly for lines containing dashes ('-')
			rangeToContainEntireSpan.moveToElementText(ctx.viewDomNode);
		} else {
			// Looks like we've hit the hover or something foreign
			resultHitTarget = parentElement;
		}

		// Move range out of the span node, IE doesn't like having many ranges in
		// the same spot and will act badly for lines containing dashes ('-')
		textRange.moveToElementText(ctx.viewDomNode);

		return {
			position: resultPosition,
			hitTarget: resultHitTarget
		};
	}

	private static _doHitTest(ctx: HitTestContext, request: BareHitTestRequest): IHitTestResult {
		// State of the art (18.10.2012):
		// The spec says browsers should support document.caretPositionFromPoint, but nobody implemented it (http://dev.w3.org/csswg/cssom-view/)
		// Gecko:
		//    - they tried to implement it once, but failed: https://bugzilla.mozilla.org/show_bug.cgi?id=654352
		//    - however, they do give out rangeParent/rangeOffset properties on mouse events
		// Webkit:
		//    - they have implemented a previous version of the spec which was using document.caretRangeFromPoint
		// IE:
		//    - they have a proprietary method on ranges, moveToPoint: https://msdn.microsoft.com/en-us/library/ie/ms536632(v=vs.85).aspx

		// 24.08.2016: Edge has added WebKit's document.caretRangeFromPoint, but it is quite buggy
		//    - when hit testing the cursor it returns the first or the last line in the viewport
		//    - it inconsistently hits text nodes or span nodes, while WebKit only hits text nodes
		//    - when toggling render whitespace on, and hit testing in the empty content after a line, it always hits offset 0 of the first span of the line

		// Thank you browsers for making this so 'easy' :)

		if (document.caretRangeFromPoint) {

			return this._doHitTestWithCaretRangeFromPoint(ctx, request);

		} else if ((<any>document).caretPositionFromPoint) {

			return this._doHitTestWithCaretPositionFromPoint(ctx, request.pos.toClientCoordinates());

		} else if ((<any>document.body).createTextRange) {

			return this._doHitTestWithMoveToPoint(ctx, request.pos.toClientCoordinates());

		}

		return {
			position: null,
			hitTarget: null
		};
	}
}
