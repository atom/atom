/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import { BreadcrumbsWidget } from 'vs/base/browser/ui/breadcrumbs/breadcrumbsWidget';
import { Emitter, Event } from 'vs/base/common/event';
import * as glob from 'vs/base/common/glob';
import { IDisposable } from 'vs/base/common/lifecycle';
import { localize } from 'vs/nls';
import { IConfigurationOverrides, IConfigurationService } from 'vs/platform/configuration/common/configuration';
import { Extensions, IConfigurationRegistry } from 'vs/platform/configuration/common/configurationRegistry';
import { registerSingleton } from 'vs/platform/instantiation/common/extensions';
import { createDecorator } from 'vs/platform/instantiation/common/instantiation';
import { Registry } from 'vs/platform/registry/common/platform';
import { GroupIdentifier } from 'vs/workbench/common/editor';

export const IBreadcrumbsService = createDecorator<IBreadcrumbsService>('IEditorBreadcrumbsService');

export interface IBreadcrumbsService {

	_serviceBrand: any;

	register(group: GroupIdentifier, widget: BreadcrumbsWidget): IDisposable;

	getWidget(group: GroupIdentifier): BreadcrumbsWidget;
}


export class BreadcrumbsService implements IBreadcrumbsService {

	_serviceBrand: any;

	private readonly _map = new Map<number, BreadcrumbsWidget>();

	register(group: number, widget: BreadcrumbsWidget): IDisposable {
		if (this._map.has(group)) {
			throw new Error(`group (${group}) has already a widget`);
		}
		this._map.set(group, widget);
		return {
			dispose: () => this._map.delete(group)
		};
	}

	getWidget(group: number): BreadcrumbsWidget {
		return this._map.get(group);
	}
}

registerSingleton(IBreadcrumbsService, BreadcrumbsService);


//#region config

export abstract class BreadcrumbsConfig<T> {

	name: string;
	onDidChange: Event<void>;

	abstract getValue(overrides?: IConfigurationOverrides): T;
	abstract updateValue(value: T, overrides?: IConfigurationOverrides): Thenable<void>;
	abstract dispose(): void;

	private constructor() {
		// internal
	}

	static IsEnabled = BreadcrumbsConfig._stub<boolean>('breadcrumbs.enabled');
	static UseQuickPick = BreadcrumbsConfig._stub<boolean>('breadcrumbs.useQuickPick');
	static FilePath = BreadcrumbsConfig._stub<'on' | 'off' | 'last'>('breadcrumbs.filePath');
	static SymbolPath = BreadcrumbsConfig._stub<'on' | 'off' | 'last'>('breadcrumbs.symbolPath');
	static SymbolSortOrder = BreadcrumbsConfig._stub<'position' | 'name' | 'type'>('breadcrumbs.symbolSortOrder');
	static FilterOnType = BreadcrumbsConfig._stub<boolean>('breadcrumbs.filterOnType');

	static FileExcludes = BreadcrumbsConfig._stub<glob.IExpression>('files.exclude');

	private static _stub<T>(name: string): { bindTo(service: IConfigurationService): BreadcrumbsConfig<T> } {
		return {
			bindTo(service) {
				let onDidChange = new Emitter<void>();

				let listener = service.onDidChangeConfiguration(e => {
					if (e.affectsConfiguration(name)) {
						onDidChange.fire(undefined);
					}
				});

				return new class implements BreadcrumbsConfig<T>{
					readonly name = name;
					readonly onDidChange = onDidChange.event;
					getValue(overrides?: IConfigurationOverrides): T {
						return service.getValue(name, overrides);
					}
					updateValue(newValue: T, overrides?: IConfigurationOverrides): Thenable<void> {
						return service.updateValue(name, newValue, overrides);
					}
					dispose(): void {
						listener.dispose();
						onDidChange.dispose();
					}
				};
			}
		};
	}
}

Registry.as<IConfigurationRegistry>(Extensions.Configuration).registerConfiguration({
	id: 'breadcrumbs',
	title: localize('title', "Breadcrumb Navigation"),
	order: 101,
	type: 'object',
	properties: {
		'breadcrumbs.enabled': {
			description: localize('enabled', "Enable/disable navigation breadcrumbs"),
			type: 'boolean',
			default: false
		},
		// 'breadcrumbs.useQuickPick': {
		// 	description: localize('useQuickPick', "Use quick pick instead of breadcrumb-pickers."),
		// 	type: 'boolean',
		// 	default: false
		// },
		'breadcrumbs.filePath': {
			description: localize('filepath', "Controls whether and how file paths are shown in the breadcrumbs view."),
			type: 'string',
			default: 'on',
			enum: ['on', 'off', 'last'],
			enumDescriptions: [
				localize('filepath.on', "Show the file path in the breadcrumbs view."),
				localize('filepath.off', "Do not show the file path in the breadcrumbs view."),
				localize('filepath.last', "Only show the last element of the file path in the breadcrumbs view."),
			]
		},
		'breadcrumbs.symbolPath': {
			description: localize('symbolpath', "Controls whether and how symbols are shown in the breadcrumbs view."),
			type: 'string',
			default: 'on',
			enum: ['on', 'off', 'last'],
			enumDescriptions: [
				localize('symbolpath.on', "Show all symbols in the breadcrumbs view."),
				localize('symbolpath.off', "Do not show symbols in the breadcrumbs view."),
				localize('symbolpath.last', "Only show the current symbol in the breadcrumbs view."),
			]
		},
		'breadcrumbs.symbolSortOrder': {
			description: localize('symbolSortOrder', "Controls how symbols are sorted in the breadcrumbs outline view."),
			type: 'string',
			default: 'position',
			enum: ['position', 'name', 'type'],
			enumDescriptions: [
				localize('symbolSortOrder.position', "Show symbol outline in file position order."),
				localize('symbolSortOrder.name', "Show symbol outline in alphabetical order."),
				localize('symbolSortOrder.type', "Show symbol outline in symbol type order."),
			]
		},
		// 'breadcrumbs.filterOnType': {
		// 	description: localize('filterOnType', "Controls whether the breadcrumb picker filters or highlights when typing."),
		// 	type: 'boolean',
		// 	default: false
		// },
	}
});

//#endregion
