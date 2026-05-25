```bash
I am building a cross-platform dotfiles repository for Arch Linux and macOS.

Repository structure:

```txt
dotfiles/
├── bootstrap.sh
├── install/
│   ├── arch.sh
│   ├── macos.sh
│   ├── common.sh
│   └── packages/
│       ├── arch.txt
│       └── brew.txt
│
├── scripts/
│   ├── detect-os.sh
│   ├── setup-nvim.sh
│   ├── setup-tmux.sh
│   ├── setup-ghostty.sh
│   ├── setup-symlinks.sh
│   ├── backup.sh
│   └── utils.sh
│
├── configs/
│   ├── nvim/
│   ├── tmux/
│   ├── ghostty/
│   ├── zsh/
│   └── git/
│
├── bin/
│   └── myScripts/
│
├── backups/
│
├── logs/
│
└── README.md
```

Workflow requirements:

1. `bootstrap.sh` is the main entry point.

2. `bootstrap.sh` should call `scripts/detect-os.sh`.

3. `detect-os.sh` must detect:

	* Arch Linux
	* macOS

4. Based on the detected OS:

	* run `install/arch.sh` for Arch Linux
	* run `install/macos.sh` for macOS

5. Each installer script should:

	* read package names from:

	  * `install/packages/arch.txt`
	  * `install/packages/brew.txt`
	* loop through every package
	* install packages automatically

6. Package managers:

	* Arch Linux:

	  * `pacman`
	  * optionally `paru`
	* macOS:

	  * `homebrew`

7. After package installation:

	* run setup scripts from `scripts/`
	* setup scripts should configure:

	  * Neovim
	  * tmux
	  * Ghostty
	  * zsh
	  * git

8. Configurations inside `configs/` should be symlinked into:

	* `~/.config`
	* or their proper destination paths

9. Existing configs should be backed up before symlinking.

10. Store backups inside:

```txt
backups/
```

11. Store installation logs inside:

```txt
logs/
```

12. Requirements:

* idempotent scripts
* modular structure
* reusable helper functions
* colored logging
* proper error handling
* safe re-run support

Generate:

* complete implementation
* shell scripts
* helper utilities
* symlink logic
* package installation logic
* backup system
* logging system
* recommended best practices
* comments explaining important parts
```