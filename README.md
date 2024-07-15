# chatty-ai.nvim

```
     _         _   _                 _ 
  __| |_  __ _| |_| |_ _  _     __ _(_)
 / _| ' \/ _` |  _|  _| || |   / _` | |
 \__|_||_\__,_|\__|\__|\_, |   \__,_|_|
                       |__/
```

## What?

## Why?

## How?

## Features

## Required dependencies
### Lua dependencies
- [nvim-lua/plenary.nvim](https://github.com/nvim-lua/plenary.nvim)

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
use { 'justinhj/chatty-ai.nvim', requires = {{'nvim-lua/plenary.nvim'}} }
```

### [Lazy](https://github.com/folke/lazy.nvim)

``` lua
todo
```

## Configuration


## Diagnostics and debugging
If something breaks you should see a standard Vim error telling you what the problem is. There is some info logging you will find wherever your Neovim cache is `:h stdpath`.

For more than just info,warn and error logging you can enable debug logs which show a more verbose behaviour of the plugin using the following command to launch nvim.

`DEBUG_PLENARY=true nvim`

Inspired by TODO

Copyright (c) 2025 Justin Heyes-Jones
