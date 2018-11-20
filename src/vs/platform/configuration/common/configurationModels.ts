/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as json from 'vs/base/common/json';
import { ResourceMap } from 'vs/base/common/map';
import * as arrays from 'vs/base/common/arrays';
import * as types from 'vs/base/common/types';
import * as objects from 'vs/base/common/objects';
import { URI } from 'vs/base/common/uri';
import { OVERRIDE_PROPERTY_PATTERN } from 'vs/platform/configuration/common/configurationRegistry';
import { IOverrides, overrideIdentifierFromKey, addToValueTree, toValuesTree, IConfigurationModel, getConfigurationValue, IConfigurationOverrides, IConfigurationData, getDefaultValues, getConfigurationKeys, IConfigurationChangeEvent, ConfigurationTarget, removeFromValueTree, toOverrides } from 'vs/platform/configuration/common/configuration';
import { Workspace } from 'vs/platform/workspace/common/workspace';

export class ConfigurationModel implements IConfigurationModel {

	private isFrozen: boolean = false;

	constructor(
		private _contents: any = {},
		private _keys: string[] = [],
		private _overrides: IOverrides[] = []
	) {
	}

	get contents(): any {
		return this.checkAndFreeze(this._contents);
	}

	get overrides(): IOverrides[] {
		return this.checkAndFreeze(this._overrides);
	}

	get keys(): string[] {
		return this.checkAndFreeze(this._keys);
	}

	getValue<V>(section: string): V {
		return section ? getConfigurationValue<any>(this.contents, section) : this.contents;
	}

	override(identifier: string): ConfigurationModel {
		const overrideContents = this.getContentsForOverrideIdentifer(identifier);

		if (!overrideContents || typeof overrideContents !== 'object' || !Object.keys(overrideContents).length) {
			// If there are no valid overrides, return self
			return this;
		}

		let contents = {};
		for (const key of arrays.distinct([...Object.keys(this.contents), ...Object.keys(overrideContents)])) {

			let contentsForKey = this.contents[key];
			let overrideContentsForKey = overrideContents[key];

			// If there are override contents for the key, clone and merge otherwise use base contents
			if (overrideContentsForKey) {
				// Clone and merge only if base contents and override contents are of type object otherwise just override
				if (typeof contentsForKey === 'object' && typeof overrideContentsForKey === 'object') {
					contentsForKey = objects.deepClone(contentsForKey);
					this.mergeContents(contentsForKey, overrideContentsForKey);
				} else {
					contentsForKey = overrideContentsForKey;
				}
			}

			contents[key] = contentsForKey;
		}

		return new ConfigurationModel(contents);
	}

	merge(...others: ConfigurationModel[]): ConfigurationModel {
		const contents = objects.deepClone(this.contents);
		const overrides = objects.deepClone(this.overrides);
		const keys = [...this.keys];

		for (const other of others) {
			this.mergeContents(contents, other.contents);

			for (const otherOverride of other.overrides) {
				const [override] = overrides.filter(o => arrays.equals(o.identifiers, otherOverride.identifiers));
				if (override) {
					this.mergeContents(override.contents, otherOverride.contents);
				} else {
					overrides.push(objects.deepClone(otherOverride));
				}
			}
			for (const key of other.keys) {
				if (keys.indexOf(key) === -1) {
					keys.push(key);
				}
			}
		}
		return new ConfigurationModel(contents, keys, overrides);
	}

	freeze(): ConfigurationModel {
		this.isFrozen = true;
		return this;
	}

	private mergeContents(source: any, target: any): void {
		for (const key of Object.keys(target)) {
			if (key in source) {
				if (types.isObject(source[key]) && types.isObject(target[key])) {
					this.mergeContents(source[key], target[key]);
					continue;
				}
			}
			source[key] = objects.deepClone(target[key]);
		}
	}

	private checkAndFreeze<T>(data: T): T {
		if (this.isFrozen && !Object.isFrozen(data)) {
			return objects.deepFreeze(data);
		}
		return data;
	}

	private getContentsForOverrideIdentifer(identifier: string): any {
		for (const override of this.overrides) {
			if (override.identifiers.indexOf(identifier) !== -1) {
				return override.contents;
			}
		}
		return null;
	}

	toJSON(): IConfigurationModel {
		return {
			contents: this.contents,
			overrides: this.overrides,
			keys: this.keys
		};
	}

