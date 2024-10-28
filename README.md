# chatty-ai.nvim

<img src="https://github.com/user-attachments/assets/8c97b63e-36f4-48b9-8718-445e2d9e7223" alt="chattyailogo" width="66%">

## What?

Chatty-AI is a configurable, composable Neovim plugin for interacting with LLM's and writing code.

### Goals

- Nothing going in the background, a programmer driven workflow.
- Users can add their own chat services using a simple extensible architecture like that of [nvim-cmp](https://github.com/hrsh7th/nvim-cmp). 
- Build your workflow with a simple composable set of tools.

### Features

- Easy to add support new completion services.
- Compose different prompt sources into each completion and make your own.
- Full control over the prompt context and chat history.
- Toolbar information on token usage etc.

### Future features under consideration

- Lower level interface to LLMS including tokenization/detokenization.
- Embeddings. Add support for creating embeddings, vector storage and similarity search. (Maybe an external plugin).
- Support for function calling.

## Why?

Honestly I made it for mostly for fun, and to provide the exact assistant environment I wanted, but hopefully others will find it useful.

## How?

The plugin is built in lua and relies on the excellent [Plenary]() library to handle the calls to curl which power the completion services.

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

### Adding a service

TODO

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
