/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import { IChannel, IServerChannel } from 'vs/base/parts/ipc/node/ipc';
import { LogLevel, ILogService, DelegatedLogService } from 'vs/platform/log/common/log';
import { Event, buffer } from 'vs/base/common/event';

export class LogLevelSetterChannel implements IServerChannel {

	onDidChangeLogLevel: Event<LogLevel>;

	constructor(private service: ILogService) {
		this.onDidChangeLogLevel = buffer(service.onDidChangeLogLevel, true);
	}

	listen(_, event: string): Event<any> {
		switch (event) {
			case 'onDidChangeLogLevel': return this.onDidChangeLogLevel;
		}

		throw new Error(`Event not found: ${event}`);
	}

	call(_, command: string, arg?: any): Thenable<any> {
		switch (command) {
			case 'setLevel': this.service.setLevel(arg);
		}

		throw new Error(`Call not found: ${command}`);
	}
}

export class LogLevelSetterChannelClient {

	constructor(private channel: IChannel) { }

	get onDidChangeLogLevel(): Event<LogLevel> {
		return this.channel.listen('onDidChangeLogLevel');
	}

	setLevel(level: LogLevel): void {
		this.channel.call('setLevel', level);
	}
}

export class FollowerLogService extends DelegatedLogService implements ILogService {
	_serviceBrand: any;

	constructor(private master: LogLevelSetterChannelClient, logService: ILogService) {
		super(logService);
		this._register(master.onDidChangeLogLevel(level => logService.setLevel(level)));
	}

	setLevel(level: LogLevel): void {
		this.master.setLevel(level);
	}
}