	// Update methods

	public setValue(key: string, value: any) {
		this.addKey(key);
		addToValueTree(this.contents, key, value, e => { throw new Error(e); });
	}

	public removeValue(key: string): void {
		if (this.removeKey(key)) {
			removeFromValueTree(this.contents, key);
		}
	}

	private addKey(key: string): void {
		let index = this.keys.length;
		for (let i = 0; i < index; i++) {
			if (key.indexOf(this.keys[i]) === 0) {
				index = i;
			}
		}
		this.keys.splice(index, 1, key);
	}

	private removeKey(key: string): boolean {
		let index = this.keys.indexOf(key);
		if (index !== -1) {
			this.keys.splice(index, 1);
			return true;
		}
		return false;
	}
}

export class DefaultConfigurationModel extends ConfigurationModel {

	constructor() {
		const contents = getDefaultValues();
		const keys = getConfigurationKeys();
		const overrides: IOverrides[] = [];
		for (const key of Object.keys(contents)) {
			if (OVERRIDE_PROPERTY_PATTERN.test(key)) {
				overrides.push({
					identifiers: [overrideIdentifierFromKey(key).trim()],
					contents: toValuesTree(contents[key], message => console.error(`Conflict in default settings file: ${message}`))
				});
			}
		}
		super(contents, keys, overrides);
	}
}

export class ConfigurationModelParser {

	private _configurationModel: ConfigurationModel | null = null;
	private _parseErrors: any[] = [];

	constructor(protected readonly _name: string) { }

	get configurationModel(): ConfigurationModel {
		return this._configurationModel || new ConfigurationModel();
	}

	get errors(): any[] {
		return this._parseErrors;
	}

	public parse(content: string): void {
		const raw = this.parseContent(content);
		const configurationModel = this.parseRaw(raw);
		this._configurationModel = new ConfigurationModel(configurationModel.contents, configurationModel.keys, configurationModel.overrides);
	}

	protected parseContent(content: string): any {
		let raw: any = {};
		let currentProperty: string | null = null;
		let currentParent: any = [];
		let previousParents: any[] = [];
		let parseErrors: json.ParseError[] = [];

		function onValue(value: any) {
			if (Array.isArray(currentParent)) {
				(<any[]>currentParent).push(value);
			} else if (currentProperty) {
				currentParent[currentProperty] = value;
			}
		}

		let visitor: json.JSONVisitor = {
			onObjectBegin: () => {
				let object = {};
				onValue(object);
				previousParents.push(currentParent);
				currentParent = object;
				currentProperty = null;
			},
			onObjectProperty: (name: string) => {
				currentProperty = name;
			},
			onObjectEnd: () => {
				currentParent = previousParents.pop();
			},
			onArrayBegin: () => {
				let array: any[] = [];
				onValue(array);
				previousParents.push(currentParent);
				currentParent = array;
				currentProperty = null;
			},
			onArrayEnd: () => {
				currentParent = previousParents.pop();
			},
			onLiteralValue: onValue,
			onError: (error: json.ParseErrorCode, offset: number, length: number) => {
				parseErrors.push({ error, offset, length });
			}
		};
		if (content) {
			try {
				json.visit(content, visitor);
				raw = currentParent[0] || {};
			} catch (e) {
				console.error(`Error while parsing settings file ${this._name}: ${e}`);
				this._parseErrors = [e];
			}
		}

		return raw;
	}

	protected parseRaw(raw: any): IConfigurationModel {
		const contents = toValuesTree(raw, message => console.error(`Conflict in settings file ${this._name}: ${message}`));
		const keys = Object.keys(raw);
		const overrides: IOverrides[] = toOverrides(raw, message => console.error(`Conflict in settings file ${this._name}: ${message}`));
		return { contents, keys, overrides };
	}
}

export class Configuration {

	private _workspaceConsolidatedConfiguration: ConfigurationModel | null = null;
	private _foldersConsolidatedConfigurations: ResourceMap<ConfigurationModel> = new ResourceMap<ConfigurationModel>();

	constructor(
		private _defaultConfiguration: ConfigurationModel,
		private _userConfiguration: ConfigurationModel,
		private _workspaceConfiguration: ConfigurationModel = new ConfigurationModel(),
		private _folderConfigurations: ResourceMap<ConfigurationModel> = new ResourceMap<ConfigurationModel>(),
		private _memoryConfiguration: ConfigurationModel = new ConfigurationModel(),
		private _memoryConfigurationByResource: ResourceMap<ConfigurationModel> = new ResourceMap<ConfigurationModel>(),
		private _freeze: boolean = true) {
	}

