defmodule AutoLinker.Parser do
  @moduledoc """
  Module to handle parsing the the input string.
  """

  alias AutoLinker.Builder

  @doc """
  Parse the given string, identifying items to link.

  Parses the string, replacing the matching urls and phone numbers with an html link.

  ## Examples

      iex> AutoLinker.Parser.parse("Check out google.com")
      ~s{Check out <a href="http://google.com" class="auto-linker" target="_blank" rel="noopener noreferrer">google.com</a>}

      iex> AutoLinker.Parser.parse("call me at x9999", phone: true)
      ~s{call me at <a href="#" class="phone-number" data-phone="9999">x9999</a>}

      iex> AutoLinker.Parser.parse("or at home on 555.555.5555", phone: true)
      ~s{or at home on <a href="#" class="phone-number" data-phone="5555555555">555.555.5555</a>}

      iex> AutoLinker.Parser.parse(", work (555) 555-5555", phone: true)
      ~s{, work <a href="#" class="phone-number" data-phone="5555555555">(555) 555-5555</a>}
  """

  # @invalid_url ~r/\.\.+/
  @invalid_url ~r/(\.\.+)|(^(\d+\.){1,2}\d+$)/

  @match_url ~r{^[\w\.-]+(?:\.[\w\.-]+)+[\w\-\._~%:/?#[\]@!\$&'\(\)\*\+,;=.]+$}

  @match_scheme ~r{^(?:http(s)?:\/\/)?[\w.-]+(?:\.[\w\.-]+)+[\w\-\._~%:/?#[\]@!\$&'\(\)\*\+,;=.]+$}

  @match_phone ~r"((?:x\d{2,7})|(?:(?:\+?1\s?(?:[.-]\s?)?)?(?:\(\s?(?:[2-9]1[02-9]|[2-9][02-8]1|[2-9][02-8][02-9])\s?\)|(?:[2-9]1[02-9]|[2-9][02-8]1|[2-9][02-8][02-9]))\s?(?:[.-]\s?)?)(?:[2-9]1[02-9]|[2-9][02-9]1|[2-9][02-9]{2})\s?(?:[.-]\s?)?(?:[0-9]{4}))"

  @match_hostname ~r{^(?:https?:\/\/)?(?:[^@\n]+\\w@)?(?<host>[^:#~\/\n?]+)}

  @match_ip ~r"^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$"

  # @user
  # @user@example.com
  @match_mention ~r/^@[a-zA-Z\d_-]+@[a-zA-Z0-9_-](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*|@[a-zA-Z\d_-]+/u

  # https://www.w3.org/TR/html5/forms.html#valid-e-mail-address
  @match_email ~r/^[a-zA-Z0-9.!#$%&'*+\/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$/u

  @match_hashtag ~r/^(?<tag>\#\w+)/u

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

  @tlds "./priv/tlds.txt" |> File.read!() |> String.split("\n", trim: true)

  @default_opts ~w(url)a

  def parse(input, opts \\ %{})
  def parse(input, opts) when is_binary(input), do: {input, nil} |> parse(opts) |> elem(0)
  def parse(input, list) when is_list(list), do: parse(input, Enum.into(list, %{}))

  def parse(input, opts) do
    config =
      :auto_linker
      |> Application.get_env(:opts, [])
      |> Enum.into(%{})
      |> Map.put(
        :attributes,
        Application.get_env(:auto_linker, :attributes, [])
      )

    opts =
      Enum.reduce(@default_opts, opts, fn opt, acc ->
        if is_nil(opts[opt]) and is_nil(config[opt]) do
          Map.put(acc, opt, true)
        else
          acc
        end
      end)

    do_parse(input, Map.merge(config, opts))
  end

  defp do_parse(input, %{phone: false} = opts), do: do_parse(input, Map.delete(opts, :phone))
  defp do_parse(input, %{url: false} = opts), do: do_parse(input, Map.delete(opts, :url))

  defp do_parse(input, %{phone: _} = opts) do
    input
    |> do_parse(opts, {"", "", :parsing}, &check_and_link_phone/3)
    |> do_parse(Map.delete(opts, :phone))
  end

  defp do_parse(input, %{hashtag: true} = opts) do
    input
    |> do_parse(opts, {"", "", :parsing}, &check_and_link_hashtag/3)
    |> do_parse(Map.delete(opts, :hashtag))
  end

  defp do_parse(input, %{extra: true} = opts) do
    input
    |> do_parse(opts, {"", "", :parsing}, &check_and_link_extra/3)
    |> do_parse(Map.delete(opts, :extra))
  end

  defp do_parse({text, user_acc}, %{markdown: true} = opts) do
    text
    |> Builder.create_markdown_links(opts)
    |> (&{&1, user_acc}).()
    |> do_parse(Map.delete(opts, :markdown))
  end

  defp do_parse(input, %{email: true} = opts) do
    input
    |> do_parse(opts, {"", "", :parsing}, &check_and_link_email/3)
    |> do_parse(Map.delete(opts, :email))
  end

  defp do_parse({text, user_acc}, %{url: _} = opts) do
    input =
      with exclude <- Map.get(opts, :exclude_patterns),
           true <- is_list(exclude),
           true <- String.starts_with?(text, exclude) do
        {text, user_acc}
      else
        _ ->
          do_parse(
            {text, user_acc},
            opts,
            {"", "", :parsing},
            &check_and_link/3
          )
      end

    do_parse(input, Map.delete(opts, :url))
  end

  defp do_parse(input, %{mention: true} = opts) do
    input
    |> do_parse(opts, {"", "", :parsing}, &check_and_link_mention/3)
    |> do_parse(Map.delete(opts, :mention))
  end

  defp do_parse(input, _), do: input

  defp do_parse({"", user_acc}, _opts, {"", acc, _}, _handler),
    do: {acc, user_acc}

  defp do_parse({"", user_acc}, opts, {buffer, acc, _}, handler) do
    {buffer, user_acc} = run_handler(handler, buffer, opts, user_acc)
    {acc <> buffer, user_acc}
  end

  defp do_parse({"<a" <> text, user_acc}, opts, {buffer, acc, :parsing}, handler),
    do: do_parse({text, user_acc}, opts, {"", acc <> buffer <> "<a", :skip}, handler)

  defp do_parse({"</a>" <> text, user_acc}, opts, {buffer, acc, :skip}, handler),
    do: do_parse({text, user_acc}, opts, {"", acc <> buffer <> "</a>", :parsing}, handler)

  defp do_parse({"<" <> text, user_acc}, opts, {"", acc, :parsing}, handler),
    do: do_parse({text, user_acc}, opts, {"<", acc, {:open, 1}}, handler)

  defp do_parse({">" <> text, user_acc}, opts, {buffer, acc, {:attrs, level}}, handler),
    do:
      do_parse(
        {text, user_acc},
        opts,
        {"", acc <> buffer <> ">", {:html, level}},
        handler
      )

  defp do_parse({<<ch::8>> <> text, user_acc}, opts, {"", acc, {:attrs, level}}, handler) do
    do_parse({text, user_acc}, opts, {"", acc <> <<ch::8>>, {:attrs, level}}, handler)
  end

  defp do_parse({"</" <> text, user_acc}, opts, {buffer, acc, {:html, level}}, handler) do
    {buffer, user_acc} = run_handler(handler, buffer, opts, user_acc)

    do_parse(
      {text, user_acc},
      opts,
      {"", acc <> buffer <> "</", {:close, level}},
      handler
    )
  end

  defp do_parse({">" <> text, user_acc}, opts, {buffer, acc, {:close, 1}}, handler),
    do: do_parse({text, user_acc}, opts, {"", acc <> buffer <> ">", :parsing}, handler)

  defp do_parse({">" <> text, user_acc}, opts, {buffer, acc, {:close, level}}, handler),
    do:
      do_parse(
        {text, user_acc},
        opts,
        {"", acc <> buffer <> ">", {:html, level - 1}},
        handler
      )

  defp do_parse({" " <> text, user_acc}, opts, {buffer, acc, {:open, level}}, handler),
    do:
      do_parse(
        {text, user_acc},
        opts,
        {"", acc <> buffer <> " ", {:attrs, level}},
        handler
      )

  defp do_parse({"\n" <> text, user_acc}, opts, {buffer, acc, {:open, level}}, handler),
    do:
      do_parse(
        {text, user_acc},
        opts,
        {"", acc <> buffer <> "\n", {:attrs, level}},
        handler
      )

  # default cases where state is not important
  defp do_parse(
         {" " <> text, user_acc},
         %{phone: _} = opts,
         {buffer, acc, state},
         handler
       ),
       do: do_parse({text, user_acc}, opts, {buffer <> " ", acc, state}, handler)

  defp do_parse({" " <> text, user_acc}, opts, {buffer, acc, state}, handler) do
    {buffer, user_acc} = run_handler(handler, buffer, opts, user_acc)

    do_parse(
      {text, user_acc},
      opts,
      {"", acc <> buffer <> " ", state},
      handler
    )
  end

  defp do_parse({"\n" <> text, user_acc}, opts, {buffer, acc, state}, handler) do
    {buffer, user_acc} = run_handler(handler, buffer, opts, user_acc)

    do_parse(
      {text, user_acc},
      opts,
      {"", acc <> buffer <> "\n", state},
      handler
    )
  end

  defp do_parse({<<ch::8>>, user_acc}, opts, {buffer, acc, state}, handler) do
    {buffer, user_acc} = run_handler(handler, buffer <> <<ch::8>>, opts, user_acc)

    do_parse(
      {"", user_acc},
      opts,
      {"", acc <> buffer, state},
      handler
    )
  end

  defp do_parse({<<ch::8>> <> text, user_acc}, opts, {buffer, acc, state}, handler),
    do: do_parse({text, user_acc}, opts, {buffer <> <<ch::8>>, acc, state}, handler)

  def check_and_link(buffer, opts, _user_acc) do
    buffer
    |> is_url?(opts[:scheme])
    |> link_url(buffer, opts)
  end

  def check_and_link_email(buffer, opts, _user_acc) do
    buffer
    |> is_email?
    |> link_email(buffer, opts)
  end

  def check_and_link_phone(buffer, opts, _user_acc) do
    buffer
    |> match_phone
    |> link_phone(buffer, opts)
  end

  def check_and_link_mention(buffer, opts, user_acc) do
    buffer
    |> match_mention
    |> link_mention(buffer, opts, user_acc)
  end

  def check_and_link_hashtag(buffer, opts, user_acc) do
    buffer
    |> match_hashtag
    |> link_hashtag(buffer, opts, user_acc)
  end

  def check_and_link_extra("xmpp:" <> handle, opts, _user_acc) do
    handle
    |> is_email?
    |> link_extra("xmpp:" <> handle, opts)
  end

  def check_and_link_extra(buffer, opts, _user_acc) do
    buffer
    |> String.starts_with?(@prefix_extra)
    |> link_extra(buffer, opts)
  end

  # @doc false
  def is_url?(buffer, true) do
    if Regex.match?(@invalid_url, buffer) do
      false
    else
      @match_scheme |> Regex.match?(buffer) |> is_valid_tld?(buffer)
    end
  end

  def is_url?(buffer, _) do
    if Regex.match?(@invalid_url, buffer) do
      false
    else
      @match_url |> Regex.match?(buffer) |> is_valid_tld?(buffer)
    end
  end

  def is_email?(buffer) do
    if Regex.match?(@invalid_url, buffer) do
      false
    else
      @match_email |> Regex.match?(buffer) |> is_valid_tld?(buffer)
    end
  end

  def is_valid_tld?(true, buffer) do
    [host] = Regex.run(@match_hostname, buffer, capture: [:host])

    if is_ip?(host) do
      true
    else
      tld = host |> String.split(".") |> List.last()

      Enum.member?(@tlds, tld)
    end
  end

  def is_valid_tld?(false, _), do: false

  def is_ip?(buffer) do
    Regex.match?(@match_ip, buffer)
  end

  @doc false
  def match_phone(buffer) do
    case Regex.scan(@match_phone, buffer) do
      [] -> nil
      other -> other
    end
  end

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

  def link_phone(nil, buffer, _), do: buffer

  def link_phone(list, buffer, opts) do
    Builder.create_phone_link(list, buffer, opts)
  end

  @doc false
  def link_url(true, buffer, opts) do
    Builder.create_link(buffer, opts)
  end

  def link_url(_, buffer, _opts), do: buffer

  @doc false
  def link_email(true, buffer, opts) do
    Builder.create_email_link(buffer, opts)
  end

  def link_email(_, buffer, _opts), do: buffer

  def link_extra(true, buffer, opts) do
    Builder.create_extra_link(buffer, opts)
  end

  def link_extra(_, buffer, _opts), do: buffer

  defp run_handler(handler, buffer, opts, user_acc) do
    case handler.(buffer, opts, user_acc) do
      {buffer, user_acc} -> {buffer, user_acc}
      buffer -> {buffer, user_acc}
    end
  end
end
