# Encoding Rules

This repository standardizes text files on `UTF-8`.

## Project defaults

- EditorConfig enforces `charset = utf-8`.
- VS Code uses `"files.encoding": "utf8"`.
- Git normalizes text files with `.gitattributes`.

## Windows terminal

If Arabic text looks garbled in PowerShell, the file is often still correct and only the terminal output is wrong.

Use this once per terminal session:

```powershell
chcp 65001
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
```

When reading files manually in PowerShell, prefer:

```powershell
Get-Content -Encoding UTF8 <path>
```

## Recovery note

If a file was actually saved with the wrong encoding, these settings prevent new corruption but do not automatically repair old damaged text. That file must be restored or rewritten once.
