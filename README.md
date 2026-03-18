# yazi-tmsu

A [Yazi](https://github.com/sxyazi/yazi) plugin for [TMSU](https://tmsu.org/) 
![screenshot](img/screenshot2.png)

---

## Features

* **Add tags**: Batch tag selected files.
* **Remove tags**: Quickly strip tags.
* **List tags**: View all tags from selection.
* **Common tags**: Find overlapping tags between files.
* **Live filter**: Catch files via tag through a filter.

## Installation

### Linux/MacOS

Using the [Yazi Package Manager](https://yazi-rs.github.io/docs/cli/#package-manager):

```sh
ya pkg add arbope/tmsu
```

Or manually:

```sh
git clone https://github.com/arbope/tmsu.yazi.git ~/.config/yazi/plugins/tmsu.yazi
```

## Usage

Add this to your `yazi.toml`:

```toml
[[mgr.prepend_keymap]]
on = ["f", "a"]
run = "plugin tmsu add"
desc = "TMSU: Add tags"

[[mgr.prepend_keymap]]
on = ["f", "d"]
run = "plugin tmsu list"
desc = "TMSU: List tags"

[[mgr.prepend_keymap]]
on = ["f", "l"]
run = "plugin tmsu filter"
desc = "TMSU: List files by tag"

[[mgr.prepend_keymap]]
on = ["f", "r"]
run = "plugin tmsu remove"
desc = "TMSU: Remove tags"

[[mgr.prepend_keymap]]
on = ["f", "c"]
run = "plugin tmsu common"
desc = "TMSU: Common tags"
