defmodule Linkify.Parser do
  @moduledoc """
  Module to handle parsing the the input string.
  """

  alias Linkify.Builder

  @invalid_url ~r/(\.\.+)|(^(\d+\.){1,2}\d+$)/

  @match_url ~r{^(?:\W*)?(?<url>(?:https?:\/\/)?[\w.-]+(?:\.[\w\.-]+)+[\w\-\._~%:\/?#[\]@!\$&'\(\)\*\+,;=.]+$)}u

  @match_hostname ~r{^\W*(?<scheme>https?:\/\/)?(?:[^@\n]+\\w@)?(?<host>[^:#~\/\n?]+)}u

  @match_ip ~r"^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$"

  # @user
  # @user@example.com
  # &Community
  # &Community@instance.tld
  # +CategoryTag
  # +CategoryTag@instance.tld
  @match_mention ~r"^[@|&|\+][a-zA-Z\d_-]+@[a-zA-Z0-9_-](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*|[@|&|\+][a-zA-Z\d_-]+"u

  # https://www.w3.org/TR/html5/forms.html#valid-e-mail-address
  @match_email ~r"^[a-zA-Z0-9.!#$%&'*+\/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$"u

  @match_hashtag ~r/^(?<tag>\#[[:word:]_]*[[:alpha:]_·][[:word:]_·\p{M}]*)/u

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

  @tlds "./priv/tlds.txt" |> File.read!() |> String.split("\n", trim: true) |> MapSet.new()

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

  @types [:url, :email, :hashtag, :mention, :extra]

  def parse(input, opts \\ %{})
  def parse(input, opts) when is_binary(input), do: {input, %{}} |> parse(opts) |> elem(0)
  def parse(input, list) when is_list(list), do: parse(input, Enum.into(list, %{}))

  def parse(input, opts) do
    opts = Map.merge(@default_opts, opts)
    opts_list = Map.to_list(opts)

    Enum.reduce(@types, input, fn
      type, input ->
        if {type, true} in opts_list do
          do_parse(input, opts, {"", "", :parsing}, type)
        else
          input
        end
    end)
  end

  defp do_parse({"", user_acc}, _opts, {"", acc, _}, _handler),
    do: {acc, user_acc}

  defp do_parse({"@" <> text, user_acc}, opts, {buffer, acc, :skip}, type),
    do: do_parse({text, user_acc}, opts, {"", acc <> buffer <> "@", :skip}, type)

  defp do_parse({"<a" <> text, user_acc}, opts, {buffer, acc, :parsing}, type),
    do: do_parse({text, user_acc}, opts, {"", acc <> buffer <> "<a", :skip}, type)

  defp do_parse({"<pre" <> text, user_acc}, opts, {buffer, acc, :parsing}, type),
    do: do_parse({text, user_acc}, opts, {"", acc <> buffer <> "<pre", :skip}, type)

  defp do_parse({"<code" <> text, user_acc}, opts, {buffer, acc, :parsing}, type),
    do: do_parse({text, user_acc}, opts, {"", acc <> buffer <> "<code", :skip}, type)

  defp do_parse({"</a>" <> text, user_acc}, opts, {buffer, acc, :skip}, type),
    do: do_parse({text, user_acc}, opts, {"", acc <> buffer <> "</a>", :parsing}, type)

  defp do_parse({"</pre>" <> text, user_acc}, opts, {buffer, acc, :skip}, type),
    do: do_parse({text, user_acc}, opts, {"", acc <> buffer <> "</pre>", :parsing}, type)

  defp do_parse({"</code>" <> text, user_acc}, opts, {buffer, acc, :skip}, type),
    do: do_parse({text, user_acc}, opts, {"", acc <> buffer <> "</code>", :parsing}, type)

  defp do_parse({"<" <> text, user_acc}, opts, {"", acc, :parsing}, type),
    do: do_parse({text, user_acc}, opts, {"<", acc, {:open, 1}}, type)

  defp do_parse({"<" <> text, user_acc}, opts, {"", acc, {:html, level}}, type) do
    do_parse({text, user_acc}, opts, {"<", acc, {:open, level + 1}}, type)
  end

  defp do_parse({">" <> text, user_acc}, opts, {buffer, acc, {:attrs, level}}, type),
    do:
      do_parse(
        {text, user_acc},
        opts,
        {"", acc <> buffer <> ">", {:html, level}},
        type
      )

  defp do_parse({<<ch::8>> <> text, user_acc}, opts, {"", acc, {:attrs, level}}, type) do
    do_parse({text, user_acc}, opts, {"", acc <> <<ch::8>>, {:attrs, level}}, type)
  end

  defp do_parse({"</" <> text, user_acc}, opts, {buffer, acc, {:html, level}}, type) do
    {buffer, user_acc} = link(type, buffer, opts, user_acc)

    do_parse(
      {text, user_acc},
      opts,
      {"", acc <> buffer <> "</", {:close, level}},
      type
    )
  end

  defp do_parse({">" <> text, user_acc}, opts, {buffer, acc, {:close, 1}}, type),
    do: do_parse({text, user_acc}, opts, {"", acc <> buffer <> ">", :parsing}, type)

  defp do_parse({">" <> text, user_acc}, opts, {buffer, acc, {:close, level}}, type),
    do:
      do_parse(
        {text, user_acc},
        opts,
        {"", acc <> buffer <> ">", {:html, level - 1}},
        type
      )

  defp do_parse({text, user_acc}, opts, {buffer, acc, {:open, level}}, type) do
    do_parse({text, user_acc}, opts, {"", acc <> buffer, {:attrs, level}}, type)
  end

  defp do_parse(
         {<<char::bytes-size(1), text::binary>>, user_acc},
         opts,
         {buffer, acc, state},
         type
       )
       when char in [" ", "\r", "\n"] do
    {buffer, user_acc} = link(type, buffer, opts, user_acc)

    do_parse(
      {text, user_acc},
      opts,
      {"", acc <> buffer <> char, state},
      type
    )
  end

  defp do_parse({<<ch::8>>, user_acc}, opts, {buffer, acc, state}, type) do
    {buffer, user_acc} = link(type, buffer <> <<ch::8>>, opts, user_acc)

    do_parse(
      {"", user_acc},
      opts,
      {"", acc <> buffer, state},
      type
    )
  end

  defp do_parse({<<ch::8>> <> text, user_acc}, opts, {buffer, acc, state}, type),
    do: do_parse({text, user_acc}, opts, {buffer <> <<ch::8>>, acc, state}, type)

  def check_and_link(:url, buffer, opts, user_acc) do
    str = strip_parens(buffer)

    if url?(str, opts) do
      case @match_url |> Regex.run(str, capture: [:url]) |> hd() do
        ^buffer -> maybe_link_url(buffer, opts, user_acc)
        url -> String.replace(buffer, url, maybe_link_url(url, opts, user_acc))
      end
    else
      buffer
    end
  end

  def check_and_link(:email, buffer, opts, _user_acc) do
    if email?(buffer, opts), do: link_email(buffer, opts), else: buffer
  end

  def check_and_link(:mention, buffer, opts, user_acc) do
    buffer
    |> match_mention
    |> link_mention(buffer, opts, user_acc)
  end

  def check_and_link(:hashtag, buffer, opts, user_acc) do
    buffer
    |> match_hashtag
    |> link_hashtag(buffer, opts, user_acc)
  end

  def check_and_link(:extra, "xmpp:" <> handle, opts, _user_acc) do
    if email?(handle, opts), do: link_extra("xmpp:" <> handle, opts), else: handle
  end

  def check_and_link(:extra, buffer, opts, _user_acc) do
    if String.starts_with?(buffer, @prefix_extra), do: link_extra(buffer, opts), else: buffer
  end

  defp strip_parens("(" <> buffer) do
    ~r/[^\)]*/ |> Regex.run(buffer) |> hd()
  end

  defp strip_parens(buffer), do: buffer

  def url?(buffer, opts) do
    valid_url?(buffer) && Regex.match?(@match_url, buffer) && valid_tld?(buffer, opts)
  end

  def email?(buffer, opts) do
    valid_url?(buffer) && Regex.match?(@match_email, buffer) && valid_tld?(buffer, opts)
  end

  defp valid_url?(url), do: !Regex.match?(@invalid_url, url)

  @doc """
  Validates a URL's TLD. Returns a boolean.

  Will return `true` if `:validate_tld` option set to `false`.

  Will skip validation and return `true` if `:validate_tld` set to `:no_scheme` and the url has a scheme.
  """
  def valid_tld?(url, opts) do
    [scheme, host] = Regex.run(@match_hostname, url, capture: [:scheme, :host])

    cond do
      opts[:validate_tld] == false ->
        true

      ip?(host) ->
        true

      # don't validate if scheme is present
      opts[:validate_tld] == :no_scheme and scheme != "" ->
        true

      true ->
        tld = host |> String.split(".") |> List.last()
        MapSet.member?(@tlds, tld)
    end
  end

  def ip?(buffer), do: Regex.match?(@match_ip, buffer)

  def match_mention(buffer) do
    # IO.inspect(match_mention: buffer)

    case Regex.run(@match_mention, buffer) do
      [mention] ->
        # IO.inspect(matched_mention: mention)
        mention

      _ ->
        nil
    end
  end

  def match_hashtag(buffer) do
    case Regex.run(@match_hashtag, buffer, capture: [:tag]) do
      [hashtag] -> hashtag
      _ -> nil
    end
  end

  def maybe_link_url(url, %{url_handler: url_handler} = opts, user_acc) do
    url
    |> url_handler.(opts, user_acc)
  end

  def maybe_link_url(url, opts, _user_acc) do
    link_url(url, opts)
  end

  def link_hashtag(nil, buffer, _, _user_acc), do: buffer

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

  def link_mention(nil, buffer, _, user_acc), do: {buffer, user_acc}

  def link_mention(mention, buffer, %{mention_handler: mention_handler} = opts, user_acc) do
    # IO.inspect(link_mention: mention)
    # IO.inspect(link_mention: buffer)

    mention
    |> mention_handler.(buffer, opts, user_acc)
    |> maybe_update_buffer(mention, buffer)
  end

  def link_mention(mention, buffer, opts, _user_acc) do
    # IO.inspect(link_mention_default: mention)

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

  defp maybe_update_buffer(out, _match, _buffer), do: out

  @doc false
  def link_url(buffer, opts) do
    Builder.create_link(buffer, opts)
  end

  @doc false
  def link_email(buffer, opts) do
    Builder.create_email_link(buffer, opts)
  end

  def link_extra(buffer, opts) do
    Builder.create_extra_link(buffer, opts)
  end

  defp link(type, buffer, opts, user_acc) do
    case check_and_link(type, buffer, opts, user_acc) do
      {buffer, user_acc} -> {buffer, user_acc}
      buffer -> {buffer, user_acc}
    end
  end
end
