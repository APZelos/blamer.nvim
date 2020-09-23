# blamer.nvim

A git blame plugin for (neo)vim inspired by VS Code's GitLens plugin.

![blamer gif](https://res.cloudinary.com/djg49e1u9/image/upload/c_crop,h_336/v1579092411/blamer_mkv07c.gif)

Note: For Vim, a popup feature is required.

## Installation

#### vim-plug

1. Add the following line to your `init.vim`:

```
call plug#begin('~/.local/share/nvim/plugged')
...
Plug 'APZelos/blamer.nvim'
...
call plug#end()
```

2. Run `:PlugInstall`.

## Configuration

#### Enabled

Enables blamer on (neo)vim startup.

You can toggle blamer on/off with the `:BlamerToggle` command.

If the current directory is not a git repository the blamer will be automatically disabled.

Default: `0`

```
let g:blamer_enabled = 1
```

#### Delay

The delay in milliseconds for the blame message to show. Setting this too low may cause performance issues.

Default: `1000`

```
let g:blamer_delay = 500
```

#### Show in visual modes

Enables / disables blamer in visual modes.

Default: `1`

```
let g:blamer_show_in_visual_modes = 0
```

#### Show in insert modes

Enables / disables blamer in insert modes.

Default: `1`

```
let g:blamer_show_in_insert_modes = 0
```

#### Prefix

The prefix that will be added to the template.

Default: `' '`

```
let g:blamer_prefix = ' > '
```

#### Template

The template for the blame message that will be shown.

Default: `'<committer>, <committer-time> • <summary>'`

Available options: `<author>`, `<author-mail>`, `<author-time>`, `<committer>`, `<committer-mail>`, `<committer-time>`, `<summary>`, `<commit-short>`, `<commit-long>`.

```
let g:blamer_template = '<committer> <summary>'
```

### Date format

The [format](https://devhints.io/datetime#strftime-format) of the date fields. (`<author-time>`, `<committer-time>`)

Default: `'%d/%m/%y %H:%M'`

```
let g:blamer_date_format = '%d/%m/%y'
```

### Relative time

Shows commit date in relative format

Default: `0`

```
let g:blamer_relative_time = 1
```

#### Highlight

The color of the blame message.

Default: `link Blamer Comment`

```
highlight Blamer guifg=lightgrey
```

## Author

[APZelos](https://github.com/APZelos)

## License

This software is released under the MIT License.
