/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import { IViewlet } from 'vs/workbench/common/viewlet';
import { createDecorator, ServiceIdentifier } from 'vs/platform/instantiation/common/instantiation';
import { Event } from 'vs/base/common/event';
import { ViewletDescriptor } from 'vs/workbench/browser/viewlet';
import { IProgressService } from 'vs/platform/progress/common/progress';

export const IViewletService = createDecorator<IViewletService>('viewletService');

export interface IViewletService {
	_serviceBrand: ServiceIdentifier<any>;

	onDidViewletRegister: Event<ViewletDescriptor>;
	onDidViewletOpen: Event<IViewlet>;
	onDidViewletClose: Event<IViewlet>;
	onDidViewletEnablementChange: Event<{ id: string, enabled: boolean }>;

	/**
	 * Opens a viewlet with the given identifier and pass keyboard focus to it if specified.
	 */
	openViewlet(id: string, focus?: boolean): Thenable<IViewlet>;

	/**
	 * Returns the current active viewlet or null if none.
	 */
	getActiveViewlet(): IViewlet;

	/**
	 * Returns the id of the default viewlet.
	 */
	getDefaultViewletId(): string;

	/**
	 * Returns the viewlet by id.
	 */
	getViewlet(id: string): ViewletDescriptor;

	/**
	 * Returns all enabled viewlets following the default order (Explorer - Search - SCM - Debug - Extensions)
	 */
	getAllViewlets(): ViewletDescriptor[];

	/**
	 * Returns all enabled viewlets
	 */
	getViewlets(): ViewletDescriptor[];

	/**
	 * Enables or disables a viewlet. Disabled viewlets are completly hidden from UI.
	 * By default all viewlets are enabled.
	 */
	setViewletEnablement(id: string, enabled: boolean): void;

	/**
	 *
	 */
	getProgressIndicator(id: string): IProgressService;
}
