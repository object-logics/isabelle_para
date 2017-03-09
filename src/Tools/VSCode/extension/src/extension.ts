'use strict';

import * as vscode from 'vscode';
import * as path from 'path';
import * as os from 'os';
import * as decorations from './decorations';
import { Decoration } from './decorations'
import { LanguageClient, LanguageClientOptions, SettingMonitor, ServerOptions, TransportKind, NotificationType }
  from 'vscode-languageclient';


export function activate(context: vscode.ExtensionContext)
{
  let is_windows = os.type().startsWith("Windows")

  let cygwin_root = vscode.workspace.getConfiguration("isabelle").get<string>("cygwin_root");
  let isabelle_home = vscode.workspace.getConfiguration("isabelle").get<string>("home");
  let isabelle_args = vscode.workspace.getConfiguration("isabelle").get<Array<string>>("args");

  if (is_windows && cygwin_root == "")
    vscode.window.showErrorMessage("Missing user settings: isabelle.cygwin_root")
  else if (isabelle_home == "")
    vscode.window.showErrorMessage("Missing user settings: isabelle.home")
  else {
    let isabelle_tool = isabelle_home + "/bin/isabelle"
    let standard_args = ["-o", "vscode_unicode_symbols", "-o", "vscode_pide_extensions"]

    let server_options: ServerOptions =
      is_windows ?
        { command: cygwin_root + "/bin/bash",
          args: ["-l", isabelle_tool, "vscode_server"].concat(standard_args, isabelle_args) } :
        { command: isabelle_tool,
          args: ["vscode_server"].concat(standard_args, isabelle_args) };
    let client_options: LanguageClientOptions = {
      documentSelector: ["isabelle", "isabelle-ml", "bibtex"]
    };

    let client = new LanguageClient("Isabelle", server_options, client_options, false)

    decorations.init(context)
    vscode.window.onDidChangeActiveTextEditor(decorations.update_editor)
    vscode.workspace.onDidCloseTextDocument(decorations.close_document)
    client.onReady().then(() =>
      client.onNotification(
        new NotificationType<Decoration, void>("PIDE/decoration"), decorations.apply_decoration))

    context.subscriptions.push(client.start());
  }
}

export function deactivate() { }
