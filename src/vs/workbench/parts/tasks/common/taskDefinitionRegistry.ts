/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as nls from 'vs/nls';
import { IJSONSchema, IJSONSchemaMap } from 'vs/base/common/jsonSchema';
import { IStringDictionary } from 'vs/base/common/collections';
import * as Types from 'vs/base/common/types';
import * as Objects from 'vs/base/common/objects';

import { ExtensionsRegistry, ExtensionMessageCollector } from 'vs/workbench/services/extensions/common/extensionsRegistry';

import * as Tasks from 'vs/workbench/parts/tasks/common/tasks';


const taskDefinitionSchema: IJSONSchema = {
	type: 'object',
	additionalProperties: false,
	properties: {
		type: {
			type: 'string',
			description: nls.localize('TaskDefinition.description', 'The actual task type. Please note that types starting with a \'$\' are reserved for internal usage.')
		},
		required: {
			type: 'array',
			items: {
				type: 'string'
			}
		},
		properties: {
			type: 'object',
			description: nls.localize('TaskDefinition.properties', 'Additional properties of the task type'),
			additionalProperties: {
				$ref: 'http://json-schema.org/draft-04/schema#'
			}
		}
	}
};

namespace Configuration {
	export interface TaskDefinition {
		type?: string;
		required?: string[];
		properties?: IJSONSchemaMap;
	}

	export function from(value: TaskDefinition, extensionId: string, messageCollector: ExtensionMessageCollector): Tasks.TaskDefinition | undefined {
		if (!value) {
			return undefined;
		}
		let taskType = Types.isString(value.type) ? value.type : undefined;
		if (!taskType || taskType.length === 0) {
			messageCollector.error(nls.localize('TaskTypeConfiguration.noType', 'The task type configuration is missing the required \'taskType\' property'));
			return undefined;
		}
		let required: string[] = [];
		if (Array.isArray(value.required)) {
			for (let element of value.required) {
				if (Types.isString(element)) {
					required.push(element);
				}
			}
		}
		return { extensionId, taskType, required: required, properties: value.properties ? Objects.deepClone(value.properties) : {} };
	}
}


const taskDefinitionsExtPoint = ExtensionsRegistry.registerExtensionPoint<Configuration.TaskDefinition[]>('taskDefinitions', [], {
	description: nls.localize('TaskDefinitionExtPoint', 'Contributes task kinds'),
	type: 'array',
	items: taskDefinitionSchema
});

export interface ITaskDefinitionRegistry {
	onReady(): Promise<void>;

	get(key: string): Tasks.TaskDefinition;
	all(): Tasks.TaskDefinition[];
	getJsonSchema(): IJSONSchema;
}

class TaskDefinitionRegistryImpl implements ITaskDefinitionRegistry {

	private taskTypes: IStringDictionary<Tasks.TaskDefinition>;
	private readyPromise: Promise<void>;
	private _schema: IJSONSchema;

	constructor() {
		this.taskTypes = Object.create(null);
		this.readyPromise = new Promise<void>((resolve, reject) => {
			taskDefinitionsExtPoint.setHandler((extensions) => {
				try {
					for (let extension of extensions) {
						let taskTypes = extension.value;
						for (let taskType of taskTypes) {
							let type = Configuration.from(taskType, extension.description.id, extension.collector);
							if (type) {
								this.taskTypes[type.taskType] = type;
							}
						}
					}
				} catch (error) {
				}
				resolve(undefined);
			});
		});
	}

	public onReady(): Promise<void> {
		return this.readyPromise;
	}

	public get(key: string): Tasks.TaskDefinition {
		return this.taskTypes[key];
	}

	public all(): Tasks.TaskDefinition[] {
		return Object.keys(this.taskTypes).map(key => this.taskTypes[key]);
	}

	public getJsonSchema(): IJSONSchema {
		if (this._schema === void 0) {
			let schemas: IJSONSchema[] = [];
			for (let definition of this.all()) {
				let schema: IJSONSchema = {
					type: 'object',
					additionalProperties: false
				};
				if (definition.required.length > 0) {
					schema.required = definition.required.slice(0);
				}
				if (definition.properties !== void 0) {
					schema.properties = Objects.deepClone(definition.properties);
				} else {
					schema.properties = Object.create(null);
				}
				schema.properties!.type = {
					type: 'string',
					enum: [definition.taskType]
				};
				schemas.push(schema);
			}
			this._schema = { oneOf: schemas };
		}
		return this._schema;
	}
}

export const TaskDefinitionRegistry: ITaskDefinitionRegistry = new TaskDefinitionRegistryImpl();
