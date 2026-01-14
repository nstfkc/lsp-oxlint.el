# lsp-oxlint

An Emacs package providing LSP integration for [Oxlint](https://oxc.rs/docs/guide/usage/linter), a fast JavaScript/TypeScript linter written in Rust.

## Features

- Real-time linting diagnostics via LSP
- Code actions for automatic fixes
- Auto-fix on save support
- Monorepo support (searches upward for config and binary)
- Runs as an add-on alongside other LSP servers (e.g., typescript-language-server)
- No external Emacs package dependencies beyond lsp-mode

## Requirements

- Emacs 27.1+
- [lsp-mode](https://github.com/emacs-lsp/lsp-mode) 8.0.0+
- oxlint installed in your project (`npm install -D oxlint`)
- `.oxlintrc.json` configuration file in your project

## Installation

### Doom Emacs

1. Add to `~/.doom.d/packages.el`:
   ```elisp
   (package! lsp-oxlint
     :recipe (:host github :repo "nstfkc/lsp-oxlint.el"))
   ```

2. Run `doom sync` and restart Emacs

The package auto-enables when lsp-mode loads. To configure, add to `~/.doom.d/config.el`:
```elisp
(setq lsp-oxlint-autofix-on-save t)  ; optional
```

### straight.el + use-package

```elisp
(use-package lsp-oxlint
  :straight (lsp-oxlint :type git
                        :host github
                        :repo "nstfkc/lsp-oxlint.el")
  :after lsp-mode)
```

## Project Setup

1. Install oxlint in your project:
   ```bash
   npm install -D oxlint
   ```

2. Create `.oxlintrc.json` in your project root:
   ```json
   {
     "$schema": "./node_modules/oxlint/configuration_schema.json",
     "rules": {}
   }
   ```

3. Open a supported file and run `M-x lsp`

## Configuration

### Auto-fix on save

```elisp
(setq lsp-oxlint-autofix-on-save t)
```

### Custom config file name

```elisp
(setq lsp-oxlint-config-file "oxlint.json")
```

### Supported file types

By default, lsp-oxlint activates for: `.js`, `.jsx`, `.ts`, `.tsx`, `.mjs`, `.cjs`, `.mts`, `.cts`, `.md`, `.mdx`

To customize:
```elisp
(setq lsp-oxlint-active-file-types '("\\.js\\'" "\\.ts\\'"))
```

## Commands

| Command                       | Description                              |
|-------------------------------|------------------------------------------|
| `M-x lsp-oxlint-fix`  | Apply fixable issues in current buffer   |
| `M-x lsp-oxlint-verify-setup` | Debug activation issues                  |

## Troubleshooting

Run `M-x lsp-oxlint-verify-setup` to diagnose issues. Common problems:

- **oxlint not found**: Run `npm install -D oxlint` in your project
- **Config not found**: Create `.oxlintrc.json` in your project root
- **Wrong file type**: Ensure you're in a supported file (JS/TS/MD/MDX)

## License

MIT
