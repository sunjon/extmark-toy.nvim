# [WIP] extmark-toy.nvim

Extmark Toy is a plugin created to house my experimental demos and games created in Neovim.
The graphical effects are rasterized using Unicode font [Block Element](https://en.wikipedia.org/wiki/Block_elements) glyphs in combination with Neovim's extmarks.

A font that supports glyphs introduced in [Unicode version 13.0](https://unicode.org/versions/Unicode13.0.0/) is required for some effects.

At the moment there's currently a single effect included; One produced for [Thomas Vigoux](https://github.com/vigoux), as a thanks for all the work he's contributed to Neovim.

I have a variety of other nearly-complete effects that I'll introduce when they have less rough edges.

At some point I'd like to support user created effects, moving utilities used for effect creation and generic methods in current effects into API functions.

## Effects

### Vigoux Logo
<img src="https://raw.githubusercontent.com/sunjon/images/master/extmark-toy.gif" alt="screenshot" width="800"/>

Keys:
`<Left>`  rotate palette left
`<Right>` rotate palette right



### WIP

TODO: add gifs/screenshots of other WIP effects

## Installation

### [Packer](https://github.com/wbthomason/packer.nvim) 

```lua
use 'sunjon/extmark-toy.nvim'
```

### [Vim-Plug](https://github.com/junegunn/vim-plug)

```lua
Plug 'sunjon/extmark-toy.nvim'
```

## Configuration

:map <key> <cmd>lua require'extmark-toy'.start()`

## Usage

`q` to exit

## License

Copyright (c) Senghan Bright. Distributed under the MIT license