	getValue(section: string, overrides: IConfigurationOverrides, workspace: Workspace): any {
		const consolidateConfigurationModel = this.getConsolidateConfigurationModel(overrides, workspace);
		return consolidateConfigurationModel.getValue(section);
	}

	updateValue(key: string, value: any, overrides: IConfigurationOverrides = {}): void {
		let memoryConfiguration: ConfigurationModel;
		if (overrides.resource) {
			memoryConfiguration = this._memoryConfigurationByResource.get(overrides.resource);
			if (!memoryConfiguration) {
				memoryConfiguration = new ConfigurationModel();
				this._memoryConfigurationByResource.set(overrides.resource, memoryConfiguration);
			}
		} else {
			memoryConfiguration = this._memoryConfiguration;
		}

		if (value === void 0) {
			memoryConfiguration.removeValue(key);
		} else {
			memoryConfiguration.setValue(key, value);
		}

		if (!overrides.resource) {
			this._workspaceConsolidatedConfiguration = null;
		}
	}

	inspect<C>(key: string, overrides: IConfigurationOverrides, workspace: Workspace): {
		default: C,
		user: C,
		workspace?: C,
		workspaceFolder?: C
		memory?: C
		value: C,
	} {
		const consolidateConfigurationModel = this.getConsolidateConfigurationModel(overrides, workspace);
		const folderConfigurationModel = this.getFolderConfigurationModelForResource(overrides.resource, workspace);
		const memoryConfigurationModel = overrides.resource ? this._memoryConfigurationByResource.get(overrides.resource) || this._memoryConfiguration : this._memoryConfiguration;
		return {
			default: overrides.overrideIdentifier ? this._defaultConfiguration.freeze().override(overrides.overrideIdentifier).getValue(key) : this._defaultConfiguration.freeze().getValue(key),
			user: overrides.overrideIdentifier ? this._userConfiguration.freeze().override(overrides.overrideIdentifier).getValue(key) : this._userConfiguration.freeze().getValue(key),
			workspace: workspace ? overrides.overrideIdentifier ? this._workspaceConfiguration.freeze().override(overrides.overrideIdentifier).getValue(key) : this._workspaceConfiguration.freeze().getValue(key) : void 0, //Check on workspace exists or not because _workspaceConfiguration is never null
			workspaceFolder: folderConfigurationModel ? overrides.overrideIdentifier ? folderConfigurationModel.freeze().override(overrides.overrideIdentifier).getValue(key) : folderConfigurationModel.freeze().getValue(key) : void 0,
			memory: overrides.overrideIdentifier ? memoryConfigurationModel.freeze().override(overrides.overrideIdentifier).getValue(key) : memoryConfigurationModel.freeze().getValue(key),
			value: consolidateConfigurationModel.getValue(key)
		};
	}

	keys(workspace: Workspace): {
		default: string[];
		user: string[];
		workspace: string[];
		workspaceFolder: string[];
	} {
		const folderConfigurationModel = this.getFolderConfigurationModelForResource(undefined, workspace);
		return {
			default: this._defaultConfiguration.freeze().keys,
			user: this._userConfiguration.freeze().keys,
			workspace: this._workspaceConfiguration.freeze().keys,
			workspaceFolder: folderConfigurationModel ? folderConfigurationModel.freeze().keys : []
		};
	}

	updateDefaultConfiguration(defaultConfiguration: ConfigurationModel): void {
		this._defaultConfiguration = defaultConfiguration;
		this._workspaceConsolidatedConfiguration = null;
		this._foldersConsolidatedConfigurations.clear();
	}

	updateUserConfiguration(userConfiguration: ConfigurationModel): void {
		this._userConfiguration = userConfiguration;
		this._workspaceConsolidatedConfiguration = null;
		this._foldersConsolidatedConfigurations.clear();
	}

	updateWorkspaceConfiguration(workspaceConfiguration: ConfigurationModel): void {
		this._workspaceConfiguration = workspaceConfiguration;
		this._workspaceConsolidatedConfiguration = null;
		this._foldersConsolidatedConfigurations.clear();
	}

