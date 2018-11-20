/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as nls from 'vs/nls';
import { Event, Emitter } from 'vs/base/common/event';
import { IJSONSchema } from 'vs/base/common/jsonSchema';
import { Registry } from 'vs/platform/registry/common/platform';
import * as types from 'vs/base/common/types';
import * as strings from 'vs/base/common/strings';
import { IJSONContributionRegistry, Extensions as JSONExtensions } from 'vs/platform/jsonschemas/common/jsonContributionRegistry';

export const Extensions = {
	Configuration: 'base.contributions.configuration'
};

export interface IConfigurationRegistry {

	/**
	 * Register a configuration to the registry.
	 */
	registerConfiguration(configuration: IConfigurationNode): void;

	/**
	 * Register multiple configurations to the registry.
	 */
	registerConfigurations(configurations: IConfigurationNode[], defaultConfigurations: IDefaultConfigurationExtension[], validate?: boolean): void;

	/**
	 * Signal that the schema of a configuration setting has changes. It is currently only supported to change enumeration values.
	 * Property or default value changes are not allowed.
	 */
	notifyConfigurationSchemaUpdated(configuration: IConfigurationNode): void;

	/**
	 * Event that fires whenver a configuration has been
	 * registered.
	 */
	onDidSchemaChange: Event<void>;

	/**
	 * Event that fires whenver a configuration has been
	 * registered.
	 */
	onDidRegisterConfiguration: Event<string[]>;

	/**
	 * Returns all configuration nodes contributed to this registry.
	 */
	getConfigurations(): IConfigurationNode[];

	/**
	 * Returns all configurations settings of all configuration nodes contributed to this registry.
	 */
	getConfigurationProperties(): { [qualifiedKey: string]: IConfigurationPropertySchema };

	/**
	 * Returns all excluded configurations settings of all configuration nodes contributed to this registry.
	 */
	getExcludedConfigurationProperties(): { [qualifiedKey: string]: IConfigurationPropertySchema };

	/**
	 * Register the identifiers for editor configurations
	 */
	registerOverrideIdentifiers(identifiers: string[]): void;
}

export const enum ConfigurationScope {
	APPLICATION = 1,
	WINDOW,
	RESOURCE,
}

export interface IConfigurationPropertySchema extends IJSONSchema {
	overridable?: boolean;
	scope?: ConfigurationScope;
	included?: boolean;
	tags?: string[];
}

export interface IConfigurationNode {
	id?: string;
	order?: number;
	type?: string | string[];
	title?: string;
	description?: string;
	properties?: { [path: string]: IConfigurationPropertySchema; };
	allOf?: IConfigurationNode[];
	overridable?: boolean;
	scope?: ConfigurationScope;
	contributedByExtension?: boolean;
}

export interface IDefaultConfigurationExtension {
	id: string;
	name: string;
	defaults: { [key: string]: {} };
}

export const allSettings: { properties: {}, patternProperties: {} } = { properties: {}, patternProperties: {} };
export const applicationSettings: { properties: {}, patternProperties: {} } = { properties: {}, patternProperties: {} };
export const windowSettings: { properties: {}, patternProperties: {} } = { properties: {}, patternProperties: {} };
export const resourceSettings: { properties: {}, patternProperties: {} } = { properties: {}, patternProperties: {} };

export const editorConfigurationSchemaId = 'vscode://schemas/settings/editor';
const contributionRegistry = Registry.as<IJSONContributionRegistry>(JSONExtensions.JSONContribution);

class ConfigurationRegistry implements IConfigurationRegistry {

	private configurationContributors: IConfigurationNode[];
	private configurationProperties: { [qualifiedKey: string]: IJSONSchema };
	private excludedConfigurationProperties: { [qualifiedKey: string]: IJSONSchema };
	private editorConfigurationSchema: IJSONSchema;
	private overrideIdentifiers: string[] = [];
	private overridePropertyPattern: string;

	private readonly _onDidSchemaChange: Emitter<void> = new Emitter<void>();
	readonly onDidSchemaChange: Event<void> = this._onDidSchemaChange.event;

	private readonly _onDidRegisterConfiguration: Emitter<string[]> = new Emitter<string[]>();
	readonly onDidRegisterConfiguration: Event<string[]> = this._onDidRegisterConfiguration.event;

	constructor() {
		this.configurationContributors = [];
		this.editorConfigurationSchema = { properties: {}, patternProperties: {}, additionalProperties: false, errorMessage: 'Unknown editor configuration setting' };
		this.configurationProperties = {};
		this.excludedConfigurationProperties = {};
		this.computeOverridePropertyPattern();

		contributionRegistry.registerSchema(editorConfigurationSchemaId, this.editorConfigurationSchema);
	}

