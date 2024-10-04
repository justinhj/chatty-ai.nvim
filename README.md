# chatty-ai.nvim

```
  _____ _           _   _                    _ 
 /  __ \ |         | | | |                  (_)
 | /  \/ |__   __ _| |_| |_ _   _      __ _  _ 
 | |   | '_ \ / _` | __| __| | | |    / _` || |
 | \__/\ | | | (_| | |_| |_| |_| |   | (_| || |
  \____/_| |_|\__,_|\__|\__|\__, |    \__,_||_|
                             __/ |             
                            |___/              
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
-- chatty-ai.nvim
require("chatty-ai").setup({})

{ "justinhj/chatty-ai.nvim",
  dependencies = { { "nvim-lua/plenary.nvim" } },
},
```

## Configuration


## Diagnostics and debugging
If something breaks you should see a standard Vim error telling you what the problem is. There is some info logging you will find wherever your Neovim cache is `:h stdpath`.

For more than just info,warn and error logging you can enable debug logs which show a more verbose behaviour of the plugin using the following command to launch nvim.

`DEBUG_PLENARY=true nvim`

## References and inspirations

### Ollama

https://github.com/ollama/ollama/blob/main/docs/api.md
https://ollama.com/library/codellama

### Claude AI

https://docs.anthropic.com/en/api/getting-started

### Open AI completinos

https://platform.openai.com/docs/guides/text-generation

## Related plugins

https://github.com/frankroeder/parrot.nvim

https://github.com/Robitx/gp.nvim

https://github.com/melbaldove/llm.nvim

https://github.com/yacineMTB/dingllm.nvim

## License and Copyright

- Copyright (c) 2024 Justin Heyes-Jones
- See the file [LICENSE](LICENSE) for copying permission.
