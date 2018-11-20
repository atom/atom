/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import { Disposable } from 'vs/base/common/lifecycle';
import { addDisposableListener } from 'vs/base/browser/dom';

/**
 * A helper that will execute a provided function when the provided HTMLElement receives
 *  dragover event for 800ms. If the drag is aborted before, the callback will not be triggered.
 */
export class DelayedDragHandler extends Disposable {
	private timeout: any;

	constructor(container: HTMLElement, callback: () => void) {
		super();

		this._register(addDisposableListener(container, 'dragover', () => {
			if (!this.timeout) {
				this.timeout = setTimeout(() => {
					callback();

					this.timeout = null;
				}, 800);
			}
		}));

		['dragleave', 'drop', 'dragend'].forEach(type => {
			this._register(addDisposableListener(container, type, () => {
				this.clearDragTimeout();
			}));
		});
	}

	private clearDragTimeout(): void {
		if (this.timeout) {
			clearTimeout(this.timeout);
			this.timeout = null;
		}
	}

	dispose(): void {
		super.dispose();

		this.clearDragTimeout();
	}
}

// Common data transfers
export const DataTransfers = {

	/**
	 * Application specific resource transfer type
	 */
	RESOURCES: 'ResourceURLs',

	/**
	 * Browser specific transfer type to download
	 */
	DOWNLOAD_URL: 'DownloadURL',

	/**
	 * Browser specific transfer type for files
	 */
	FILES: 'Files',

	/**
	 * Typicaly transfer type for copy/paste transfers.
	 */
	TEXT: 'text/plain'
};

export function applyDragImage(event: DragEvent, label: string, clazz: string): void {
	const dragImage = document.createElement('div');
	dragImage.className = clazz;
	dragImage.textContent = label;

	if (event.dataTransfer) {
		document.body.appendChild(dragImage);
		event.dataTransfer.setDragImage(dragImage, -10, -10);

		// Removes the element when the DND operation is done
		setTimeout(() => document.body.removeChild(dragImage), 0);
	}
}