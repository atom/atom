/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as readline from 'readline';
import { IDialogService, IConfirmation, IConfirmationResult } from 'vs/platform/dialogs/common/dialogs';
import Severity from 'vs/base/common/severity';
import { localize } from 'vs/nls';
import { canceled } from 'vs/base/common/errors';

export class CommandLineDialogService implements IDialogService {

	_serviceBrand: any;

	show(severity: Severity, message: string, options: string[]): Promise<number> {
		const promise = new Promise<number>((c, e) => {
			const rl = readline.createInterface({
				input: process.stdin,
				output: process.stdout,
				terminal: true
			});
			rl.prompt();
			rl.write(this.toQuestion(message, options));

			rl.prompt();

			rl.once('line', (answer) => {
				rl.close();
				c(this.toOption(answer, options));
			});
			rl.once('SIGINT', () => {
				rl.close();
				e(canceled());
			});
		});
		return promise;
	}

	private toQuestion(message: string, options: string[]): string {
		return options.reduce((previousValue: string, currentValue: string, currentIndex: number) => {
			return previousValue + currentValue + '(' + currentIndex + ')' + (currentIndex < options.length - 1 ? ' | ' : '\n');
		}, message + ' ');
	}

	private toOption(answer: string, options: string[]): number {
		const value = parseInt(answer);
		if (!isNaN(value)) {
			return value;
		}
		answer = answer.toLocaleLowerCase();
		for (let i = 0; i < options.length; i++) {
			if (options[i].toLocaleLowerCase() === answer) {
				return i;
			}
		}
		return -1;
	}

	confirm(confirmation: IConfirmation): Promise<IConfirmationResult> {
		return this.show(Severity.Info, confirmation.message, [confirmation.primaryButton || localize('ok', "Ok"), confirmation.secondaryButton || localize('cancel', "Cancel")]).then(index => {
			return {
				confirmed: index === 0
			} as IConfirmationResult;
		});
	}
}
