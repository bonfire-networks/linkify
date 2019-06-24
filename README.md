# Linkify

Linkify is a basic package for turning website names, and phone numbers into links.

Use this package in your web view to convert web references into click-able links.

This is a very early version. Some of the described options are not yet functional.

## Installation

The package can be installed by adding `linkify` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:linkify, "~> 0.1"}]
end
```

## Usage

The following examples illustrate some examples on how to use the auto linker.

```iex
iex> Linkify.link("google.com")
"<a href='http://google.com' class='linkified' target='_blank' rel='noopener noreferrer'>google.com</a>"

iex> Linkify.link("google.com", new_window: false, rel: false)
"<a href='http://google.com' class='linkified'>google.com</a>"

iex> Linkify.link("google.com", new_window: false, rel: false, class: false)
"<a href='http://google.com'>google.com</a>"

iex> Linkify.link("call me at x9999", phone: true)
"call me at <a href=\"#\" class=\"phone-number\" data-phone=\"9999\">x9999</a>"

iex> Linkify.link("or at home on 555.555.5555", phone: true)
"or at home on <a href=\"#\" class=\"phone-number\" data-phone=\"5555555555\">555.555.5555</a>"

iex> Linkify.link(", work (555) 555-5555", phone: true)
", work <a href=\"#\" class=\"phone-number\" data-phone=\"5555555555\">(555) 555-5555</a>"
```

See the [Docs](https://hexdocs.pm/linkify/) for more examples

## Configuration

By default, link parsing is enabled and phone parsing is disabled.

```elixir
# enable phone parsing, and disable link parsing
config :linkify, opts: [phone: true, url: false]
```


## License

`auto_linker` is Copyright (c) 2017 E-MetroTel

The source is released under the MIT License.

Check [LICENSE](LICENSE) for more information.
