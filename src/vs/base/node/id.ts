/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as errors from 'vs/base/common/errors';
import * as uuid from 'vs/base/common/uuid';
import { networkInterfaces } from 'os';
import { TernarySearchTree } from 'vs/base/common/map';

// http://www.techrepublic.com/blog/data-center/mac-address-scorecard-for-common-virtual-machine-platforms/
// VMware ESX 3, Server, Workstation, Player	00-50-56, 00-0C-29, 00-05-69
// Microsoft Hyper-V, Virtual Server, Virtual PC	00-03-FF
// Parallells Desktop, Workstation, Server, Virtuozzo	00-1C-42
// Virtual Iron 4	00-0F-4B
// Red Hat Xen	00-16-3E
// Oracle VM	00-16-3E
// XenSource	00-16-3E
// Novell Xen	00-16-3E
// Sun xVM VirtualBox	08-00-27
export const virtualMachineHint: { value(): number } = new class {

	private _virtualMachineOUIs: TernarySearchTree<boolean>;
	private _value: number;

	private _isVirtualMachineMacAdress(mac: string): boolean {
		if (!this._virtualMachineOUIs) {
			this._virtualMachineOUIs = TernarySearchTree.forStrings<boolean>();

			// dash-separated
			this._virtualMachineOUIs.set('00-50-56', true);
			this._virtualMachineOUIs.set('00-0C-29', true);
			this._virtualMachineOUIs.set('00-05-69', true);
			this._virtualMachineOUIs.set('00-03-FF', true);
			this._virtualMachineOUIs.set('00-1C-42', true);
			this._virtualMachineOUIs.set('00-16-3E', true);
			this._virtualMachineOUIs.set('08-00-27', true);

			// colon-separated
			this._virtualMachineOUIs.set('00:50:56', true);
			this._virtualMachineOUIs.set('00:0C:29', true);
			this._virtualMachineOUIs.set('00:05:69', true);
			this._virtualMachineOUIs.set('00:03:FF', true);
			this._virtualMachineOUIs.set('00:1C:42', true);
			this._virtualMachineOUIs.set('00:16:3E', true);
			this._virtualMachineOUIs.set('08:00:27', true);
		}
		return !!this._virtualMachineOUIs.findSubstr(mac);
	}

	value(): number {
		if (this._value === undefined) {
			let vmOui = 0;
			let interfaceCount = 0;

			const interfaces = networkInterfaces();
			for (let name in interfaces) {
				if (Object.prototype.hasOwnProperty.call(interfaces, name)) {
					for (const { mac, internal } of interfaces[name]) {
						if (!internal) {
							interfaceCount += 1;
							if (this._isVirtualMachineMacAdress(mac.toUpperCase())) {
								vmOui += 1;
							}
						}
					}
				}
			}
			this._value = interfaceCount > 0
				? vmOui / interfaceCount
				: 0;
		}

		return this._value;
	}
};

let machineId: Promise<string>;
export function getMachineId(): Promise<string> {
	return machineId || (machineId = getMacMachineId()
		.then(id => id || uuid.generateUuid())); // fallback, generate a UUID
}

function getMacMachineId(): Promise<string> {
	return new Promise<string>(resolve => {
		Promise.all([import('crypto'), import('getmac')]).then(([crypto, getmac]) => {
			try {
				getmac.getMac((error, macAddress) => {
					if (!error) {
						resolve(crypto.createHash('sha256').update(macAddress, 'utf8').digest('hex'));
					} else {
						resolve(undefined);
					}
				});
			} catch (err) {
				errors.onUnexpectedError(err);
				resolve(undefined);
			}
		}, err => {
			errors.onUnexpectedError(err);
			resolve(undefined);
		});
	});
}
