/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import 'vs/css!./viewCursors';
import { FastDomNode, createFastDomNode } from 'vs/base/browser/fastDomNode';
import { IntervalTimer, TimeoutTimer } from 'vs/base/common/async';
import { ViewPart } from 'vs/editor/browser/view/viewPart';
import { IViewCursorRenderData, ViewCursor } from 'vs/editor/browser/viewParts/viewCursors/viewCursor';
import { TextEditorCursorBlinkingStyle, TextEditorCursorStyle } from 'vs/editor/common/config/editorOptions';
import { Position } from 'vs/editor/common/core/position';
import { editorCursorBackground, editorCursorForeground } from 'vs/editor/common/view/editorColorRegistry';
import { RenderingContext, RestrictedRenderingContext } from 'vs/editor/common/view/renderingContext';
import { ViewContext } from 'vs/editor/common/view/viewContext';
import * as viewEvents from 'vs/editor/common/view/viewEvents';
import { registerThemingParticipant } from 'vs/platform/theme/common/themeService';

export class ViewCursors extends ViewPart {

	static BLINK_INTERVAL = 500;

	private _readOnly: boolean;
	private _cursorBlinking: TextEditorCursorBlinkingStyle;
	private _cursorStyle: TextEditorCursorStyle;
	private _cursorSmoothCaretAnimation: boolean;
	private _selectionIsEmpty: boolean;

	private _isVisible: boolean;

	private _domNode: FastDomNode<HTMLElement>;

	private _startCursorBlinkAnimation: TimeoutTimer;
	private _cursorFlatBlinkInterval: IntervalTimer;
	private _blinkingEnabled: boolean;

	private _editorHasFocus: boolean;

	private _primaryCursor: ViewCursor;
	private _secondaryCursors: ViewCursor[];
	private _renderData: IViewCursorRenderData[];

	constructor(context: ViewContext) {
		super(context);

		this._readOnly = this._context.configuration.editor.readOnly;
		this._cursorBlinking = this._context.configuration.editor.viewInfo.cursorBlinking;
		this._cursorStyle = this._context.configuration.editor.viewInfo.cursorStyle;
		this._cursorSmoothCaretAnimation = this._context.configuration.editor.viewInfo.cursorSmoothCaretAnimation;
		this._selectionIsEmpty = true;

		this._primaryCursor = new ViewCursor(this._context);
		this._secondaryCursors = [];
		this._renderData = [];

		this._domNode = createFastDomNode(document.createElement('div'));
		this._domNode.setAttribute('role', 'presentation');
		this._domNode.setAttribute('aria-hidden', 'true');
		this._updateDomClassName();

		this._domNode.appendChild(this._primaryCursor.getDomNode());

		this._startCursorBlinkAnimation = new TimeoutTimer();
		this._cursorFlatBlinkInterval = new IntervalTimer();

		this._blinkingEnabled = false;

		this._editorHasFocus = false;
		this._updateBlinking();
	}

	public dispose(): void {
		super.dispose();
		this._startCursorBlinkAnimation.dispose();
		this._cursorFlatBlinkInterval.dispose();
	}

	public getDomNode(): FastDomNode<HTMLElement> {
		return this._domNode;
	}

	// --- begin event handlers

