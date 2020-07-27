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
  @match_mention ~r"^@[a-zA-Z\d_-]+@[a-zA-Z0-9_-](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*|@[a-zA-Z\d_-]+"u

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
    acc = if opts[:iodata], do: [], else: ""
    do_parse(input, opts, {"", acc, :parsing})
  end

  defp accumulate(acc, buffer) when is_list(acc),
    do: [buffer | acc]

  defp accumulate(acc, buffer) when is_binary(acc),
    do: acc <> buffer

  defp accumulate(acc, buffer, trailing) when is_list(acc),
    do: [trailing, buffer | acc]

  defp accumulate(acc, buffer, trailing) when is_binary(acc),
    do: acc <> buffer <> trailing

  defp do_parse({"", user_acc}, _opts, {"", acc, _}) when is_list(acc),
    do: {Enum.reverse(acc), user_acc}

  defp do_parse({"", user_acc}, _opts, {"", acc, _}) when is_binary(acc),
    do: {acc, user_acc}

  defp do_parse({"@" <> text, user_acc}, opts, {buffer, acc, :skip}),
    do: do_parse({text, user_acc}, opts, {"", accumulate(acc, buffer, "@"), :skip})

  defp do_parse({"<a" <> text, user_acc}, opts, {buffer, acc, :parsing}),
    do: do_parse({text, user_acc}, opts, {"", accumulate(acc, buffer, "<a"), :skip})

  defp do_parse({"<pre" <> text, user_acc}, opts, {buffer, acc, :parsing}),
    do: do_parse({text, user_acc}, opts, {"", accumulate(acc, buffer, "<pre"), :skip})

  defp do_parse({"<code" <> text, user_acc}, opts, {buffer, acc, :parsing}),
    do: do_parse({text, user_acc}, opts, {"", accumulate(acc, buffer, "<code"), :skip})

  defp do_parse({"</a>" <> text, user_acc}, opts, {buffer, acc, :skip}),
    do: do_parse({text, user_acc}, opts, {"", accumulate(acc, buffer, "</a>"), :parsing})

  defp do_parse({"</pre>" <> text, user_acc}, opts, {buffer, acc, :skip}),
    do: do_parse({text, user_acc}, opts, {"", accumulate(acc, buffer, "</pre>"), :parsing})

  defp do_parse({"</code>" <> text, user_acc}, opts, {buffer, acc, :skip}),
    do: do_parse({text, user_acc}, opts, {"", accumulate(acc, buffer, "</code>"), :parsing})

  defp do_parse({"<" <> text, user_acc}, opts, {"", acc, :parsing}),
    do: do_parse({text, user_acc}, opts, {"<", acc, {:open, 1}})

  defp do_parse({"<" <> text, user_acc}, opts, {"", acc, {:html, level}}) do
    do_parse({text, user_acc}, opts, {"<", acc, {:open, level + 1}})
  end

  defp do_parse({">" <> text, user_acc}, opts, {buffer, acc, {:attrs, level}}),
    do:
      do_parse(
        {text, user_acc},
        opts,
        {"", accumulate(acc, buffer, ">"), {:html, level}}
      )

  defp do_parse({<<ch::8>> <> text, user_acc}, opts, {"", acc, {:attrs, level}}) do
    do_parse({text, user_acc}, opts, {"", accumulate(acc, <<ch::8>>), {:attrs, level}})
  end

  defp do_parse({"</" <> text, user_acc}, opts, {buffer, acc, {:html, level}}) do
    {buffer, user_acc} = link(buffer, opts, user_acc)

    do_parse(
      {text, user_acc},
      opts,
      {"", accumulate(acc, buffer, "</"), {:close, level}}
    )
  end

  defp do_parse({">" <> text, user_acc}, opts, {buffer, acc, {:close, 1}}),
    do: do_parse({text, user_acc}, opts, {"", accumulate(acc, buffer, ">"), :parsing})

  defp do_parse({">" <> text, user_acc}, opts, {buffer, acc, {:close, level}}),
    do:
      do_parse(
        {text, user_acc},
        opts,
        {"", accumulate(acc, buffer, ">"), {:html, level - 1}}
      )

  defp do_parse({text, user_acc}, opts, {buffer, acc, {:open, level}}) do
    do_parse({text, user_acc}, opts, {"", acc <> buffer, {:attrs, level}})
  end

  defp do_parse(
         {<<char::bytes-size(1), text::binary>>, user_acc},
         opts,
         {buffer, acc, state}
       )
       when char in [" ", "\r", "\n"] do
    {buffer, user_acc} = link(buffer, opts, user_acc)

    do_parse(
      {text, user_acc},
      opts,
      {"", accumulate(acc, buffer, char), state}
    )
  end

  defp do_parse({<<ch::8>>, user_acc}, opts, {buffer, acc, state}) do
    {buffer, user_acc} = link(buffer <> <<ch::8>>, opts, user_acc)

    do_parse(
      {"", user_acc},
      opts,
      {"", accumulate(acc, buffer), state}
    )
  end

  defp do_parse({<<ch::8>> <> text, user_acc}, opts, {buffer, acc, state}),
    do: do_parse({text, user_acc}, opts, {buffer <> <<ch::8>>, acc, state})

  def check_and_link(:url, buffer, opts, _user_acc) do
    str = strip_parens(buffer)

    if url?(str, opts) do
      case @match_url |> Regex.run(str, capture: [:url]) |> hd() do
        ^buffer ->
          link_url(buffer, opts)

        url ->
          buffer
          |> String.split(url)
          |> Enum.intersperse(link_url(url, opts))
          |> if(opts[:iodata], do: & &1, else: &Enum.join(&1)).()
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
    if String.starts_with?(buffer, @prefix_extra), do: link_extra(buffer, opts), else: :nomatch
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
    case Regex.run(@match_mention, buffer) do
      [mention] -> mention
      _ -> nil
    end
  end

  def match_hashtag(buffer) do
    case Regex.run(@match_hashtag, buffer, capture: [:tag]) do
      [hashtag] -> hashtag
      _ -> nil
    end
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
    mention
    |> mention_handler.(buffer, opts, user_acc)
    |> maybe_update_buffer(mention, buffer)
  end

  def link_mention(mention, buffer, opts, _user_acc) do
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

  defp link(buffer, opts, user_acc) do
    opts_list = Map.to_list(opts)

    Enum.reduce_while(@types, {buffer, user_acc}, fn type, _ ->
      if {type, true} in opts_list do
        check_and_link_reducer(type, buffer, opts, user_acc)
      else
        {:cont, {buffer, user_acc}}
      end
    end)
  end

  defp check_and_link_reducer(type, buffer, opts, user_acc) do
    case check_and_link(type, buffer, opts, user_acc) do
      :nomatch -> {:cont, {buffer, user_acc}}
      {buffer, user_acc} -> {:halt, {buffer, user_acc}}
      buffer -> {:halt, {buffer, user_acc}}
    end
  end
end
