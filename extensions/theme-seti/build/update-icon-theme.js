/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

'use strict';

let path = require('path');
let fs = require('fs');
let https = require('https');
let url = require('url');

// list of languagesIs not shipped with VSCode. The information is used to associate an icon with a langauge association
let nonBuiltInLanguages = { // { fileNames, extensions }
	"r": { extensions: ['r', 'rhistory', 'rprofile', 'rt'] },
	"argdown": { extensions: ['ad', 'adown', 'argdown', 'argdn'] },
	"elm": { extensions: ['elm'] },
	"ocaml": { extensions: ['ml', 'mli'] },
	"nunjucks": { extensions: ['nunjucks', 'nunjs', 'nunj', 'nj', 'njk', 'tmpl', 'tpl'] },
	"mustache": { extensions: ['mustache', 'mst', 'mu', 'stache'] },
	"erb": { extensions: ['erb', 'rhtml', 'html.erb'] },
	"terraform": { extensions: ['tf', 'tfvars', 'hcl'] },
	"vue": { extensions: ['vue'] },
	"sass": { extensions: ['sass'] },
	"puppet": { extensions: ['puppet'] },
	"kotlin": { extensions: ['kt'] },
	"jinja": { extensions: ['jinja'] },
	"haxe": { extensions: ['hx'] },
	"haskell": { extensions: ['hs'] },
	"gradle": { extensions: ['gradle'] },
	"elixir": { extensions: ['ex'] },
	"haml": { extensions: ['haml'] },
	"stylus": { extensions: ['styl'] },
	"vala": { extensions: ['vala'] },
	"todo": { fileNames: ['todo'] }
};

function getCommitSha(repoId, repoPath) {
	let commitInfo = 'https://api.github.com/repos/' + repoId + '/commits?path=' + repoPath;
	return download(commitInfo).then(function (content) {
		try {
			let lastCommit = JSON.parse(content)[0];
			return Promise.resolve({
				commitSha: lastCommit.sha,
				commitDate: lastCommit.commit.author.date
			});
		} catch (e) {
			return Promise.resolve(null);
		}
	}, function () {
		console.error('Failed loading ' + commitInfo);
		return Promise.resolve(null);
	});
}

function download(source) {
	if (source.startsWith('.')) {
		return readFile(source);
	}
	return new Promise((c, e) => {
		let _url = url.parse(source);
		let options = { host: _url.host, port: _url.port, path: _url.path, headers: { 'User-Agent': 'NodeJS' } };
		let content = '';
		https.get(options, function (response) {
			response.on('data', function (data) {
				content += data.toString();
			}).on('end', function () {
				c(content);
			});
		}).on('error', function (err) {
			e(err.message);
		});
	});
}

function readFile(fileName) {
	return new Promise((c, e) => {
		fs.readFile(fileName, function (err, data) {
			if (err) {
				e(err);
			} else {
				c(data.toString());
			}
		});
	});
}

function downloadBinary(source, dest) {
	if (source.startsWith('.')) {
		return copyFile(source, dest);
	}

	return new Promise((c, e) => {
		https.get(source, function (response) {
			switch (response.statusCode) {
				case 200:
					let file = fs.createWriteStream(dest);
					response.on('data', function (chunk) {
						file.write(chunk);
					}).on('end', function () {
						file.end();
						c(null);
					}).on('error', function (err) {
						fs.unlink(dest);
						e(err.message);
					});
					break;
				case 301:
				case 302:
				case 303:
				case 307:
					console.log('redirect to ' + response.headers.location);
					downloadBinary(response.headers.location, dest).then(c, e);
					break;
				default:
					e(new Error('Server responded with status code ' + response.statusCode));
			}
		});
	});
}

function copyFile(fileName, dest) {
	return new Promise((c, e) => {
		let cbCalled = false;
		function handleError(err) {
			if (!cbCalled) {
				e(err);
				cbCalled = true;
			}
		}
		let rd = fs.createReadStream(fileName);
		rd.on("error", handleError);
		let wr = fs.createWriteStream(dest);
		wr.on("error", handleError);
		wr.on("close", function () {
			if (!cbCalled) {
				c();
				cbCalled = true;
			}
		});
		rd.pipe(wr);
	});
}

