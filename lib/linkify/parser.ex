# Copyright © 2017-2018 E-MetroTel
# Copyright © 2019-2022 Pleroma Authors
# SPDX-License-Identifier: MIT

defmodule Linkify.Parser do
  @moduledoc """
  A module for parsing strings to detect links, hashtags, and mentions.
  This parser processes the input string character by character, handling
  various special cases like HTML tags and code blocks.
  """

  import Untangle

  alias Linkify.Builder

  # Individual regex pattern functions to comply with Erlang/OTP 28
  def invalid_url, do: ~r/(\.\.+)|(^(\d+\.){1,2}\d+$)/

  def match_url,
    do:
      ~r{^(?:\W*)?(?<url>(?:https?:\/\/[\w.-]+(?:\.[\w\.-]+)*|(?:https?:\/\/)?[\w.-]+(?:\.[\w\.-]+)+)[\w\-\._~%:\/?#[\]@!\$&'\(\)\*\+,;=.]*$)}u

  def get_scheme_host, do: ~r{^\W*(?<scheme>https?:\/\/)?(?:[^@\n]+\\w@)?(?<host>[^:#~\/\n?]+)}u

  def match_hashtag,
    do: ~r/^(?<tag>\#[[:word:]_]*[[:alpha:]_·\x{200c}][[:word:]_·\p{M}\x{200c}]*)/u

  def match_skipped_tag, do: ~r/^(?<tag>(a|code|pre)).*>*/
  def match_mention, do: ~r/^(?<prefix>@)(?<user>[a-zA-Z\d_-]+)(@(?<host>[^@]+))?$/
  def delimiters, do: ~r/[,;:>?!]*$/

  @en_apostrophes [
    "'",
    "'s",
    "'ll",
    "'d"
  ]

  @prefix_extra [
    "magnet:?",
    "dweb://",
    "dat://",
    "gopher://",
    "ipfs://",
    "ipns://",
    "irc://",
    "ircs://",
    "irc6://",
    "mumble://",
    "ssb://"
  ]

  @tlds "./priv/tlds.txt"
        |> File.read!()
        |> String.split("\n", trim: true)
        |> Enum.concat(["onion"])
        |> MapSet.new()

  @default_opts %{
    url: true,
    validate_tld: true
  }

  @doc """
  Parse the given string, identifying items to link.

  Parses the string, replacing the matching urls with an html link.

  ## Examples

      iex> Linkify.Parser.parse("Check out google.com")
      ~s{Check out <a href="http://google.com">google.com</a>}
  """

  @types [:url, :hashtag, :extra, :mention, :email]

  def parse(input, opts \\ %{})
  def parse(input, opts) when is_binary(input) do
    # Replace non-breaking spaces with regular spaces to avoid pain
    # input = String.replace(input, "\u00A0", " ")
    {input, %{}} |> parse(opts) |> elem(0)
  end
  def parse(input, list) when is_list(list), do: parse(input, Enum.into(list, %{}))

  def parse(input_tuple, opts) when is_tuple(input_tuple) do
    opts = Map.merge(@default_opts, opts)

    {buffer, user_acc} = do_parse(input_tuple, opts, {"", [], :parsing})

    if opts[:iodata] do
      {buffer, user_acc}
      |> debug()
    else
      {if is_list(buffer) do
         buffer
         |> Enum.filter(&is_binary/1)
         |> IO.iodata_to_binary()
       else
         buffer
       end, user_acc}
    end
  end

  defp accumulate(acc, buffer),
    do: [buffer | acc]

  defp accumulate(acc, buffer, trailing),
    do: [trailing, buffer | acc]

  defp do_parse({"", user_acc}, _opts, {"", acc, _}),
    do: {Enum.reverse(acc), user_acc}

  # special handling for hashtags
  defp do_parse(
         {"<" <> text, user_acc},
         %{hashtag: true} = opts,
         {"#" <> _ = buffer, acc, :parsing}
       ) do
    {buffer, user_acc} = link(buffer, opts, user_acc)

    buffer =
      case buffer do
        [_, _, _] -> Enum.join(buffer)
        _ -> buffer
      end

    case Regex.run(match_skipped_tag(), buffer, capture: [:tag]) do
      [tag] ->
        text = String.trim_leading(text, tag)
        do_parse({text, user_acc}, opts, {"", accumulate(acc, buffer, "<#{tag}"), :skip})

      nil ->
        do_parse({text, user_acc}, opts, {"<", accumulate(acc, buffer, ""), {:open, 1}})
    end
  end

  defp do_parse({"<br" <> text, user_acc}, opts, {buffer, acc, :parsing}) do
    {buffer, user_acc} = link(buffer, opts, user_acc)
    do_parse({text, user_acc}, opts, {"", accumulate(acc, buffer, "<br"), {:open, 1}})
  end

  # Skip parsing inside certain HTML tags and code blocks
  defp do_parse({"<a" <> text, user_acc}, opts, {buffer, acc, :parsing}),
    do: do_parse({text, user_acc}, opts, {"", accumulate(acc, buffer, "<a"), :skip})

  defp do_parse({"<pre" <> text, user_acc}, opts, {buffer, acc, :parsing}),
    do: do_parse({text, user_acc}, opts, {"", accumulate(acc, buffer, "<pre"), :skip})

  defp do_parse({"<code" <> text, user_acc}, opts, {buffer, acc, :parsing}),
    do: do_parse({text, user_acc}, opts, {"", accumulate(acc, buffer, "<code"), :skip})

  # Resume parsing after skipped sections
  defp do_parse({"</a>" <> text, user_acc}, opts, {buffer, acc, :skip}),
    do: do_parse({text, user_acc}, opts, {"", accumulate(acc, buffer, "</a>"), :parsing})

  defp do_parse({"</pre>" <> text, user_acc}, opts, {buffer, acc, :skip}),
    do: do_parse({text, user_acc}, opts, {"", accumulate(acc, buffer, "</pre>"), :parsing})

  defp do_parse({"</code>" <> text, user_acc}, opts, {buffer, acc, :skip}),
    do: do_parse({text, user_acc}, opts, {"", accumulate(acc, buffer, "</code>"), :parsing})

  # Handle opening HTML tags
  defp do_parse({"<" <> text, user_acc}, opts, {"", acc, :parsing}),
    do: do_parse({text, user_acc}, opts, {"<", acc, {:open, 1}})

  defp do_parse({"<" <> text, user_acc}, opts, {buffer, acc, :parsing}) do
    {buffer, user_acc} = link(buffer, opts, user_acc)
    do_parse({text, user_acc}, opts, {"", accumulate(acc, buffer, "<"), {:open, 1}})
  end

  # Handle closing HTML tags
  defp do_parse({">" <> text, user_acc}, opts, {buffer, acc, {:attrs, _level}}),
    do: do_parse({text, user_acc}, opts, {"", accumulate(acc, buffer, ">"), :parsing})

  # Handle attributes in HTML tags
  defp do_parse({<<ch::8>> <> text, user_acc}, opts, {"", acc, {:attrs, level}}) do
    do_parse({text, user_acc}, opts, {"", accumulate(acc, <<ch::8>>), {:attrs, level}})
  end

  defp do_parse({text, user_acc}, opts, {buffer, acc, {:open, level}}) do
    do_parse({text, user_acc}, opts, {"", accumulate(acc, buffer), {:attrs, level}})
  end

  # Detect start of Markdown code block
  defp do_parse({"```" <> text, user_acc}, opts, {buffer, acc, :parsing}) do
    do_parse({text, user_acc}, opts, {"", accumulate(acc, buffer, "```"), :codeblock})
  end

  defp do_parse({"`" <> text, user_acc}, opts, {buffer, acc, :parsing}) do
    do_parse({text, user_acc}, opts, {"", accumulate(acc, buffer, "`"), :inline_codeblock})
  end

  # Accumulate content inside Markdown code block
  defp do_parse({text, user_acc}, opts, {buffer, acc, :codeblock = type}) do
    do_code_block({text, user_acc}, opts, {buffer, acc, {type, "```"}})
  end

  defp do_parse({text, user_acc}, opts, {buffer, acc, :inline_codeblock = type}) do
    do_code_block({text, user_acc}, opts, {buffer, acc, {type, "`"}})
  end

  # Handle text after a whitespace
  defp do_parse(
         {<<char::bytes-size(1), text::binary>>, user_acc},
         opts,
         {buffer, acc, state}
       )
       when char in [" ", "\r", "\n", "\u00A0"] do
    {buffer, user_acc} = link(buffer, opts, user_acc)

    do_parse(
      {text, user_acc},
      opts,
      {"", accumulate(acc, buffer, char), state}
    )
  end

  # Handle end of input
  defp do_parse({<<ch::8>>, user_acc}, opts, {buffer, acc, state}) do
    {buffer, user_acc} = link(buffer <> <<ch::8>>, opts, user_acc)

    do_parse(
      {"", user_acc},
      opts,
      {"", accumulate(acc, buffer), state}
    )
  end

  # Handle regular characters
  defp do_parse({<<ch::8>> <> text, user_acc}, opts, {buffer, acc, state}),
    do: do_parse({text, user_acc}, opts, {buffer <> <<ch::8>>, acc, state})

  defp do_code_block({text, user_acc}, opts, {buffer, acc, {type, separator}}) do
    case String.split(text, separator, parts: 2) do
      [code_content, rest] ->
        # End of code block
        do_parse(
          {rest, user_acc},
          opts,
          {"", accumulate(acc, buffer <> code_content, separator), :parsing}
        )

      [remaining_text] ->
        # Still inside the code block, accumulate the entire remaining text
        do_parse({"", user_acc}, opts, {buffer <> remaining_text, acc, type})
    end
  end

  def check_and_link(:url, buffer, opts, user_acc) do
    if url?(buffer, opts) |> flood("url?") do
      case match_url() |> Regex.run(buffer, capture: [:url]) |> hd() do
        ^buffer ->
          link_url(buffer, opts, user_acc)

        url ->
          link = link_url(url, opts, user_acc)
          restore_stripped_symbols(buffer, url, link)
      end
    else
      :nomatch
    end
  end

  def check_and_link(:email, buffer, opts, _user_acc) do
    if email?(buffer, opts), do: link_email(buffer, opts), else: :nomatch
  end

  def check_and_link(:mention, buffer, opts, user_acc) do
    buffer
    |> match_mention(opts)
    |> link_mention(buffer, opts, user_acc)
  end

  def check_and_link(:hashtag, buffer, opts, user_acc) do
    buffer
    |> match_hashtag
    |> link_hashtag(buffer, opts, user_acc)
  end

  def check_and_link(:extra, "xmpp:" <> handle = buffer, opts, _user_acc) do
    if email?(handle, opts), do: link_extra(buffer, opts), else: :nomatch
  end

  def check_and_link(:extra, buffer, opts, _user_acc) do
    if String.starts_with?(buffer, @prefix_extra), do: link_extra(buffer, opts), else: :nomatch
  end

  defp maybe_strip_trailing_period(buffer, type) when type in [:mention, :hashtag, :email],
    do: String.trim_trailing(buffer, ".")

  defp maybe_strip_trailing_period(buffer, _), do: buffer

  defp maybe_strip_parens(buffer) do
    trimmed = trim_leading_paren(buffer)

    with :next <- parens_check_trailing(buffer),
         :next <- parens_found_email(trimmed),
         :next <- parens_found_url(trimmed),
         %{path: path, query: query} = URI.parse(trimmed),
         :next <- parens_in_query(query),
         :next <- parens_found_path_separator(path),
         :next <- parens_path_has_open_paren(path),
         :next <- parens_check_balanced(trimmed) do
      buffer |> trim_leading_paren |> trim_trailing_paren
    else
      :both -> buffer |> trim_leading_paren |> trim_trailing_paren
      :leading_only -> buffer |> trim_leading_paren
      :noop -> buffer
      _ -> buffer
    end
  end

  defp parens_check_trailing(buffer), do: (String.ends_with?(buffer, ")") && :next) || :noop

  defp parens_found_email(trimmed),
    do: (trim_trailing_paren(trimmed) |> email?(nil) && :both) || :next

  defp parens_found_url(trimmed) do
    stripped = trim_trailing_paren(trimmed)

    # Check if the URL with parenthesis is valid first
    if url?(trimmed, %{validate_tld: false}) do
      # If the full URL (with paren) is valid, check if parens are balanced
      graphemes = String.graphemes(trimmed)
      opencnt = graphemes |> Enum.count(fn x -> x == "(" end)
      closecnt = graphemes |> Enum.count(fn x -> x == ")" end)

      if opencnt == closecnt && opencnt > 0 do
        # Don't strip if balanced
        :noop
      else
        # Continue checking
        :next
      end

      # If URL with paren is invalid, check if URL without paren is valid
    else
      if url?(stripped, %{validate_tld: false}) do
        :both
      else
        :next
      end
    end
  end

  defp parens_in_query(query), do: (is_nil(query) && :next) || :both
  defp parens_found_path_separator(path) when is_nil(path), do: :next
  defp parens_found_path_separator(path), do: (String.contains?(path, "/") && :next) || :both
  defp parens_path_has_open_paren(path) when is_nil(path), do: :next
  defp parens_path_has_open_paren(path), do: (String.contains?(path, "(") && :next) || :both

  defp parens_check_balanced(trimmed) do
    graphemes = String.graphemes(trimmed)
    opencnt = graphemes |> Enum.count(fn x -> x == "(" end)
    closecnt = graphemes |> Enum.count(fn x -> x == ")" end)

    if opencnt == closecnt && opencnt > 0 do
      # Don't strip anything if parentheses are balanced
      :noop
    else
      :next
    end
  end

  defp trim_leading_paren(buffer) do
    case buffer do
      "(" <> buffer -> buffer
      buffer -> buffer
    end
  end

  defp trim_trailing_paren(buffer),
    do:
      (String.ends_with?(buffer, ")") && String.slice(buffer, 0, String.length(buffer) - 1)) ||
        buffer

  defp strip_punctuation(buffer), do: String.replace(buffer, delimiters(), "")

  defp strip_en_apostrophes(buffer) do
    Enum.reduce(@en_apostrophes, buffer, fn abbrev, buf ->
      String.replace_suffix(buf, abbrev, "")
    end)
  end

  def url?(buffer, opts) do
    valid_url?(buffer) |> flood("valid_url") && 
    Regex.match?(match_url(), buffer) |> flood("matched?") && 
    valid_tld?(buffer, opts) |> flood("valid_tld?")
  end

  def email?(buffer, opts) do
    # Note: In reality the local part can only be checked by the remote server
    case Regex.run(~r/^(?<user>.*)@(?<host>[^@]+)$/, buffer, capture: [:user, :host]) do
      [_user, hostname] -> valid_hostname?(hostname, opts) && valid_tld?(hostname, opts)
      _ -> false
    end
  end

  defp valid_url?("[" <> _), do: false

  defp valid_url?(url) do
    with {_, [scheme]} <- {:regex, Regex.run(get_scheme_host(), url, capture: [:scheme])},
         true <- scheme == "" do
      !Regex.match?(invalid_url(), url)
    else
      _ ->
        true
    end
  end

  @doc """
  Validates a URL's TLD. Returns a boolean.

  Will return `true` if `:validate_tld` option set to `false`.

  Will skip validation and return `true` if `:validate_tld` set to `:no_scheme` and the url has a scheme.
  """
  def valid_tld?(url, opts) do
    [scheme, host] = Regex.run(get_scheme_host(), url, capture: [:scheme, :host])

    # Remove port from host for validation
    host_without_port = host |> String.split(":") |> List.first()
    has_scheme? = scheme != ""

    cond do
      opts[:validate_tld] == false ->
        true

      # don't validate if scheme is present
      opts[:validate_tld] == :no_scheme and has_scheme? ->
        true

      has_scheme? && ip?(host_without_port) ->
        true

      # For single-word hosts like localhost, require scheme OR port OR path
      String.split(host_without_port, ".") |> length() == 1 ->
        has_port? = String.contains?(url, ":")
        has_path? = String.contains?(url, "/")

        if has_scheme? || has_port? || has_path? do
          # Allow localhost and other single-word hosts if they have additional URL components
          true
        else
          # Reject bare single words without URL context
          false
        end

      true ->
        do_check_valid_tld?(host_without_port)
    end
    |> flood("#{url} valid_tld?")
  end

  defp do_check_valid_tld?(host) do
    tld = host |> String.trim_trailing(".") |> String.split(".") |> List.last()
    MapSet.member?(@tlds, tld)
  end

  def safe_to_integer(string, base \\ 10) do
    String.to_integer(string, base)
  rescue
    _ ->
      nil
  end

  def ip?(buffer) do
    case :inet.parse_strict_address(to_charlist(buffer)) do
      {:error, _} -> false
      {:ok, _} -> true
    end
  end

  # IDN-compatible, ported from musl-libc's is_valid_hostname()
  def valid_hostname?(hostname, opts) do
    cond do
      opts[:validate_hostname] == false ->
        true

      true ->
        hostname
        |> String.to_charlist()
        |> Enum.any?(fn s ->
          !(s >= 0x80 || s in 0x30..0x39 || s in 0x41..0x5A || s in 0x61..0x7A || s in ~c".-:")
        end)
        |> Kernel.!()
    end
  end

  def match_mention(buffer, opts) do
    case Regex.run(opts[:mention_regex] || match_mention(), buffer,
           capture: [:prefix, :user, :host]
         ) do
      [prefix, user, ""] ->
        (prefix || "@") <> user

      [prefix, user, hostname] ->
        # debug(hostname, "match_mention")
        if valid_hostname?(hostname, opts) |> debug && valid_tld?(hostname, opts) |> debug,
          do: (prefix || "@") <> user <> "@" <> hostname,
          else: nil

      other ->
        debug(other)
        nil
    end

    # |> debug("match_mention")
  end

  def match_hashtag(buffer) do
    case Regex.run(match_hashtag(), buffer, capture: [:tag]) do
      [hashtag] -> hashtag
      _ -> nil
    end
  end

  def link_url(url, %{url_handler: url_handler} = opts, user_acc) do
    url
    |> url_handler.(opts, user_acc)
  end

  def link_url(url, opts, _user_acc) do
    Builder.create_link(url, opts)
  end

  def link_hashtag(nil, _buffer, _, _user_acc), do: :nomatch

  def link_hashtag(hashtag, buffer, %{hashtag_handler: hashtag_handler} = opts, user_acc) do
    hashtag
    |> hashtag_handler.(buffer, opts, user_acc)
    |> maybe_update_buffer(hashtag, buffer)
  end

  def link_hashtag(hashtag, buffer, opts, _user_acc) do
    hashtag
    |> Builder.create_hashtag_link(buffer, opts)
    |> maybe_update_buffer(hashtag, buffer)
  end

  def link_mention(nil, _buffer, _, _user_acc), do: :nomatch

  def link_mention(mention, buffer, %{mention_handler: mention_handler} = opts, user_acc) do
    # debug(mention)
    # debug(buffer)

    mention
    |> mention_handler.(buffer, opts, user_acc)
    |> maybe_update_buffer(mention, buffer)
  end

  def link_mention(mention, buffer, opts, _user_acc) do
    # debug(mention)

    mention
    |> Builder.create_mention_link(buffer, opts)
    |> maybe_update_buffer(mention, buffer)
  end

  defp maybe_update_buffer(out, match, buffer) when is_binary(out) do
    maybe_update_buffer({out, nil}, match, buffer)
  end

  defp maybe_update_buffer({out, user_acc}, match, buffer)
       when match != buffer and out != buffer do
    out = String.replace(buffer, match, out)
    {out, user_acc}
  end

  # {out, user_acc}
  defp maybe_update_buffer(out, _match, _buffer), do: out

  @doc false
  def link_email(buffer, opts) do
    Builder.create_email_link(buffer, opts)
  end

  def link_extra(buffer, opts) do
    Builder.create_extra_link(buffer, opts)
  end

  defp link(buffer, opts, user_acc) do
    Enum.reduce_while(@types, {buffer, user_acc}, fn type, _ ->
      if opts[type] == true do
        check_and_link_reducer(type, buffer, opts, user_acc)
      else
        {:cont, {buffer, user_acc}}
      end
    end)
  end

  defp check_and_link_reducer(type, buffer, opts, user_acc) do
    str =
      buffer
      |> String.split("<")
      |> List.first()
      |> strip_en_apostrophes()
      |> strip_punctuation()
      |> maybe_strip_trailing_period(type)
      |> maybe_strip_parens()
      |> debug("processed str")

    debug(buffer, "original buffer")
    debug(str, "stripped str")

    case check_and_link(type, str, opts, user_acc) |> debug("checked_and_linked") do
      :nomatch ->
        {:cont, {buffer, user_acc}}

      {link, user_acc} ->
        {:halt, {restore_stripped_symbols(buffer, str, link), user_acc}}

      link ->
        {:halt, {restore_stripped_symbols(buffer, str, link), user_acc}}
    end
  end

  defp restore_stripped_symbols(buffer, buffer, link), do: link # when buffer and stripped_buffer are the same

  defp restore_stripped_symbols(buffer, stripped_buffer, {link, user_acc}) do
    restore_stripped_symbols(buffer, stripped_buffer, link)
  end

  defp restore_stripped_symbols(buffer, stripped_buffer, link) when is_binary(link) do
    case String.split(buffer, stripped_buffer, parts: 2) do
      [prefix, suffix] -> prefix <> link <> suffix
      [single] when single == buffer -> link
      _ -> buffer
    end
  end

  defp restore_stripped_symbols(buffer, _stripped_buffer, _link), do: buffer

end