	public onConfigurationChanged(e: viewEvents.ViewConfigurationChangedEvent): boolean {

		if (e.readOnly) {
			this._readOnly = this._context.configuration.editor.readOnly;
		}
		if (e.viewInfo) {
			this._cursorBlinking = this._context.configuration.editor.viewInfo.cursorBlinking;
			this._cursorStyle = this._context.configuration.editor.viewInfo.cursorStyle;
		}

		this._primaryCursor.onConfigurationChanged(e);
		this._updateBlinking();
		if (e.viewInfo) {
			this._updateDomClassName();
		}
		for (let i = 0, len = this._secondaryCursors.length; i < len; i++) {
			this._secondaryCursors[i].onConfigurationChanged(e);
		}
		return true;
	}
	private _onCursorPositionChanged(position: Position, secondaryPositions: Position[]): void {
		this._primaryCursor.onCursorPositionChanged(position);
		this._updateBlinking();

		if (this._secondaryCursors.length < secondaryPositions.length) {
			// Create new cursors
			let addCnt = secondaryPositions.length - this._secondaryCursors.length;
			for (let i = 0; i < addCnt; i++) {
				let newCursor = new ViewCursor(this._context);
				this._domNode.domNode.insertBefore(newCursor.getDomNode().domNode, this._primaryCursor.getDomNode().domNode.nextSibling);
				this._secondaryCursors.push(newCursor);
			}
		} else if (this._secondaryCursors.length > secondaryPositions.length) {
			// Remove some cursors
			let removeCnt = this._secondaryCursors.length - secondaryPositions.length;
			for (let i = 0; i < removeCnt; i++) {
				this._domNode.removeChild(this._secondaryCursors[0].getDomNode());
				this._secondaryCursors.splice(0, 1);
			}
		}

		for (let i = 0; i < secondaryPositions.length; i++) {
			this._secondaryCursors[i].onCursorPositionChanged(secondaryPositions[i]);
		}

	}
	public onCursorStateChanged(e: viewEvents.ViewCursorStateChangedEvent): boolean {
		let positions: Position[] = [];
		for (let i = 0, len = e.selections.length; i < len; i++) {
			positions[i] = e.selections[i].getPosition();
		}
		this._onCursorPositionChanged(positions[0], positions.slice(1));

		const selectionIsEmpty = e.selections[0].isEmpty();
		if (this._selectionIsEmpty !== selectionIsEmpty) {
			this._selectionIsEmpty = selectionIsEmpty;
			this._updateDomClassName();
		}

		return true;
	}

	public onDecorationsChanged(e: viewEvents.ViewDecorationsChangedEvent): boolean {
		// true for inline decorations that can end up relayouting text
		return true;
	}
	public onFlushed(e: viewEvents.ViewFlushedEvent): boolean {
		return true;
	}
	public onFocusChanged(e: viewEvents.ViewFocusChangedEvent): boolean {
		this._editorHasFocus = e.isFocused;
		this._updateBlinking();
		return false;
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
		return true;
	}
	public onTokensChanged(e: viewEvents.ViewTokensChangedEvent): boolean {
		let shouldRender = (position: Position) => {
			for (let i = 0, len = e.ranges.length; i < len; i++) {
				if (e.ranges[i].fromLineNumber <= position.lineNumber && position.lineNumber <= e.ranges[i].toLineNumber) {
					return true;
				}
			}
			return false;
		};
		if (shouldRender(this._primaryCursor.getPosition())) {
			return true;
		}
		for (let i = 0; i < this._secondaryCursors.length; i++) {
			if (shouldRender(this._secondaryCursors[i].getPosition())) {
				return true;
			}
		}
		return false;
	}
	public onZonesChanged(e: viewEvents.ViewZonesChangedEvent): boolean {
		return true;
	}

	// --- end event handlers

	// ---- blinking logic

	private _getCursorBlinking(): TextEditorCursorBlinkingStyle {
		if (!this._editorHasFocus) {
			return TextEditorCursorBlinkingStyle.Hidden;
		}
		if (this._readOnly) {
			return TextEditorCursorBlinkingStyle.Solid;
		}
		return this._cursorBlinking;
	}

	private _updateBlinking(): void {
		this._startCursorBlinkAnimation.cancel();
		this._cursorFlatBlinkInterval.cancel();

		let blinkingStyle = this._getCursorBlinking();

		// hidden and solid are special as they involve no animations
		let isHidden = (blinkingStyle === TextEditorCursorBlinkingStyle.Hidden);
		let isSolid = (blinkingStyle === TextEditorCursorBlinkingStyle.Solid);

		if (isHidden) {
			this._hide();
		} else {
			this._show();
		}

		this._blinkingEnabled = false;
		this._updateDomClassName();

		if (!isHidden && !isSolid) {
			if (blinkingStyle === TextEditorCursorBlinkingStyle.Blink) {
				// flat blinking is handled by JavaScript to save battery life due to Chromium step timing issue https://bugs.chromium.org/p/chromium/issues/detail?id=361587
				this._cursorFlatBlinkInterval.cancelAndSet(() => {
					if (this._isVisible) {
						this._hide();
					} else {
						this._show();
					}
				}, ViewCursors.BLINK_INTERVAL);
			} else {
				this._startCursorBlinkAnimation.setIfNotSet(() => {
					this._blinkingEnabled = true;
					this._updateDomClassName();
				}, ViewCursors.BLINK_INTERVAL);
			}
		}
	}
	// --- end blinking logic

