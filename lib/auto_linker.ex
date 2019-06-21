defmodule AutoLinker do
  @moduledoc """
  Create url links from text containing urls.

  Turns an input string like `"Check out google.com"` into
  `Check out "<a href=\"http://google.com\" target=\"_blank\" rel=\"noopener noreferrer\">google.com</a>"`

  ## Examples

      iex> AutoLinker.link("google.com")
      ~s(<a href="http://google.com" class="auto-linker" target="_blank" rel="noopener noreferrer">google.com</a>)

      iex> AutoLinker.link("google.com", new_window: false, rel: false)
      ~s(<a href="http://google.com" class="auto-linker">google.com</a>)

      iex> AutoLinker.link("google.com", new_window: false, rel: false, class: false)
      ~s(<a href="http://google.com">google.com</a>)
  """

  import AutoLinker.Parser

  @doc """
  Auto link a string.

  Options:

  * `class: "auto-linker"` - specify the class to be added to the generated link. false to clear
  * `rel: "noopener noreferrer"` - override the rel attribute. false to clear
  * `new_window: true` - set to false to remove `target='_blank'` attribute
  * `truncate: false` - Set to a number to truncate urls longer then the number. Truncated urls will end in `..`
  * `strip_prefix: true` - Strip the scheme prefix
  * `exclude_class: false` - Set to a class name when you don't want urls auto linked in the html of the give class
  * `exclude_id: false` - Set to an element id when you don't want urls auto linked in the html of the give element
  * `exclude_patterns: ["```"]` - Don't link anything between the the pattern
  * `email: false` - link email links
  * `mention: false` - link @mentions (when `true`, requires `mention_prefix` or `mention_handler` options to be set)
  * `mention_prefix: nil` - a prefix to build a link for a mention (example: `https://example.com/user/`)
  * `mention_handler: nil` - a custom handler to validate and formart a mention
  * `hashtag: false` - link #hashtags (when `true`, requires `hashtag_prefix` or `hashtag_handler` options to be set)
  * `hashtag_prefix: nil` - a prefix to build a link for a hashtag (example: `https://example.com/tag/`)
  * `hashtag_handler: nil` - a custom handler to validate and formart a hashtag
  * `extra: false` - link urls with rarely used schemes (magnet, ipfs, irc, etc.)
  * `validate_tld: true` - Set to false to disable TLD validation for urls/emails, also can be set to :no_scheme to validate TLDs only for urls without a scheme (e.g `example.com` will be validated, but `http://example.loki` won't)

  Each of the above options can be specified when calling `link(text, opts)`
  or can be set in the `:auto_linker`'s configuration. For example:

       config :auto_linker,
         class: false,
         new_window: false

  Note that passing opts to `link/2` will override the configuration settings.
  """
  def link(text, opts \\ []) do
    parse(text, opts)
  end

  def link_map(text, acc, opts \\ []) do
    parse({text, acc}, opts)
  end
end
