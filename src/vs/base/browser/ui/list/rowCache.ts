/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import { IListRenderer } from './list';
import { IDisposable } from 'vs/base/common/lifecycle';
import { $, removeClass } from 'vs/base/browser/dom';

export interface IRow {
	domNode: HTMLElement | null;
	templateId: string;
	templateData: any;
}

function removeFromParent(element: HTMLElement): void {
	try {
		if (element.parentElement) {
			element.parentElement.removeChild(element);
		}
	} catch (e) {
		// this will throw if this happens due to a blur event, nasty business
	}
}

export class RowCache<T> implements IDisposable {

	private cache = new Map<string, IRow[]>();

	constructor(private renderers: Map<string, IListRenderer<T, any>>) { }

	/**
	 * Returns a row either by creating a new one or reusing
	 * a previously released row which shares the same templateId.
	 */
	alloc(templateId: string): IRow {
		let result = this.getTemplateCache(templateId).pop();

		if (!result) {
			const domNode = $('.monaco-list-row');
			const renderer = this.renderers.get(templateId);
			const templateData = renderer.renderTemplate(domNode);
			result = { domNode, templateId, templateData };
		}

		return result;
	}

	/**
	 * Releases the row for eventual reuse.
	 */
	release(row: IRow): void {
		if (!row) {
			return;
		}

		this.releaseRow(row);
	}

	private releaseRow(row: IRow): void {
		const { domNode, templateId } = row;
		if (domNode) {
			removeClass(domNode, 'scrolling');
			removeFromParent(domNode);
		}

		const cache = this.getTemplateCache(templateId);
		cache.push(row);
	}

	private getTemplateCache(templateId: string): IRow[] {
		let result = this.cache.get(templateId);

		if (!result) {
			result = [];
			this.cache.set(templateId, result);
		}

		return result;
	}

	private garbageCollect(): void {
		if (!this.renderers) {
			return;
		}

		this.cache.forEach((cachedRows, templateId) => {
			for (const cachedRow of cachedRows) {
				const renderer = this.renderers.get(templateId);
				renderer.disposeTemplate(cachedRow.templateData);
				cachedRow.domNode = null;
				cachedRow.templateData = null;
			}
		});

		this.cache.clear();
	}

	dispose(): void {
		this.garbageCollect();
		this.cache.clear();
		this.renderers = null!; // StrictNullOverride: nulling out ok in dispose
	}
}