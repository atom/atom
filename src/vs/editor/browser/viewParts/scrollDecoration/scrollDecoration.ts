/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import 'vs/css!./scrollDecoration';
import { FastDomNode, createFastDomNode } from 'vs/base/browser/fastDomNode';
import { ViewPart } from 'vs/editor/browser/view/viewPart';
import { RenderingContext, RestrictedRenderingContext } from 'vs/editor/common/view/renderingContext';
import { ViewContext } from 'vs/editor/common/view/viewContext';
import * as viewEvents from 'vs/editor/common/view/viewEvents';
import { scrollbarShadow } from 'vs/platform/theme/common/colorRegistry';
import { registerThemingParticipant } from 'vs/platform/theme/common/themeService';

export class ScrollDecorationViewPart extends ViewPart {

	private _domNode: FastDomNode<HTMLElement>;
	private _scrollTop: number;
	private _width: number;
	private _shouldShow: boolean;
	private _useShadows: boolean;

	constructor(context: ViewContext) {
		super(context);

		this._scrollTop = 0;
		this._width = 0;
		this._updateWidth();
		this._shouldShow = false;
		this._useShadows = this._context.configuration.editor.viewInfo.scrollbar.useShadows;
		this._domNode = createFastDomNode(document.createElement('div'));
		this._domNode.setAttribute('role', 'presentation');
		this._domNode.setAttribute('aria-hidden', 'true');
	}

	public dispose(): void {
		super.dispose();
	}

	private _updateShouldShow(): boolean {
		let newShouldShow = (this._useShadows && this._scrollTop > 0);
		if (this._shouldShow !== newShouldShow) {
			this._shouldShow = newShouldShow;
			return true;
		}
		return false;
	}

	public getDomNode(): FastDomNode<HTMLElement> {
		return this._domNode;
	}

	private _updateWidth(): boolean {
		const layoutInfo = this._context.configuration.editor.layoutInfo;
		let newWidth = 0;
		if (layoutInfo.renderMinimap === 0 || (layoutInfo.minimapWidth > 0 && layoutInfo.minimapLeft === 0)) {
			newWidth = layoutInfo.width;
		} else {
			newWidth = layoutInfo.width - layoutInfo.minimapWidth - layoutInfo.verticalScrollbarWidth;
		}
		if (this._width !== newWidth) {
			this._width = newWidth;
			return true;
		}
		return false;
	}

	// --- begin event handlers

	public onConfigurationChanged(e: viewEvents.ViewConfigurationChangedEvent): boolean {
		let shouldRender = false;
		if (e.viewInfo) {
			this._useShadows = this._context.configuration.editor.viewInfo.scrollbar.useShadows;
		}
		if (e.layoutInfo) {
			shouldRender = this._updateWidth();
		}
		return this._updateShouldShow() || shouldRender;
	}
	public onScrollChanged(e: viewEvents.ViewScrollChangedEvent): boolean {
		this._scrollTop = e.scrollTop;
		return this._updateShouldShow();
	}

	// --- end event handlers

	public prepareRender(ctx: RenderingContext): void {
		// Nothing to read
	}

	public render(ctx: RestrictedRenderingContext): void {
		this._domNode.setWidth(this._width);
		this._domNode.setClassName(this._shouldShow ? 'scroll-decoration' : '');
	}
}

registerThemingParticipant((theme, collector) => {
	const shadow = theme.getColor(scrollbarShadow);
	if (shadow) {
		collector.addRule(`.monaco-editor .scroll-decoration { box-shadow: ${shadow} 0 6px 6px -6px inset; }`);
	}
});