function darkenColor(color) {
	let res = '#';
	for (let i = 1; i < 7; i += 2) {
		let newVal = Math.round(parseInt('0x' + color.substr(i, 2), 16) * 0.9);
		let hex = newVal.toString(16);
		if (hex.length == 1) {
			res += '0';
		}
		res += hex;
	}
	return res;
}

function getLanguageMappings() {
	let langMappings = {};
	let allExtensions = fs.readdirSync('..');
	for (let i = 0; i < allExtensions.length; i++) {
		let dirPath = path.join('..', allExtensions[i], 'package.json');
		if (fs.existsSync(dirPath)) {
			let content = fs.readFileSync(dirPath).toString();
			let jsonContent = JSON.parse(content);
			let languages = jsonContent.contributes && jsonContent.contributes.languages;
			if (Array.isArray(languages)) {
				for (let k = 0; k < languages.length; k++) {
					let languageId = languages[k].id;
					if (languageId) {
						let extensions = languages[k].extensions;
						let mapping = {};
						if (Array.isArray(extensions)) {
							mapping.extensions = extensions.map(function (e) { return e.substr(1).toLowerCase(); });
						}
						let filenames = languages[k].filenames;
						if (Array.isArray(filenames)) {
							mapping.fileNames = filenames.map(function (f) { return f.toLowerCase(); });
						}
						langMappings[languageId] = mapping;
					}
				}
			}
		}
	}
	for (let languageId in nonBuiltInLanguages) {
		langMappings[languageId] = nonBuiltInLanguages[languageId];
	}
	return langMappings;
}

//let font = 'https://raw.githubusercontent.com/jesseweed/seti-ui/master/styles/_fonts/seti/seti.woff';
let font = '../../../seti-ui/styles/_fonts/seti/seti.woff';

exports.copyFont = function () {
	return downloadBinary(font, './icons/seti.woff');
};

//let fontMappings = 'https://raw.githubusercontent.com/jesseweed/seti-ui/master/styles/_fonts/seti.less';
//let mappings = 'https://raw.githubusercontent.com/jesseweed/seti-ui/master/styles/components/icons/mapping.less';
//let colors = 'https://raw.githubusercontent.com/jesseweed/seti-ui/master/styles/ui-variables.less';

let fontMappingsFile = '../../../seti-ui/styles/_fonts/seti.less';
let fileAssociationFile = '../../../seti-ui/styles/components/icons/mapping.less';
let colorsFile = '../../../seti-ui/styles/ui-variables.less';

