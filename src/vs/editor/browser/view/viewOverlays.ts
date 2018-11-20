/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import { FastDomNode, createFastDomNode } from 'vs/base/browser/fastDomNode';
import { Configuration } from 'vs/editor/browser/config/configuration';
import { DynamicViewOverlay } from 'vs/editor/browser/view/dynamicViewOverlay';
import { IVisibleLine, IVisibleLinesHost, VisibleLinesCollection } from 'vs/editor/browser/view/viewLayer';
import { ViewPart } from 'vs/editor/browser/view/viewPart';
import { IStringBuilder } from 'vs/editor/common/core/stringBuilder';
import { IConfiguration } from 'vs/editor/common/editorCommon';
import { RenderingContext, RestrictedRenderingContext } from 'vs/editor/common/view/renderingContext';
import { ViewContext } from 'vs/editor/common/view/viewContext';
import * as viewEvents from 'vs/editor/common/view/viewEvents';
import { ViewportData } from 'vs/editor/common/viewLayout/viewLinesViewportData';

export class ViewOverlays extends ViewPart implements IVisibleLinesHost<ViewOverlayLine> {

	private readonly _visibleLines: VisibleLinesCollection<ViewOverlayLine>;
	protected readonly domNode: FastDomNode<HTMLElement>;
	private _dynamicOverlays: DynamicViewOverlay[];
	private _isFocused: boolean;

	constructor(context: ViewContext) {
		super(context);

		this._visibleLines = new VisibleLinesCollection<ViewOverlayLine>(this);
		this.domNode = this._visibleLines.domNode;

		this._dynamicOverlays = [];
		this._isFocused = false;

		this.domNode.setClassName('view-overlays');
	}

	public shouldRender(): boolean {
		if (super.shouldRender()) {
			return true;
		}

		for (let i = 0, len = this._dynamicOverlays.length; i < len; i++) {
			let dynamicOverlay = this._dynamicOverlays[i];
			if (dynamicOverlay.shouldRender()) {
				return true;
			}
		}

		return false;
	}

	public dispose(): void {
		super.dispose();

		for (let i = 0, len = this._dynamicOverlays.length; i < len; i++) {
			let dynamicOverlay = this._dynamicOverlays[i];
			dynamicOverlay.dispose();
		}
		this._dynamicOverlays = [];
	}

	public getDomNode(): FastDomNode<HTMLElement> {
		return this.domNode;
	}

	// ---- begin IVisibleLinesHost

	public createVisibleLine(): ViewOverlayLine {
		return new ViewOverlayLine(this._context.configuration, this._dynamicOverlays);
	}

	// ---- end IVisibleLinesHost

	public addDynamicOverlay(overlay: DynamicViewOverlay): void {
		this._dynamicOverlays.push(overlay);
	}

	// ----- event handlers

	public onConfigurationChanged(e: viewEvents.ViewConfigurationChangedEvent): boolean {
		this._visibleLines.onConfigurationChanged(e);
		let startLineNumber = this._visibleLines.getStartLineNumber();
		let endLineNumber = this._visibleLines.getEndLineNumber();
		for (let lineNumber = startLineNumber; lineNumber <= endLineNumber; lineNumber++) {
			let line = this._visibleLines.getVisibleLine(lineNumber);
			line.onConfigurationChanged(e);
		}
		return true;
	}
	public onFlushed(e: viewEvents.ViewFlushedEvent): boolean {
		return this._visibleLines.onFlushed(e);
	}
	public onFocusChanged(e: viewEvents.ViewFocusChangedEvent): boolean {
		this._isFocused = e.isFocused;
		return true;
	}
	public onLinesChanged(e: viewEvents.ViewLinesChangedEvent): boolean {
		return this._visibleLines.onLinesChanged(e);
	}
	public onLinesDeleted(e: viewEvents.ViewLinesDeletedEvent): boolean {
		return this._visibleLines.onLinesDeleted(e);
	}
	public onLinesInserted(e: viewEvents.ViewLinesInsertedEvent): boolean {
		return this._visibleLines.onLinesInserted(e);
	}
	public onScrollChanged(e: viewEvents.ViewScrollChangedEvent): boolean {
		return this._visibleLines.onScrollChanged(e) || true;
	}
	public onTokensChanged(e: viewEvents.ViewTokensChangedEvent): boolean {
		return this._visibleLines.onTokensChanged(e);
	}
	public onZonesChanged(e: viewEvents.ViewZonesChangedEvent): boolean {
		return this._visibleLines.onZonesChanged(e);
	}

	// ----- end event handlers

	public prepareRender(ctx: RenderingContext): void {
		let toRender = this._dynamicOverlays.filter(overlay => overlay.shouldRender());

		for (let i = 0, len = toRender.length; i < len; i++) {
			let dynamicOverlay = toRender[i];
			dynamicOverlay.prepareRender(ctx);
			dynamicOverlay.onDidRender();
		}
	}

