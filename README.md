# Linkify

Linkify is a basic package for turning website names into links.

Use this package in your web view to convert web references into click-able links.

## Installation

The package can be installed by adding `linkify` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:linkify, "~> 0.1"}]
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
```

See the [Docs](https://hexdocs.pm/linkify/) for more examples

```


## License

`auto_linker` is Copyright (c) 2017 E-MetroTel

The source is released under the MIT License.

Check [LICENSE](LICENSE) for more information.