	public registerConfiguration(configuration: IConfigurationNode, validate: boolean = true): void {
		this.registerConfigurations([configuration], [], validate);
	}

	public registerConfigurations(configurations: IConfigurationNode[], defaultConfigurations: IDefaultConfigurationExtension[], validate: boolean = true): void {
		const configurationNode = this.toConfiguration(defaultConfigurations);
		if (configurationNode) {
			configurations.push(configurationNode);
		}

		const properties: string[] = [];
		configurations.forEach(configuration => {
			properties.push(...this.validateAndRegisterProperties(configuration, validate)); // fills in defaults
			this.configurationContributors.push(configuration);
			this.registerJSONConfiguration(configuration);
			this.updateSchemaForOverrideSettingsConfiguration(configuration);
		});

		this._onDidRegisterConfiguration.fire(properties);
	}

	public notifyConfigurationSchemaUpdated(configuration: IConfigurationNode) {
		contributionRegistry.notifySchemaChanged(editorConfigurationSchemaId);
	}

	public registerOverrideIdentifiers(overrideIdentifiers: string[]): void {
		this.overrideIdentifiers.push(...overrideIdentifiers);
		this.updateOverridePropertyPatternKey();
	}

	private toConfiguration(defaultConfigurations: IDefaultConfigurationExtension[]): IConfigurationNode | null {
		const configurationNode: IConfigurationNode = {
			id: 'defaultOverrides',
			title: nls.localize('defaultConfigurations.title', "Default Configuration Overrides"),
			properties: {}
		};
		for (const defaultConfiguration of defaultConfigurations) {
			for (const key in defaultConfiguration.defaults) {
				const defaultValue = defaultConfiguration.defaults[key];
				if (OVERRIDE_PROPERTY_PATTERN.test(key) && typeof defaultValue === 'object') {
					configurationNode.properties![key] = {
						type: 'object',
						default: defaultValue,
						description: nls.localize('overrideSettings.description', "Configure editor settings to be overridden for {0} language.", key),
						$ref: editorConfigurationSchemaId
					};
				}
			}
		}
		return Object.keys(configurationNode.properties!).length ? configurationNode : null;
	}

	private validateAndRegisterProperties(configuration: IConfigurationNode, validate: boolean = true, scope: ConfigurationScope = ConfigurationScope.WINDOW, overridable: boolean = false): string[] {
		scope = types.isUndefinedOrNull(configuration.scope) ? scope : configuration.scope;
		overridable = configuration.overridable || overridable;
		let propertyKeys: string[] = [];
		let properties = configuration.properties;
		if (properties) {
			for (let key in properties) {
				let message;
				if (validate && (message = validateProperty(key))) {
					console.warn(message);
					delete properties[key];
					continue;
				}
				// fill in default values
				let property = properties[key];
				let defaultValue = property.default;
				if (types.isUndefined(defaultValue)) {
					property.default = getDefaultValue(property.type);
				}
				// Inherit overridable property from parent
				if (overridable) {
					property.overridable = true;
				}

				if (OVERRIDE_PROPERTY_PATTERN.test(key)) {
					property.scope = void 0; // No scope for overridable properties `[${identifier}]`
				} else {
					property.scope = types.isUndefinedOrNull(property.scope) ? scope : property.scope;
				}

				// Add to properties maps
				// Property is included by default if 'included' is unspecified
				if (properties[key].hasOwnProperty('included') && !properties[key].included) {
					this.excludedConfigurationProperties[key] = properties[key];
					delete properties[key];
					continue;
				} else {
					this.configurationProperties[key] = properties[key];
				}

				propertyKeys.push(key);
			}
		}
		let subNodes = configuration.allOf;
		if (subNodes) {
			for (let node of subNodes) {
				propertyKeys.push(...this.validateAndRegisterProperties(node, validate, scope, overridable));
			}
		}
		return propertyKeys;
	}

	getConfigurations(): IConfigurationNode[] {
		return this.configurationContributors;
	}

	getConfigurationProperties(): { [qualifiedKey: string]: IConfigurationPropertySchema } {
		return this.configurationProperties;
	}

	getExcludedConfigurationProperties(): { [qualifiedKey: string]: IConfigurationPropertySchema } {
		return this.excludedConfigurationProperties;
	}

