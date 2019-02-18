defmodule AutoLinker.Builder do
  @moduledoc """
  Module for building the auto generated link.
  """

  @doc """
  Create a link.
  """
  def create_link(url, opts) do
    []
    |> build_attrs(url, opts, :rel)
    |> build_attrs(url, opts, :target)
    |> build_attrs(url, opts, :class)
    |> build_attrs(url, opts, :scheme)
    |> format_url(url, opts)
  end

  def create_markdown_links(text, opts) do
    []
    |> build_attrs(text, opts, :rel)
    |> build_attrs(text, opts, :target)
    |> build_attrs(text, opts, :class)
    |> format_markdown(text, opts)
  end

  defp build_attrs(attrs, _, opts, :rel) do
    if rel = Map.get(opts, :rel, "noopener noreferrer"), do: [{:rel, rel} | attrs], else: attrs
  end

  defp build_attrs(attrs, _, opts, :target) do
    if Map.get(opts, :new_window, true), do: [{:target, :_blank} | attrs], else: attrs
  end

  defp build_attrs(attrs, _, opts, :class) do
    if cls = Map.get(opts, :class, "auto-linker"), do: [{:class, cls} | attrs], else: attrs
  end

  defp build_attrs(attrs, url, _opts, :scheme) do
    if String.starts_with?(url, ["http://", "https://"]),
      do: [{:href, url} | attrs],
      else: [{:href, "http://" <> url} | attrs]
  end

  defp format_url(attrs, url, opts) do
    url =
      url
      |> strip_prefix(Map.get(opts, :strip_prefix, true))
      |> truncate(Map.get(opts, :truncate, false))

    attrs = format_attrs(attrs)
    "<a #{attrs}>" <> url <> "</a>"
  end

  defp format_attrs(attrs) do
    attrs
    |> Enum.map(fn {key, value} -> ~s(#{key}="#{value}") end)
    |> Enum.join(" ")
  end

  defp format_markdown(attrs, text, _opts) do
    attrs =
      case format_attrs(attrs) do
        "" -> ""
        attrs -> " " <> attrs
      end

    Regex.replace(~r/\[(.+?)\]\((.+?)\)/, text, "<a href='\\2'#{attrs}>\\1</a>")
  end

  defp truncate(url, false), do: url
  defp truncate(url, len) when len < 3, do: url

  defp truncate(url, len) do
    if String.length(url) > len, do: String.slice(url, 0, len - 2) <> "..", else: url
  end

  defp strip_prefix(url, true) do
    url
    |> String.replace(~r/^https?:\/\//, "")
    |> String.replace(~r/^www\./, "")
  end

  defp strip_prefix(url, _), do: url

  def create_phone_link([], buffer, _) do
    buffer
  end

  def create_phone_link([h | t], buffer, opts) do
    create_phone_link(t, format_phone_link(h, buffer, opts), opts)
  end

  def format_phone_link([h | _], buffer, opts) do
    val =
      h
      |> String.replace(~r/[\.\+\- x\(\)]+/, "")
      |> format_phone_link(h, opts)

    # val = ~s'<a href="#" class="phone-number" data-phone="#{number}">#{h}</a>'
    String.replace(buffer, h, val)
  end

  def format_phone_link(number, original, opts) do
    tag = opts[:tag] || "a"
    class = opts[:class] || "phone-number"
    data_phone = opts[:data_phone] || "data-phone"
    attrs = format_attributes(opts[:attributes] || [])
    href = opts[:href] || "#"

    ~s'<#{tag} href="#{href}" class="#{class}" #{data_phone}="#{number}"#{attrs}>#{original}</#{
      tag
    }>'
  end

  def create_mention_link("@" <> name, _buffer, opts) do
    mention_prefix = opts[:mention_prefix]

    url = mention_prefix <> name

    [href: url]
    |> build_attrs(url, opts, :rel)
    |> build_attrs(url, opts, :target)
    |> build_attrs(url, opts, :class)
    |> format_mention(name, opts)
  end

  def create_hashtag_link("#" <> tag, _buffer, opts) do
    hashtag_prefix = opts[:hashtag_prefix]

    url = hashtag_prefix <> tag

    [href: url]
    |> build_attrs(url, opts, :rel)
    |> build_attrs(url, opts, :target)
    |> build_attrs(url, opts, :class)
    |> format_hashtag(tag, opts)
  end

  def create_email_link(email, opts) do
    []
    |> build_attrs(email, opts, :class)
    |> format_email(email, opts)
  end

  def create_extra_link(uri, opts) do
    []
    |> build_attrs(uri, opts, :class)
    |> format_extra(uri, opts)
  end

  def format_mention(attrs, name, _opts) do
    attrs = format_attrs(attrs)
    "<a #{attrs}>@" <> name <> "</a>"
  end

  def format_hashtag(attrs, tag, _opts) do
    attrs = format_attrs(attrs)
    "<a #{attrs}>#" <> tag <> "</a>"
  end

  def format_email(attrs, email, _opts) do
    attrs = format_attrs(attrs)
    ~s(<a href="mailto:#{email}" #{attrs}>#{email}</a>)
  end

  def format_extra(attrs, uri, _opts) do
    attrs = format_attributes(attrs)
    ~s(<a href="#{uri}"#{attrs}>#{uri}</a>)
  end

  defp format_attributes(attrs) do
    Enum.reduce(attrs, "", fn {name, value}, acc ->
      acc <> ~s' #{name}="#{value}"'
    end)
  end
end
