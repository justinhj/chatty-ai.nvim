# chatty-ai.nvim
     _         _   _                 _ 
  __| |_  __ _| |_| |_ _  _ ___ __ _(_)
 / _| ' \/ _` |  _|  _| || |___/ _` | |
 \__|_||_\__,_|\__|\__|\_, |   \__,_|_|
                       |__/

## What?

## Why?

## How?

## Features

## Required dependencies
### Lua dependencies
- [nvim-lua/plenary.nvim](https://github.com/nvim-lua/plenary.nvim)

**NOTICE** Please check the nvim-web-devicons repo for information on breaking changes to Nerd Fonts. This dependency is used to show the icons in this plugin and requires a compatible font. Thank you to Github user @david-0609 for bringing this to my attention and updating the icons used in this application. Should you encounter missing icons please upgrade the font you are using so it is using 2.3 or 3.0.

_If you do not wish to upgrade your font you can pin to a previous version of the plugin using tag v0.8.0 instead of the main branch._

### OS dependencies

## Installation
Use your package manager to add the dependencies and the plugin. 

### [Plug](https://github.com/junegunn/vim-plug)

```
Plug 'nvim-lua/plenary.nvim'
Plug 'justinhj/chatty-ai.nvim'
```

### [Packer](https://github.com/wbthomason/packer.nvim)

```
use { 'justinhj/battery.nvim', requires = {{'nvim-tree/nvim-web-devicons'}, {'nvim-lua/plenary.nvim'}}}
```

## Configuration


## Diagnostics and debugging
If something breaks you should see a standard Vim error telling you what the problem is. There is some info logging you will find wherever your Neovim cache is `:h stdpath`.

For more than just info,warn and error logging you can enable debug logs which show a more verbose behaviour of the plugin using the following command to launch nvim.

`DEBUG_PLENARY=true nvim`

Inspired by TODO

Copyright (c) 2025 Justin Heyes-Jones
