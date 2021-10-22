/*eslint-env node*/
/*global global*/
// FIXME: We should check where we use this and replace it with google font icons
import '@fortawesome/fontawesome-free/css/all.css';
import './static/css/main.css';
import 'blockly';

import './grammar.ne';
import * as monaco from 'monaco-editor/esm/vs/editor/editor.api';
global.monaco = monaco;
import { EmacsExtension } from 'monaco-emacs';
global.EmacsExtension = EmacsExtension;
import { initVimMode } from 'monaco-vim';
global.initVimMode = initVimMode;

import * as bignumberDTS from '!!raw-loader!bignumber.js/bignumber.d.ts';
import * as simeonDTS from '!!raw-loader!src/Language/Javascript/SimeonJS.ts';
global.monacoExtraTypeScriptLibs = [
  [ bignumberDTS.default, 'inmemory://model/bignumber.js.d.ts'],
  [ simeonDTS.default, "inmemory://model/simeon-js.d.ts" ]
];

import { BigNumber } from 'bignumber';

import './src/Main.purs';
