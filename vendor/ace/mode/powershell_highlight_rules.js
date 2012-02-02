define(function(require, exports, module) {
"use strict";

var oop = require("../lib/oop");
var lang = require("../lib/lang");
var TextHighlightRules = require("./text_highlight_rules").TextHighlightRules;

var PowershellHighlightRules = function() {
    
    var keywords = lang.arrayToMap(
      ("function|if|else|elseif|switch|while|default|for|do|until|break|continue|" + 
       "foreach|return|filter|in|trap|throw|param|begin|process|end").split("|")
    );

    var builtinFunctions = lang.arrayToMap(
      ("Get-Alias|Import-Alias|New-Alias|Set-Alias|Get-AuthenticodeSignature|Set-AuthenticodeSignature|" +
       "Set-Location|Get-ChildItem|Clear-Item|Get-Command|Measure-Command|Trace-Command|" +
       "Add-Computer|Checkpoint-Computer|Remove-Computer|Restart-Computer|Restore-Computer|Stop-Computer|" +
       "Reset-ComputerMachinePassword|Test-ComputerSecureChannel|Add-Content|Get-Content|Set-Content|Clear-Content|" +
       "Get-Command|Invoke-Command|Enable-ComputerRestore|Disable-ComputerRestore|Get-ComputerRestorePoint|Test-Connection|" +
       "ConvertFrom-CSV|ConvertTo-CSV|ConvertTo-Html|ConvertTo-Xml|ConvertFrom-SecureString|ConvertTo-SecureString|" +
       "Copy-Item|Export-Counter|Get-Counter|Import-Counter|Get-Credential|Get-Culture|" +
       "Get-ChildItem|Get-Date|Set-Date|Remove-Item|Compare-Object|Get-Event|" +
       "Get-WinEvent|New-Event|Remove-Event|Unregister-Event|Wait-Event|Clear-EventLog|" +
       "Get-Eventlog|Limit-EventLog|New-Eventlog|Remove-EventLog|Show-EventLog|Write-EventLog|" +
       "Get-EventSubscriber|Register-EngineEvent|Register-ObjectEvent|Register-WmiEvent|Get-ExecutionPolicy|Set-ExecutionPolicy|" +
       "Export-Alias|Export-Clixml|Export-Console|Export-Csv|ForEach-Object|Format-Custom|" +
       "Format-List|Format-Table|Format-Wide|Export-FormatData|Get-FormatData|Get-Item|" +
       "Get-ChildItem|Get-Help|Add-History|Clear-History|Get-History|Invoke-History|" +
       "Get-Host|Read-Host|Write-Host|Get-HotFix|Import-Clixml|Import-Csv|" +
       "Invoke-Command|Invoke-Expression|Get-Item|Invoke-Item|New-Item|Remove-Item|" +
       "Set-Item|Clear-ItemProperty|Copy-ItemProperty|Get-ItemProperty|Move-ItemProperty|New-ItemProperty|" +
       "Remove-ItemProperty|Rename-ItemProperty|Set-ItemProperty|Get-Job|Receive-Job|Remove-Job|" +
       "Start-Job|Stop-Job|Wait-Job|Stop-Process|Update-List|Get-Location|" +
       "Pop-Location|Push-Location|Set-Location|Send-MailMessage|Add-Member|Get-Member|" +
       "Move-Item|Compare-Object|Group-Object|Measure-Object|New-Object|Select-Object|" +
       "Sort-Object|Where-Object|Out-Default|Out-File|Out-GridView|Out-Host|" +
       "Out-Null|Out-Printer|Out-String|Convert-Path|Join-Path|Resolve-Path|" +
       "Split-Path|Test-Path|Get-Pfxcertificate|Pop-Location|Push-Location|Get-Process|" +
       "Start-Process|Stop-Process|Wait-Process|Enable-PSBreakpoint|Disable-PSBreakpoint|Get-PSBreakpoint|" +
       "Set-PSBreakpoint|Remove-PSBreakpoint|Get-PSDrive|New-PSDrive|Remove-PSDrive|Get-PSProvider|" +
       "Set-PSdebug|Enter-PSSession|Exit-PSSession|Export-PSSession|Get-PSSession|Import-PSSession|" +
       "New-PSSession|Remove-PSSession|Disable-PSSessionConfiguration|Enable-PSSessionConfiguration|Get-PSSessionConfiguration|Register-PSSessionConfiguration|" +
       "Set-PSSessionConfiguration|Unregister-PSSessionConfiguration|New-PSSessionOption|Add-PsSnapIn|Get-PsSnapin|Remove-PSSnapin|" +
       "Get-Random|Read-Host|Remove-Item|Rename-Item|Rename-ItemProperty|Select-Object|" +
       "Select-XML|Send-MailMessage|Get-Service|New-Service|Restart-Service|Resume-Service|" +
       "Set-Service|Start-Service|Stop-Service|Suspend-Service|Sort-Object|Start-Sleep|" +
       "ConvertFrom-StringData|Select-String|Tee-Object|New-Timespan|Trace-Command|Get-Tracesource|" +
       "Set-Tracesource|Start-Transaction|Complete-Transaction|Get-Transaction|Use-Transaction|Undo-Transaction|" +
       "Start-Transcript|Stop-Transcript|Add-Type|Update-TypeData|Get-Uiculture|Get-Unique|" +
       "Update-Formatdata|Update-Typedata|Clear-Variable|Get-Variable|New-Variable|Remove-Variable|" +
       "Set-Variable|New-WebServiceProxy|Where-Object|Write-Debug|Write-Error|Write-Host|" +
       "Write-Output|Write-Progress|Write-Verbose|Write-Warning|Set-WmiInstance|Invoke-WmiMethod|" +
       "Get-WmiObject|Remove-WmiObject|Connect-WSMan|Disconnect-WSMan|Test-WSMan|Invoke-WSManAction|" +
       "Disable-WSManCredSSP|Enable-WSManCredSSP|Get-WSManCredSSP|New-WSManInstance|Get-WSManInstance|Set-WSManInstance|" +
       "Remove-WSManInstance|Set-WSManQuickConfig|New-WSManSessionOption").split("|"));

    var binaryOperatorsRe = "eq|ne|ge|gt|lt|le|like|notlike|match|notmatch|replace|contains|notcontains|" +
                            "ieq|ine|ige|igt|ile|ilt|ilike|inotlike|imatch|inotmatch|ireplace|icontains|inotcontains|" +
                            "is|isnot|as|" +
                            "and|or|band|bor|not"; 

    // regexp must not have capturing parentheses. Use (?:) instead.
    // regexps are ordered -> the first match is used

    this.$rules = {
        "start" : [
            {
                token : "comment",
                regex : "#.*$"
            }, {
                token : "string", // single line
                regex : '["](?:(?:\\\\.)|(?:[^"\\\\]))*?["]'
            }, {
                token : "string", // single line
                regex : "['](?:(?:\\\\.)|(?:[^'\\\\]))*?[']"
            }, {
                token : "constant.numeric", // hex
                regex : "0[xX][0-9a-fA-F]+\\b"
            }, {
                token : "constant.numeric", // float
                regex : "[+-]?\\d+(?:(?:\\.\\d*)?(?:[eE][+-]?\\d+)?)?\\b"
            }, {
                token : "constant.language.boolean",
                regex : "[$](?:[Tt]rue|[Ff]alse)\\b"
            }, {
                token : "constant.language",
                regex : "[$][Nn]ull\\b"
            }, {
                token : "variable.instance",
                regex : "[$][a-zA-Z][a-zA-Z0-9_]*\\b"
            }, {
                token : function(value) {
                    if (keywords.hasOwnProperty(value))
                        return "keyword";
                    else if (builtinFunctions.hasOwnProperty(value))
                        return "support.function";
                    else
                        return "identifier";
                },
                // TODO: Unicode escape sequences
                // TODO: Unicode identifiers
                regex : "[a-zA-Z_$][a-zA-Z0-9_$\\-]*\\b"
            }, {
                token : "keyword.operator",
                regex : "\\-(?:" + binaryOperatorsRe + ")"
            }, {
                token : "keyword.operator",
                regex : "&|\\*|\\+|\\-|\\=|\\+=|\\-="
            }, {
                token : "lparen",
                regex : "[[({]"
            }, {
                token : "rparen",
                regex : "[\\])}]"
            }, {
                token : "text",
                regex : "\\s+"
            }
        ],
        "comment" : [
            {
                token : "comment", // closing comment
                regex : ".*?\\*\\/",
                next : "start"
            }, {
                token : "comment", // comment spanning whole line
                merge : true,
                regex : ".+"
            }
        ]
    };
};

oop.inherits(PowershellHighlightRules, TextHighlightRules);

exports.PowershellHighlightRules = PowershellHighlightRules;
});
