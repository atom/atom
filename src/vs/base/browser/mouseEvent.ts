/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import { IframeUtils } from 'vs/base/browser/iframe';

export interface IMouseEvent {
	readonly browserEvent: MouseEvent;
	readonly leftButton: boolean;
	readonly middleButton: boolean;
	readonly rightButton: boolean;
	readonly target: HTMLElement;
	readonly detail: number;
	readonly posx: number;
	readonly posy: number;
	readonly ctrlKey: boolean;
	readonly shiftKey: boolean;
	readonly altKey: boolean;
	readonly metaKey: boolean;
	readonly timestamp: number;

	preventDefault(): void;
	stopPropagation(): void;
}

export class StandardMouseEvent implements IMouseEvent {

	public readonly browserEvent: MouseEvent;

	public readonly leftButton: boolean;
	public readonly middleButton: boolean;
	public readonly rightButton: boolean;
	public readonly target: HTMLElement;
	public detail: number;
	public readonly posx: number;
	public readonly posy: number;
	public readonly ctrlKey: boolean;
	public readonly shiftKey: boolean;
	public readonly altKey: boolean;
	public readonly metaKey: boolean;
	public readonly timestamp: number;

	constructor(e: MouseEvent) {
		this.timestamp = Date.now();
		this.browserEvent = e;
		this.leftButton = e.button === 0;
		this.middleButton = e.button === 1;
		this.rightButton = e.button === 2;

		this.target = <HTMLElement>e.target;

		this.detail = e.detail || 1;
		if (e.type === 'dblclick') {
			this.detail = 2;
		}
		this.ctrlKey = e.ctrlKey;
		this.shiftKey = e.shiftKey;
		this.altKey = e.altKey;
		this.metaKey = e.metaKey;

		if (typeof e.pageX === 'number') {
			this.posx = e.pageX;
			this.posy = e.pageY;
		} else {
			// Probably hit by MSGestureEvent
			this.posx = e.clientX + document.body.scrollLeft + document.documentElement!.scrollLeft;
			this.posy = e.clientY + document.body.scrollTop + document.documentElement!.scrollTop;
		}

		// Find the position of the iframe this code is executing in relative to the iframe where the event was captured.
		let iframeOffsets = IframeUtils.getPositionOfChildWindowRelativeToAncestorWindow(self, e.view);
		this.posx -= iframeOffsets.left;
		this.posy -= iframeOffsets.top;
	}

	public preventDefault(): void {
		if (this.browserEvent.preventDefault) {
			this.browserEvent.preventDefault();
		}
	}

	public stopPropagation(): void {
		if (this.browserEvent.stopPropagation) {
			this.browserEvent.stopPropagation();
		}
	}
}

export interface IDataTransfer {
	dropEffect: string;
	effectAllowed: string;
	types: any[];
	files: any[];

	setData(type: string, data: string): void;
	setDragImage(image: any, x: number, y: number): void;

	getData(type: string): string;
	clearData(types?: string[]): void;
}

export class DragMouseEvent extends StandardMouseEvent {

	public readonly dataTransfer: IDataTransfer;

	constructor(e: MouseEvent) {
		super(e);
		this.dataTransfer = (<any>e).dataTransfer;
	}

}

export class StandardWheelEvent {

	public readonly browserEvent: WheelEvent | null;
	public readonly deltaY: number;
	public readonly deltaX: number;
	public readonly target: Node;

	constructor(e: WheelEvent | null, deltaX: number = 0, deltaY: number = 0) {

		this.browserEvent = e || null;
		this.target = e ? (e.target || (<any>e).targetNode || e.srcElement) : null;

		this.deltaY = deltaY;
		this.deltaX = deltaX;

		if (e) {
			if (e.deltaMode === e.DOM_DELTA_LINE) {
				this.deltaX = -e.deltaX / 3;
				this.deltaY = -e.deltaY / 3;
			} else if (e.deltaMode === e.DOM_DELTA_PIXEL) {
				this.deltaX = -e.deltaX / 40;
				this.deltaY = -e.deltaY / 40;
			}
		}
	}

	public preventDefault(): void {
		if (this.browserEvent) {
			if (this.browserEvent.preventDefault) {
				this.browserEvent.preventDefault();
			}
		}
	}

	public stopPropagation(): void {
		if (this.browserEvent) {
			if (this.browserEvent.stopPropagation) {
				this.browserEvent.stopPropagation();
			}
		}
	}
}
