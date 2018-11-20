/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as nls from 'vs/nls';
import * as aria from 'vs/base/browser/ui/aria/aria';
import { IAction, Action } from 'vs/base/common/actions';
import { IOutputService, OUTPUT_PANEL_ID, IOutputChannelRegistry, Extensions as OutputExt, IOutputChannelDescriptor } from 'vs/workbench/parts/output/common/output';
import { SelectActionItem } from 'vs/base/browser/ui/actionbar/actionbar';
import { IPartService } from 'vs/workbench/services/part/common/partService';
import { IPanelService } from 'vs/workbench/services/panel/common/panelService';
import { TogglePanelAction } from 'vs/workbench/browser/panel';
import { IDisposable, dispose } from 'vs/base/common/lifecycle';
import { attachSelectBoxStyler } from 'vs/platform/theme/common/styler';
import { IThemeService } from 'vs/platform/theme/common/themeService';
import { IContextViewService } from 'vs/platform/contextview/browser/contextView';
import { Registry } from 'vs/platform/registry/common/platform';
import { groupBy } from 'vs/base/common/arrays';
import { IQuickInputService, IQuickPickItem } from 'vs/platform/quickinput/common/quickInput';
import { IEditorService } from 'vs/workbench/services/editor/common/editorService';
import { IInstantiationService } from 'vs/platform/instantiation/common/instantiation';
import { LogViewerInput } from 'vs/workbench/parts/output/browser/logViewer';

export class ToggleOutputAction extends TogglePanelAction {

	public static readonly ID = 'workbench.action.output.toggleOutput';
	public static readonly LABEL = nls.localize('toggleOutput', "Toggle Output");

	constructor(
		id: string, label: string,
		@IPartService partService: IPartService,
		@IPanelService panelService: IPanelService,
	) {
		super(id, label, OUTPUT_PANEL_ID, panelService, partService);
	}
}

export class ClearOutputAction extends Action {

	public static readonly ID = 'workbench.output.action.clearOutput';
	public static readonly LABEL = nls.localize('clearOutput', "Clear Output");

	constructor(
		id: string, label: string,
		@IOutputService private outputService: IOutputService
	) {
		super(id, label, 'output-action clear-output');
	}

	public run(): Promise<boolean> {
		this.outputService.getActiveChannel().clear();
		aria.status(nls.localize('outputCleared', "Output was cleared"));

		return Promise.resolve(true);
	}
}

export class ToggleOutputScrollLockAction extends Action {

	public static readonly ID = 'workbench.output.action.toggleOutputScrollLock';
	public static readonly LABEL = nls.localize({ key: 'toggleOutputScrollLock', comment: ['Turn on / off automatic output scrolling'] }, "Toggle Output Scroll Lock");

	private toDispose: IDisposable[] = [];

	constructor(id: string, label: string,
		@IOutputService private outputService: IOutputService) {
		super(id, label, 'output-action output-scroll-unlock');
		this.toDispose.push(this.outputService.onActiveOutputChannel(channel => this.setClass(this.outputService.getActiveChannel().scrollLock)));
	}

	public run(): Promise<boolean> {
		const activeChannel = this.outputService.getActiveChannel();
		if (activeChannel) {
			activeChannel.scrollLock = !activeChannel.scrollLock;
			this.setClass(activeChannel.scrollLock);
		}

		return Promise.resolve(true);
	}

	private setClass(locked: boolean) {
		if (locked) {
			this.class = 'output-action output-scroll-lock';
		} else {
			this.class = 'output-action output-scroll-unlock';
		}
	}

	public dispose() {
		super.dispose();
		this.toDispose = dispose(this.toDispose);
	}
}

export class SwitchOutputAction extends Action {

	public static readonly ID = 'workbench.output.action.switchBetweenOutputs';

	constructor(@IOutputService private outputService: IOutputService) {
		super(SwitchOutputAction.ID, nls.localize('switchToOutput.label', "Switch to Output"));

		this.class = 'output-action switch-to-output';
	}

	public run(channelId?: string): Thenable<any> {
		return this.outputService.showChannel(channelId);
	}
}

export class SwitchOutputActionItem extends SelectActionItem {

	private static readonly SEPARATOR = '─────────';

	private outputChannels: IOutputChannelDescriptor[];
	private logChannels: IOutputChannelDescriptor[];

	constructor(
		action: IAction,
		@IOutputService private outputService: IOutputService,
		@IThemeService themeService: IThemeService,
		@IContextViewService contextViewService: IContextViewService
	) {
		super(null, action, [], 0, contextViewService, { ariaLabel: nls.localize('outputChannels', 'Output Channels.') });

		let outputChannelRegistry = Registry.as<IOutputChannelRegistry>(OutputExt.OutputChannels);
		this.toDispose.push(outputChannelRegistry.onDidRegisterChannel(() => this.updateOtions(this.outputService.getActiveChannel().id)));
		this.toDispose.push(outputChannelRegistry.onDidRemoveChannel(() => this.updateOtions(this.outputService.getActiveChannel().id)));
		this.toDispose.push(this.outputService.onActiveOutputChannel(activeChannelId => this.updateOtions(activeChannelId)));
		this.toDispose.push(attachSelectBoxStyler(this.selectBox, themeService));

		this.updateOtions(this.outputService.getActiveChannel().id);
	}

