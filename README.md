# Linkify

Linkify is a basic package for turning website names into links.

Use this package in your web view to convert web references into click-able links.

## Installation

The package can be installed by adding `linkify` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:linkify, "~> 0.5"}]
end
```

## Usage

The following examples illustrate some examples on how to use the auto linker.

```elixir

iex> Linkify.link("google.com")
"<a href=\"http://google.com\">google.com</a>"

iex> Linkify.link("google.com", class: "linkified")
"<a href=\"http://google.com\" class=\"linkified\">google.com</a>"

iex> Linkify.link("google.com", new_window: true)
"<a href=\"http://google.com\" target=\"_blank\">google.com</a>"

iex> Linkify.link("google.com", new_window: true, rel: "noopener noreferrer")
"<a href=\"http://google.com\" target=\"_blank\" rel=\"noopener noreferrer\">google.com</a>"

iex> Linkify.link("Hello @niceguy17@pleroma.com", mention: true, mention_prefix: "/users/")
"Hello <a href=\"/users/niceguy17@pleroma.com\">@niceguy17@pleroma.com</a>"
```

See the [Docs](https://hexdocs.pm/linkify/) for more examples

## Acknowledgments

This is a fork of [auto_linker](https://github.com/smpallen99/auto_linker) by [Steve Pallen](https://github.com/smpallen99).

## License

Copyright © 2017-2018 E-MetroTel

Copyright © 2019-2022 Pleroma Authors

SPDX-License-Identifier: MIT AND CC0-1.0

Check [REUSE Specification](https://reuse.software/spec/) on how to get more information.