	updateFolderConfiguration(resource: URI, configuration: ConfigurationModel): void {
		this._folderConfigurations.set(resource, configuration);
		this._foldersConsolidatedConfigurations.delete(resource);
	}

	deleteFolderConfiguration(resource: URI): void {
		this.folders.delete(resource);
		this._foldersConsolidatedConfigurations.delete(resource);
	}

	get defaults(): ConfigurationModel {
		return this._defaultConfiguration;
	}

	get user(): ConfigurationModel {
		return this._userConfiguration;
	}

	get workspace(): ConfigurationModel {
		return this._workspaceConfiguration;
	}

	protected get folders(): ResourceMap<ConfigurationModel> {
		return this._folderConfigurations;
	}

	private getConsolidateConfigurationModel(overrides: IConfigurationOverrides, workspace: Workspace): ConfigurationModel {
		let configurationModel = this.getConsolidatedConfigurationModelForResource(overrides, workspace);
		return overrides.overrideIdentifier ? configurationModel.override(overrides.overrideIdentifier) : configurationModel;
	}

	private getConsolidatedConfigurationModelForResource({ resource }: IConfigurationOverrides, workspace: Workspace): ConfigurationModel {
		let consolidateConfiguration = this.getWorkspaceConsolidatedConfiguration();

		if (workspace && resource) {
			const root = workspace.getFolder(resource);
			if (root) {
				consolidateConfiguration = this.getFolderConsolidatedConfiguration(root.uri) || consolidateConfiguration;
			}
			const memoryConfigurationForResource = this._memoryConfigurationByResource.get(resource);
			if (memoryConfigurationForResource) {
				consolidateConfiguration = consolidateConfiguration.merge(memoryConfigurationForResource);
			}
		}

		return consolidateConfiguration;
	}

	private getWorkspaceConsolidatedConfiguration(): ConfigurationModel {
		if (!this._workspaceConsolidatedConfiguration) {
			this._workspaceConsolidatedConfiguration = this._defaultConfiguration.merge(this._userConfiguration, this._workspaceConfiguration, this._memoryConfiguration);
			if (this._freeze) {
				this._workspaceConfiguration = this._workspaceConfiguration.freeze();
			}
		}
		return this._workspaceConsolidatedConfiguration;
	}

	private getFolderConsolidatedConfiguration(folder: URI): ConfigurationModel {
		let folderConsolidatedConfiguration = this._foldersConsolidatedConfigurations.get(folder);
		if (!folderConsolidatedConfiguration) {
			const workspaceConsolidateConfiguration = this.getWorkspaceConsolidatedConfiguration();
			const folderConfiguration = this._folderConfigurations.get(folder);
			if (folderConfiguration) {
				folderConsolidatedConfiguration = workspaceConsolidateConfiguration.merge(folderConfiguration);
				if (this._freeze) {
					folderConsolidatedConfiguration = folderConsolidatedConfiguration.freeze();
				}
				this._foldersConsolidatedConfigurations.set(folder, folderConsolidatedConfiguration);
			} else {
				folderConsolidatedConfiguration = workspaceConsolidateConfiguration;
			}
		}
		return folderConsolidatedConfiguration;
	}

	private getFolderConfigurationModelForResource(resource: URI | undefined, workspace: Workspace): ConfigurationModel | null {
		if (workspace && resource) {
			const root = workspace.getFolder(resource);
			if (root) {
				return this._folderConfigurations.get(root.uri);
			}
		}
		return null;
	}

	toData(): IConfigurationData {
		return {
			defaults: {
				contents: this._defaultConfiguration.contents,
				overrides: this._defaultConfiguration.overrides,
				keys: this._defaultConfiguration.keys
			},
			user: {
				contents: this._userConfiguration.contents,
				overrides: this._userConfiguration.overrides,
				keys: this._userConfiguration.keys
			},
			workspace: {
				contents: this._workspaceConfiguration.contents,
				overrides: this._workspaceConfiguration.overrides,
				keys: this._workspaceConfiguration.keys
			},
			folders: this._folderConfigurations.keys().reduce((result, folder) => {
				const { contents, overrides, keys } = this._folderConfigurations.get(folder);
				result[folder.toString()] = { contents, overrides, keys };
				return result;
			}, Object.create({})),
			isComplete: true
		};
	}