	public render(ctx: RestrictedRenderingContext): void {
		// Overwriting to bypass `shouldRender` flag
		this._viewOverlaysRender(ctx);

		this.domNode.toggleClassName('focused', this._isFocused);
	}

	_viewOverlaysRender(ctx: RestrictedRenderingContext): void {
		this._visibleLines.renderLines(ctx.viewportData);
	}
}

export class ViewOverlayLine implements IVisibleLine {

	private _configuration: IConfiguration;
	private _dynamicOverlays: DynamicViewOverlay[];
	private _domNode: FastDomNode<HTMLElement> | null;
	private _renderedContent: string | null;
	private _lineHeight: number;

	constructor(configuration: IConfiguration, dynamicOverlays: DynamicViewOverlay[]) {
		this._configuration = configuration;
		this._lineHeight = this._configuration.editor.lineHeight;
		this._dynamicOverlays = dynamicOverlays;

		this._domNode = null;
		this._renderedContent = null;
	}

	public getDomNode(): HTMLElement | null {
		if (!this._domNode) {
			return null;
		}
		return this._domNode.domNode;
	}
	public setDomNode(domNode: HTMLElement): void {
		this._domNode = createFastDomNode(domNode);
	}

	public onContentChanged(): void {
		// Nothing
	}
	public onTokensChanged(): void {
		// Nothing
	}
	public onConfigurationChanged(e: viewEvents.ViewConfigurationChangedEvent): void {
		if (e.lineHeight) {
			this._lineHeight = this._configuration.editor.lineHeight;
		}
	}

	public renderLine(lineNumber: number, deltaTop: number, viewportData: ViewportData, sb: IStringBuilder): boolean {
		let result = '';
		for (let i = 0, len = this._dynamicOverlays.length; i < len; i++) {
			let dynamicOverlay = this._dynamicOverlays[i];
			result += dynamicOverlay.render(viewportData.startLineNumber, lineNumber);
		}

		if (this._renderedContent === result) {
			// No rendering needed
			return false;
		}

		this._renderedContent = result;

		sb.appendASCIIString('<div style="position:absolute;top:');
		sb.appendASCIIString(String(deltaTop));
		sb.appendASCIIString('px;width:100%;height:');
		sb.appendASCIIString(String(this._lineHeight));
		sb.appendASCIIString('px;">');
		sb.appendASCIIString(result);
		sb.appendASCIIString('</div>');

		return true;
	}

	public layoutLine(lineNumber: number, deltaTop: number): void {
		if (this._domNode) {
			this._domNode.setTop(deltaTop);
			this._domNode.setHeight(this._lineHeight);
		}
	}
}

export class ContentViewOverlays extends ViewOverlays {

	private _contentWidth: number;

	constructor(context: ViewContext) {
		super(context);

		this._contentWidth = this._context.configuration.editor.layoutInfo.contentWidth;

		this.domNode.setHeight(0);
	}

	// --- begin event handlers

	public onConfigurationChanged(e: viewEvents.ViewConfigurationChangedEvent): boolean {
		if (e.layoutInfo) {
			this._contentWidth = this._context.configuration.editor.layoutInfo.contentWidth;
		}
		return super.onConfigurationChanged(e);
	}
	public onScrollChanged(e: viewEvents.ViewScrollChangedEvent): boolean {
		return super.onScrollChanged(e) || e.scrollWidthChanged;
	}

	// --- end event handlers

	_viewOverlaysRender(ctx: RestrictedRenderingContext): void {
		super._viewOverlaysRender(ctx);

		this.domNode.setWidth(Math.max(ctx.scrollWidth, this._contentWidth));
	}
}

export class MarginViewOverlays extends ViewOverlays {

	private _contentLeft: number;

	constructor(context: ViewContext) {
		super(context);

		this._contentLeft = this._context.configuration.editor.layoutInfo.contentLeft;

		this.domNode.setClassName('margin-view-overlays');
		this.domNode.setWidth(1);

		Configuration.applyFontInfo(this.domNode, this._context.configuration.editor.fontInfo);
	}

	public onConfigurationChanged(e: viewEvents.ViewConfigurationChangedEvent): boolean {
		let shouldRender = false;
		if (e.fontInfo) {
			Configuration.applyFontInfo(this.domNode, this._context.configuration.editor.fontInfo);
			shouldRender = true;
		}
		if (e.layoutInfo) {
			this._contentLeft = this._context.configuration.editor.layoutInfo.contentLeft;
			shouldRender = true;
		}
		return super.onConfigurationChanged(e) || shouldRender;
	}

	public onScrollChanged(e: viewEvents.ViewScrollChangedEvent): boolean {
		return super.onScrollChanged(e) || e.scrollHeightChanged;
	}

	_viewOverlaysRender(ctx: RestrictedRenderingContext): void {
		super._viewOverlaysRender(ctx);
		let height = Math.min(ctx.scrollHeight, 1000000);
		this.domNode.setHeight(height);
		this.domNode.setWidth(this._contentLeft);
	}
}