exports.update = function () {

	console.log('Reading from ' + fontMappingsFile);
	let def2Content = {};
	let ext2Def = {};
	let fileName2Def = {};
	let def2ColorId = {};
	let colorId2Value = {};
	let lang2Def = {};

	function writeFileIconContent(info) {
		let iconDefinitions = {};
		let allDefs = Object.keys(def2Content).sort();

		for (let i = 0; i < allDefs.length; i++) {
			let def = allDefs[i];
			let entry = { fontCharacter: def2Content[def] };
			let colorId = def2ColorId[def];
			if (colorId) {
				let colorValue = colorId2Value[colorId];
				if (colorValue) {
					entry.fontColor = colorValue;

					let entryInverse = { fontCharacter: entry.fontCharacter, fontColor: darkenColor(colorValue) };
					iconDefinitions[def + '_light'] = entryInverse;
				}
			}
			iconDefinitions[def] = entry;
		}

		function getInvertSet(input) {
			let result = {};
			for (let assoc in input) {
				let invertDef = input[assoc] + '_light';
				if (iconDefinitions[invertDef]) {
					result[assoc] = invertDef;
				}
			}
			return result;
		}

		let res = {
			information_for_contributors: [
				'This file has been generated from data in https://github.com/jesseweed/seti-ui',
				'- icon definitions: https://github.com/jesseweed/seti-ui/blob/master/styles/_fonts/seti.less',
				'- icon colors: https://github.com/jesseweed/seti-ui/blob/master/styles/ui-variables.less',
				'- file associations: https://github.com/jesseweed/seti-ui/blob/master/styles/components/icons/mapping.less',
				'If you want to provide a fix or improvement, please create a pull request against the jesseweed/seti-ui repository.',
				'Once accepted there, we are happy to receive an update request.',
			],
			fonts: [{
				id: "seti",
				src: [{ "path": "./seti.woff", "format": "woff" }],
				weight: "normal",
				style: "normal",
				size: "150%"
			}],
			iconDefinitions: iconDefinitions,
			//	folder: "_folder",
			file: "_default",
			fileExtensions: ext2Def,
			fileNames: fileName2Def,
			languageIds: lang2Def,
			light: {
				file: "_default_light",
				fileExtensions: getInvertSet(ext2Def),
				languageIds: getInvertSet(lang2Def),
				fileNames: getInvertSet(fileName2Def)
			},
			version: 'https://github.com/jesseweed/seti-ui/commit/' + info.commitSha,
		};

		let path = './icons/vs-seti-icon-theme.json';
		fs.writeFileSync(path, JSON.stringify(res, null, '\t'));
		console.log('written ' + path);
	}


	let match;

	return download(fontMappingsFile).then(function (content) {
		let regex = /@([\w-]+):\s*'(\\E[0-9A-F]+)';/g;
		let contents = {};
		while ((match = regex.exec(content)) !== null) {
			contents[match[1]] = match[2];
		}

		return download(fileAssociationFile).then(function (content) {
			let regex2 = /\.icon-(?:set|partial)\(['"]([\w-\.]+)['"],\s*['"]([\w-]+)['"],\s*(@[\w-]+)\)/g;
			while ((match = regex2.exec(content)) !== null) {
				let pattern = match[1];
				let def = '_' + match[2];
				let colorId = match[3];
				let storedColorId = def2ColorId[def];
				let i = 1;
				while (storedColorId && colorId !== storedColorId) { // different colors for the same def?
					def = `_${match[2]}_${i}`;
					storedColorId = def2ColorId[def];
					i++;
				}
				if (!def2ColorId[def]) {
					def2ColorId[def] = colorId;
					def2Content[def] = contents[match[2]];
				}

				if (def === '_default') {
					continue; // no need to assign default color.
				}
				if (pattern[0] === '.') {
					ext2Def[pattern.substr(1).toLowerCase()] = def;
				} else {
					fileName2Def[pattern.toLowerCase()] = def;
				}
			}
			// replace extensions for languageId
			let langMappings = getLanguageMappings();
			for (let lang in langMappings) {
				let mappings = langMappings[lang];
				let exts = mappings.extensions || [];
				let fileNames = mappings.fileNames || [];
				let preferredDef = null;
				// use the first file association for the preferred definition
				for (let i1 = 0; i1 < exts.length && !preferredDef; i1++) {
					preferredDef = ext2Def[exts[i1]];
				}
				// use the first file association for the preferred definition
				for (let i1 = 0; i1 < fileNames.length && !preferredDef; i1++) {
					preferredDef = fileName2Def[fileNames[i1]];
				}
				if (preferredDef) {
					lang2Def[lang] = preferredDef;
					if (!nonBuiltInLanguages[lang]) {
						for (let i2 = 0; i2 < exts.length; i2++) {
							// remove the extension association, unless it is different from the preferred
							if (ext2Def[exts[i2]] === preferredDef) {
								delete ext2Def[exts[i2]];
							}
						}
						for (let i2 = 0; i2 < fileNames.length; i2++) {
							// remove the fileName association, unless it is different from the preferred
							if (fileName2Def[fileNames[i2]] === preferredDef) {
								delete fileName2Def[fileNames[i2]];
							}
						}
					}
				}
			}


			return download(colorsFile).then(function (content) {
				let regex3 = /(@[\w-]+):\s*(#[0-9a-z]+)/g;
				while ((match = regex3.exec(content)) !== null) {
					colorId2Value[match[1]] = match[2];
				}
				return getCommitSha('jesseweed/seti-ui', 'styles/_fonts/seti.less').then(function (info) {
					try {
						writeFileIconContent(info);
						if (info) {
							console.log('Updated to jesseweed/seti-ui@' + info.commitSha.substr(0, 7) + ' (' + info.commitDate.substr(0, 10) + ')');
						}

					} catch (e) {
						console.error(e);
					}
				});
			});
		});
	}, console.error);
};

if (path.basename(process.argv[1]) === 'update-icon-theme.js') {
	exports.copyFont().then(() => exports.update());
}