	allKeys(workspace: Workspace): string[] {
		let keys = this.keys(workspace);
		let all = [...keys.default];
		const addKeys = (keys) => {
			for (const key of keys) {
				if (all.indexOf(key) === -1) {
					all.push(key);
				}
			}
		};
		addKeys(keys.user);
		addKeys(keys.workspace);
		for (const resource of this.folders.keys()) {
			addKeys(this.folders.get(resource).keys);
		}
		return all;
	}
}

export class AbstractConfigurationChangeEvent {

	protected doesConfigurationContains(configuration: ConfigurationModel, config: string): boolean {
		let changedKeysTree = configuration.contents;
		let requestedTree = toValuesTree({ [config]: true }, () => { });

		let key;
		while (typeof requestedTree === 'object' && (key = Object.keys(requestedTree)[0])) { // Only one key should present, since we added only one property
			changedKeysTree = changedKeysTree[key];
			if (!changedKeysTree) {
				return false; // Requested tree is not found
			}
			requestedTree = requestedTree[key];
		}
		return true;
	}

	protected updateKeys(configuration: ConfigurationModel, keys: string[], resource?: URI): void {
		for (const key of keys) {
			configuration.setValue(key, {});
		}
	}
}

export class ConfigurationChangeEvent extends AbstractConfigurationChangeEvent implements IConfigurationChangeEvent {

	private _source: ConfigurationTarget;
	private _sourceConfig: any;

	constructor(
		private _changedConfiguration: ConfigurationModel = new ConfigurationModel(),
		private _changedConfigurationByResource: ResourceMap<ConfigurationModel> = new ResourceMap<ConfigurationModel>()) {
		super();
	}

	get changedConfiguration(): IConfigurationModel {
		return this._changedConfiguration;
	}

	get changedConfigurationByResource(): ResourceMap<IConfigurationModel> {
		return this._changedConfigurationByResource;
	}

	change(event: ConfigurationChangeEvent): ConfigurationChangeEvent;
	change(keys: string[], resource?: URI): ConfigurationChangeEvent;
	change(arg1: any, arg2?: any): ConfigurationChangeEvent {
		if (arg1 instanceof ConfigurationChangeEvent) {
			this._changedConfiguration = this._changedConfiguration.merge(arg1._changedConfiguration);
			for (const resource of arg1._changedConfigurationByResource.keys()) {
				let changedConfigurationByResource = this.getOrSetChangedConfigurationForResource(resource);
				changedConfigurationByResource = changedConfigurationByResource.merge(arg1._changedConfigurationByResource.get(resource));
				this._changedConfigurationByResource.set(resource, changedConfigurationByResource);
			}
		} else {
			this.changeWithKeys(arg1, arg2);
		}
		return this;
	}

	telemetryData(source: ConfigurationTarget, sourceConfig: any): ConfigurationChangeEvent {
		this._source = source;
		this._sourceConfig = sourceConfig;
		return this;
	}

	get affectedKeys(): string[] {
		const keys = [...this._changedConfiguration.keys];
		this._changedConfigurationByResource.forEach(model => keys.push(...model.keys));
		return arrays.distinct(keys);
	}

	get source(): ConfigurationTarget {
		return this._source;
	}

	get sourceConfig(): any {
		return this._sourceConfig;
	}

	affectsConfiguration(config: string, resource?: URI): boolean {
		let configurationModelsToSearch: ConfigurationModel[] = [this._changedConfiguration];

		if (resource) {
			let model = this._changedConfigurationByResource.get(resource);
			if (model) {
				configurationModelsToSearch.push(model);
			}
		} else {
			configurationModelsToSearch.push(...this._changedConfigurationByResource.values());
		}

		for (const configuration of configurationModelsToSearch) {
			if (this.doesConfigurationContains(configuration, config)) {
				return true;
			}
		}

		return false;
	}

	private changeWithKeys(keys: string[], resource?: URI): void {
		let changedConfiguration = resource ? this.getOrSetChangedConfigurationForResource(resource) : this._changedConfiguration;
		this.updateKeys(changedConfiguration, keys);
	}

	private getOrSetChangedConfigurationForResource(resource: URI): ConfigurationModel {
		let changedConfigurationByResource = this._changedConfigurationByResource.get(resource);
		if (!changedConfigurationByResource) {
			changedConfigurationByResource = new ConfigurationModel();
			this._changedConfigurationByResource.set(resource, changedConfigurationByResource);
		}
		return changedConfigurationByResource;
	}
}