	private registerJSONConfiguration(configuration: IConfigurationNode) {
		function register(configuration: IConfigurationNode) {
			let properties = configuration.properties;
			if (properties) {
				for (const key in properties) {
					allSettings.properties[key] = properties[key];
					switch (properties[key].scope) {
						case ConfigurationScope.APPLICATION:
							applicationSettings.properties[key] = properties[key];
							break;
						case ConfigurationScope.WINDOW:
							windowSettings.properties[key] = properties[key];
							break;
						case ConfigurationScope.RESOURCE:
							resourceSettings.properties[key] = properties[key];
							break;
					}
				}
			}
			let subNodes = configuration.allOf;
			if (subNodes) {
				subNodes.forEach(register);
			}
		}
		register(configuration);
		this._onDidSchemaChange.fire();
	}

	private updateSchemaForOverrideSettingsConfiguration(configuration: IConfigurationNode): void {
		if (configuration.id !== SETTINGS_OVERRRIDE_NODE_ID) {
			this.update(configuration);
			contributionRegistry.registerSchema(editorConfigurationSchemaId, this.editorConfigurationSchema);
		}
	}

	private updateOverridePropertyPatternKey(): void {
		let patternProperties: IJSONSchema = allSettings.patternProperties[this.overridePropertyPattern];
		if (!patternProperties) {
			patternProperties = {
				type: 'object',
				description: nls.localize('overrideSettings.defaultDescription', "Configure editor settings to be overridden for a language."),
				errorMessage: 'Unknown Identifier. Use language identifiers',
				$ref: editorConfigurationSchemaId
			};
		}

		delete allSettings.patternProperties[this.overridePropertyPattern];
		delete applicationSettings.patternProperties[this.overridePropertyPattern];
		delete windowSettings.patternProperties[this.overridePropertyPattern];
		delete resourceSettings.patternProperties[this.overridePropertyPattern];

		this.computeOverridePropertyPattern();

		allSettings.patternProperties[this.overridePropertyPattern] = patternProperties;
		applicationSettings.patternProperties[this.overridePropertyPattern] = patternProperties;
		windowSettings.patternProperties[this.overridePropertyPattern] = patternProperties;
		resourceSettings.patternProperties[this.overridePropertyPattern] = patternProperties;

		this._onDidSchemaChange.fire();
	}

	private update(configuration: IConfigurationNode): void {
		let properties = configuration.properties;
		if (properties) {
			for (let key in properties) {
				if (properties[key].overridable) {
					this.editorConfigurationSchema.properties![key] = this.getConfigurationProperties()[key];
				}
			}
		}
		let subNodes = configuration.allOf;
		if (subNodes) {
			subNodes.forEach(subNode => this.update(subNode));
		}
	}

	private computeOverridePropertyPattern(): void {
		this.overridePropertyPattern = this.overrideIdentifiers.length ? OVERRIDE_PATTERN_WITH_SUBSTITUTION.replace('${0}', this.overrideIdentifiers.map(identifier => strings.createRegExp(identifier, false).source).join('|')) : OVERRIDE_PROPERTY;
	}
}

const SETTINGS_OVERRRIDE_NODE_ID = 'override';
const OVERRIDE_PROPERTY = '\\[.*\\]$';
const OVERRIDE_PATTERN_WITH_SUBSTITUTION = '\\[(${0})\\]$';
export const OVERRIDE_PROPERTY_PATTERN = new RegExp(OVERRIDE_PROPERTY);

function getDefaultValue(type: string | string[] | undefined): any {
	const t = Array.isArray(type) ? (<string[]>type)[0] : <string>type;
	switch (t) {
		case 'boolean':
			return false;
		case 'integer':
		case 'number':
			return 0;
		case 'string':
			return '';
		case 'array':
			return [];
		case 'object':
			return {};
		default:
			return null;
	}
}


const configurationRegistry = new ConfigurationRegistry();
Registry.add(Extensions.Configuration, configurationRegistry);

export function validateProperty(property: string): string | null {
	if (OVERRIDE_PROPERTY_PATTERN.test(property)) {
		return nls.localize('config.property.languageDefault', "Cannot register '{0}'. This matches property pattern '\\\\[.*\\\\]$' for describing language specific editor settings. Use 'configurationDefaults' contribution.", property);
	}
	if (configurationRegistry.getConfigurationProperties()[property] !== void 0) {
		return nls.localize('config.property.duplicate', "Cannot register '{0}'. This property is already registered.", property);
	}
	return null;
}

export function getScopes(): { [key: string]: ConfigurationScope } {
	const scopes = {};
	const configurationProperties = configurationRegistry.getConfigurationProperties();
	for (const key of Object.keys(configurationProperties)) {
		scopes[key] = configurationProperties[key].scope;
	}
	scopes['launch'] = ConfigurationScope.RESOURCE;
	scopes['task'] = ConfigurationScope.RESOURCE;
	return scopes;
}
