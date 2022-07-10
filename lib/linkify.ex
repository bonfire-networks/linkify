# Copyright © 2017-2018 E-MetroTel
# Copyright © 2019-2022 Pleroma Authors
# SPDX-License-Identifier: MIT

defmodule Linkify do
  @moduledoc """
  Create url links from text containing urls.

  Turns an input string like `"Check out google.com"` into
  `Check out "<a href=\"http://google.com\">google.com</a>"`

  ## Examples

      iex> Linkify.link("google.com")
      ~s(<a href="http://google.com">google.com</a>)

      iex> Linkify.link("google.com", new_window: true, rel: "noopener noreferrer")
      ~s(<a href="http://google.com" target="_blank" rel="noopener noreferrer">google.com</a>)

      iex> Linkify.link("google.com", class: "linkified")
      ~s(<a href="http://google.com" class="linkified">google.com</a>)
  """

  import Linkify.Parser

  @doc """
  Finds links and turns them into HTML `<a>` tag.

  Options:

  * `class` - specify the class to be added to the generated link.
  * `rel` - specify the rel attribute.
  * `new_window` - set to `true` to add `target="_blank"` attribute
  * `truncate` - Set to a number to truncate urls longer then the number. Truncated urls will end in `...`
  * `strip_prefix` - Strip the scheme prefix (default: `false`)
  * `exclude_class` - Set to a class name when you don't want urls auto linked in the html of the give class (default: `false`)
  * `exclude_id` - Set to an element id when you don't want urls auto linked in the html of the give element (default: `false`)
  * `email` - link email links (default: `false`)
  * `mention` - link @mentions (when `true`, requires `mention_prefix` or `mention_handler` options to be set) (default: `false`)
  * `mention_prefix` - a prefix to build a link for a mention (example: `https://example.com/user/`, default: `nil`)
  * `mention_handler` - a custom handler to validate and format a mention (default: `nil`)
  * `hashtag: false` - link #hashtags (when `true`, requires `hashtag_prefix` or `hashtag_handler` options to be set)
  * `hashtag_prefix: nil` - a prefix to build a link for a hashtag (example: `https://example.com/tag/`)
  * `hashtag_handler: nil` - a custom handler to validate and format a hashtag
  * `extra: false` - link urls with rarely used schemes (magnet, ipfs, irc, etc.)
  * `validate_tld: true` - Set to false to disable TLD validation for urls/emails, also can be set to :no_scheme to validate TLDs only for urls without a scheme (e.g `example.com` will be validated, but `http://example.loki` won't)
  * `iodata` - Set to `true` to return iodata as a result, or `:safe` for iodata with linkified anchor tags wrapped in Phoenix.HTML `:safe` tuples (removes need for further sanitization)
  * `href_handler: nil` - a custom handler to process a url before it is set as the link href, useful for generating exit links
  """
  def link(text, opts \\ []) do
    parse(text, opts)
  end

  def link_to_iodata(text, opts \\ []) do
    parse(text, Keyword.merge(opts, iodata: true))
  end

  def link_safe(text, opts \\ []) do
    parse(text, Keyword.merge(opts, iodata: :safe))
  end

  def link_map(text, acc, opts \\ []) do
    parse({text, acc}, opts)
  end
end