	private _updateDomClassName(): void {
		this._domNode.setClassName(this._getClassName());
	}

	private _getClassName(): string {
		let result = 'cursors-layer';
		if (!this._selectionIsEmpty) {
			result += ' has-selection';
		}
		switch (this._cursorStyle) {
			case TextEditorCursorStyle.Line:
				result += ' cursor-line-style';
				break;
			case TextEditorCursorStyle.Block:
				result += ' cursor-block-style';
				break;
			case TextEditorCursorStyle.Underline:
				result += ' cursor-underline-style';
				break;
			case TextEditorCursorStyle.LineThin:
				result += ' cursor-line-thin-style';
				break;
			case TextEditorCursorStyle.BlockOutline:
				result += ' cursor-block-outline-style';
				break;
			case TextEditorCursorStyle.UnderlineThin:
				result += ' cursor-underline-thin-style';
				break;
			default:
				result += ' cursor-line-style';
		}
		if (this._blinkingEnabled) {
			switch (this._getCursorBlinking()) {
				case TextEditorCursorBlinkingStyle.Blink:
					result += ' cursor-blink';
					break;
				case TextEditorCursorBlinkingStyle.Smooth:
					result += ' cursor-smooth';
					break;
				case TextEditorCursorBlinkingStyle.Phase:
					result += ' cursor-phase';
					break;
				case TextEditorCursorBlinkingStyle.Expand:
					result += ' cursor-expand';
					break;
				case TextEditorCursorBlinkingStyle.Solid:
					result += ' cursor-solid';
					break;
				default:
					result += ' cursor-solid';
			}
		} else {
			result += ' cursor-solid';
		}
		if (this._cursorSmoothCaretAnimation) {
			result += ' cursor-smooth-caret-animation';
		}
		return result;
	}

	private _show(): void {
		this._primaryCursor.show();
		for (let i = 0, len = this._secondaryCursors.length; i < len; i++) {
			this._secondaryCursors[i].show();
		}
		this._isVisible = true;
	}

	private _hide(): void {
		this._primaryCursor.hide();
		for (let i = 0, len = this._secondaryCursors.length; i < len; i++) {
			this._secondaryCursors[i].hide();
		}
		this._isVisible = false;
	}

	// ---- IViewPart implementation

	public prepareRender(ctx: RenderingContext): void {
		this._primaryCursor.prepareRender(ctx);
		for (let i = 0, len = this._secondaryCursors.length; i < len; i++) {
			this._secondaryCursors[i].prepareRender(ctx);
		}
	}

	public render(ctx: RestrictedRenderingContext): void {
		let renderData: IViewCursorRenderData[] = [], renderDataLen = 0;

		const primaryRenderData = this._primaryCursor.render(ctx);
		if (primaryRenderData) {
			renderData[renderDataLen++] = primaryRenderData;
		}

		for (let i = 0, len = this._secondaryCursors.length; i < len; i++) {
			const secondaryRenderData = this._secondaryCursors[i].render(ctx);
			if (secondaryRenderData) {
				renderData[renderDataLen++] = secondaryRenderData;
			}
		}

		this._renderData = renderData;
	}

	public getLastRenderData(): IViewCursorRenderData[] {
		return this._renderData;
	}
}

registerThemingParticipant((theme, collector) => {
	const caret = theme.getColor(editorCursorForeground);
	if (caret) {
		let caretBackground = theme.getColor(editorCursorBackground);
		if (!caretBackground) {
			caretBackground = caret.opposite();
		}
		collector.addRule(`.monaco-editor .cursor { background-color: ${caret}; border-color: ${caret}; color: ${caretBackground}; }`);
		if (theme.type === 'hc') {
			collector.addRule(`.monaco-editor .cursors-layer.has-selection .cursor { border-left: 1px solid ${caretBackground}; border-right: 1px solid ${caretBackground}; }`);
		}
	}

});
