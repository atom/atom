/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import { Emitter, Event } from 'vs/base/common/event';
import { TPromise } from 'vs/base/common/winjs.base';
import { ICodeEditor } from 'vs/editor/browser/editorBrowser';
import { AbstractCodeEditorService } from 'vs/editor/browser/services/abstractCodeEditorService';
import { IDecorationRenderOptions } from 'vs/editor/common/editorCommon';
import { IModelDecorationOptions } from 'vs/editor/common/model';
import { CommandsRegistry, ICommandEvent, ICommandService } from 'vs/platform/commands/common/commands';
import { IResourceInput } from 'vs/platform/editor/common/editor';
import { IInstantiationService } from 'vs/platform/instantiation/common/instantiation';

export class TestCodeEditorService extends AbstractCodeEditorService {
	public lastInput: IResourceInput;
	public getActiveCodeEditor(): ICodeEditor | null { return null; }
	public openCodeEditor(input: IResourceInput, source: ICodeEditor | null, sideBySide?: boolean): TPromise<ICodeEditor | null> {
		this.lastInput = input;
		return TPromise.as(null);
	}
	public registerDecorationType(key: string, options: IDecorationRenderOptions, parentTypeKey?: string): void { }
	public removeDecorationType(key: string): void { }
	public resolveDecorationOptions(decorationTypeKey: string, writable: boolean): IModelDecorationOptions { return {}; }
}

export class TestCommandService implements ICommandService {
	_serviceBrand: any;

	private readonly _instantiationService: IInstantiationService;

	private readonly _onWillExecuteCommand: Emitter<ICommandEvent> = new Emitter<ICommandEvent>();
	public readonly onWillExecuteCommand: Event<ICommandEvent> = this._onWillExecuteCommand.event;

	constructor(instantiationService: IInstantiationService) {
		this._instantiationService = instantiationService;
	}

	public executeCommand<T>(id: string, ...args: any[]): Promise<T> {
		const command = CommandsRegistry.getCommand(id);
		if (!command) {
			return Promise.reject(new Error(`command '${id}' not found`));
		}

		try {
			this._onWillExecuteCommand.fire({ commandId: id });
			const result = this._instantiationService.invokeFunction.apply(this._instantiationService, [command.handler].concat(args));
			return Promise.resolve(result);
		} catch (err) {
			return Promise.reject(err);
		}
	}
}