	protected getActionContext(option: string, index: number): string {
		const channel = index < this.outputChannels.length ? this.outputChannels[index] : this.logChannels[index - this.outputChannels.length - 1];
		return channel ? channel.id : option;
	}

	private updateOtions(selectedChannel: string): void {
		const groups = groupBy(this.outputService.getChannelDescriptors(), (c1: IOutputChannelDescriptor, c2: IOutputChannelDescriptor) => {
			if (!c1.log && c2.log) {
				return -1;
			}
			if (c1.log && !c2.log) {
				return 1;
			}
			return 0;
		});
		this.outputChannels = groups[0] || [];
		this.logChannels = groups[1] || [];
		const showSeparator = this.outputChannels.length && this.logChannels.length;
		const separatorIndex = showSeparator ? this.outputChannels.length : -1;
		const options: string[] = [...this.outputChannels.map(c => c.label), ...(showSeparator ? [SwitchOutputActionItem.SEPARATOR] : []), ...this.logChannels.map(c => nls.localize('logChannel', "Log ({0})", c.label))];
		let selected = 0;
		if (selectedChannel) {
			selected = this.outputChannels.map(c => c.id).indexOf(selectedChannel);
			if (selected === -1) {
				const logChannelIndex = this.logChannels.map(c => c.id).indexOf(selectedChannel);
				selected = logChannelIndex !== -1 ? separatorIndex + 1 + logChannelIndex : 0;
			}
		}
		this.setOptions(options, Math.max(0, selected), separatorIndex !== -1 ? separatorIndex : void 0);
	}
}

export class OpenLogOutputFile extends Action {

	public static readonly ID = 'workbench.output.action.openLogOutputFile';
	public static readonly LABEL = nls.localize('openInLogViewer', "Open Log File");

	private disposables: IDisposable[] = [];

	constructor(
		@IOutputService private outputService: IOutputService,
		@IEditorService private editorService: IEditorService,
		@IInstantiationService private instantiationService: IInstantiationService
	) {
		super(OpenLogOutputFile.ID, OpenLogOutputFile.LABEL, 'output-action open-log-file');
		this.outputService.onActiveOutputChannel(this.update, this, this.disposables);
		this.update();
	}

	private update(): void {
		const outputChannelDescriptor = this.getOutputChannelDescriptor();
		this.enabled = outputChannelDescriptor && outputChannelDescriptor.file && outputChannelDescriptor.log;
	}

	public run(): Thenable<any> {
		return this.enabled ? this.editorService.openEditor(this.instantiationService.createInstance(LogViewerInput, this.getOutputChannelDescriptor())).then(() => null) : Promise.resolve(null);
	}

	private getOutputChannelDescriptor(): IOutputChannelDescriptor {
		const channel = this.outputService.getActiveChannel();
		return channel ? this.outputService.getChannelDescriptors().filter(c => c.id === channel.id)[0] : null;
	}
}

export class ShowLogsOutputChannelAction extends Action {

	static ID = 'workbench.action.showLogs';
	static LABEL = nls.localize('showLogs', "Show Logs...");

	constructor(id: string, label: string,
		@IQuickInputService private quickInputService: IQuickInputService,
		@IOutputService private outputService: IOutputService
	) {
		super(id, label);
	}

	run(): Thenable<void> {
		const entries: IQuickPickItem[] = this.outputService.getChannelDescriptors().filter(c => c.file && c.log)
			.map(({ id, label }) => (<IQuickPickItem>{ id, label }));

		return this.quickInputService.pick(entries, { placeHolder: nls.localize('selectlog', "Select Log") })
			.then(entry => {
				if (entry) {
					return this.outputService.showChannel(entry.id);
				}
				return null;
			});
	}
}

interface IOutputChannelQuickPickItem extends IQuickPickItem {
	channel: IOutputChannelDescriptor;
}

export class OpenOutputLogFileAction extends Action {

	static ID = 'workbench.action.openLogFile';
	static LABEL = nls.localize('openLogFile', "Open Log File...");

	constructor(id: string, label: string,
		@IQuickInputService private quickInputService: IQuickInputService,
		@IOutputService private outputService: IOutputService,
		@IEditorService private editorService: IEditorService,
		@IInstantiationService private instantiationService: IInstantiationService
	) {
		super(id, label);
	}

	run(): Thenable<void> {
		const entries: IOutputChannelQuickPickItem[] = this.outputService.getChannelDescriptors().filter(c => c.file && c.log)
			.map(channel => (<IOutputChannelQuickPickItem>{ id: channel.id, label: channel.label, channel }));

		return this.quickInputService.pick(entries, { placeHolder: nls.localize('selectlogFile', "Select Log file") })
			.then(entry => {
				if (entry) {
					return this.editorService.openEditor(this.instantiationService.createInstance(LogViewerInput, entry.channel)).then(() => null);
				}
				return null;
			});
	}
}