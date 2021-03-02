defmodule Linkify.ParserTest do
  use ExUnit.Case, async: true
  doctest Linkify.Parser

  import Linkify.Parser

  describe "url?/2" do
    test "valid scheme true" do
      valid_scheme_urls()
      |> Enum.each(fn url ->
        assert url?(url, scheme: true, validate_tld: true)
      end)
    end

    test "invalid scheme true" do
      invalid_scheme_urls()
      |> Enum.each(fn url ->
        refute url?(url, scheme: true, validate_tld: true)
      end)
    end

    test "valid scheme false" do
      valid_non_scheme_urls()
      |> Enum.each(fn url ->
        assert url?(url, scheme: false, validate_tld: true)
      end)
    end

    test "invalid scheme false" do
      invalid_non_scheme_urls()
      |> Enum.each(fn url ->
        refute url?(url, scheme: false, validate_tld: true)
      end)
    end

    test "checks the tld for url with a scheme when validate_tld: true" do
      custom_tld_scheme_urls()
      |> Enum.each(fn url ->
        refute url?(url, scheme: true, validate_tld: true)
      end)
    end

    test "does not check the tld for url with a scheme when validate_tld: false" do
      custom_tld_scheme_urls()
      |> Enum.each(fn url ->
        assert url?(url, scheme: true, validate_tld: false)
      end)
    end

    test "does not check the tld for url with a scheme when validate_tld: :no_scheme" do
      custom_tld_scheme_urls()
      |> Enum.each(fn url ->
        assert url?(url, scheme: true, validate_tld: :no_scheme)
      end)
    end

    test "checks the tld for url without a scheme when validate_tld: true" do
      custom_tld_non_scheme_urls()
      |> Enum.each(fn url ->
        refute url?(url, scheme: false, validate_tld: true)
      end)
    end

    test "checks the tld for url without a scheme when validate_tld: :no_scheme" do
      custom_tld_non_scheme_urls()
      |> Enum.each(fn url ->
        refute url?(url, scheme: false, validate_tld: :no_scheme)
      end)
    end

    test "does not check the tld for url without a scheme when validate_tld: false" do
      custom_tld_non_scheme_urls()
      |> Enum.each(fn url ->
        assert url?(url, scheme: false, validate_tld: false)
      end)
    end
  end

  describe "email?" do
    test "identifies valid emails" do
      valid_emails()
      |> Enum.each(fn email ->
        assert email?(email, [])
      end)
    end

    test "identifies invalid emails" do
      invalid_emails()
      |> Enum.each(fn email ->
        refute email?(email, [])
      end)
    end

    test "does not validate tlds when validate_tld: false" do
      valid_custom_tld_emails()
      |> Enum.each(fn email ->
        assert email?(email, validate_tld: false)
      end)
    end

    test "validates tlds when validate_tld: true" do
      valid_custom_tld_emails()
      |> Enum.each(fn email ->
        refute email?(email, validate_tld: true)
      end)
    end
  end

  describe "parse" do
    test "handle line breakes" do
      text = "google.com\r\nssss"
      expected = "<a href=\"http://google.com\">google.com</a>\r\nssss"

      assert parse(text) == expected
    end

    test "handle angle bracket in the end" do
      text = "google.com <br>"
      assert parse(text) == "<a href=\"http://google.com\">google.com</a> <br>"

      text = "google.com<br>hey"
      assert parse(text) == "<a href=\"http://google.com\">google.com</a><br>hey"

      text = "hey<br>google.com"
      assert parse(text) == "hey<br><a href=\"http://google.com\">google.com</a>"

      text = "<br />google.com"
      assert parse(text) == "<br /><a href=\"http://google.com\">google.com</a>"

      text = "google.com<"
      assert parse(text) == "<a href=\"http://google.com\">google.com</a><"

      text = "google.com>"
      assert parse(text) == "<a href=\"http://google.com\">google.com</a>>"
    end

    test "does not link attributes" do
      text = "Check out <a href='google.com'>google</a>"
      assert parse(text) == text
      text = "Check out <img src='google.com' alt='google.com'/>"
      assert parse(text) == text
      text = "Check out <span><img src='google.com' alt='google.com'/></span>"
      assert parse(text) == text
    end

    test "does not link inside `<pre>` and `<code>`" do
      text = "<pre>google.com</pre>"
      assert parse(text) == text

      text = "<code>google.com</code>"
      assert parse(text) == text

      text = "<pre><code>google.com</code></pre>"
      assert parse(text) == text
    end

    test "links url inside html" do
      text = "<div>google.com</div>"

      expected = "<div><a href=\"http://google.com\">google.com</a></div>"

      assert parse(text, class: false, rel: false) == expected

      text = "Check out <div class='section'>google.com</div>"

      expected =
        "Check out <div class='section'><a href=\"http://google.com\">google.com</a></div>"

      assert parse(text, class: false, rel: false) == expected
    end

    test "links url inside nested html" do
      text = "<p><strong>google.com</strong></p>"
      expected = "<p><strong><a href=\"http://google.com\">google.com</a></strong></p>"
      assert parse(text, class: false, rel: false) == expected
    end

    test "html links inside html" do
      text = ~s(<p><a href="http://google.com">google.com</a></p>)
      assert parse(text) == text

      text = ~s(<span><a href="http://google.com">google.com</a></span>)
      assert parse(text) == text

      text = ~s(<h1><a href="http://google.com">google.com</a></h1>)
      assert parse(text) == text

      text = ~s(<li><a href="http://google.com">google.com</a></li>)
      assert parse(text) == text
    end

    test "do not link parens" do
      text = " foo (https://example.com/path/folder/), bar"

      expected =
        " foo (<a href=\"https://example.com/path/folder/\">https://example.com/path/folder/</a>), bar"

      assert parse(text, class: false, rel: false, scheme: true) == expected

      text = " foo (example.com/path/folder/), bar"

      expected =
        " foo (<a href=\"http://example.com/path/folder/\">example.com/path/folder/</a>), bar"

      assert parse(text, class: false, rel: false) == expected
    end

    test "do not link punctuation marks in the end" do
      text = "google.com."
      assert parse(text) == "<a href=\"http://google.com\">google.com</a>."

      text = "google.com;"
      assert parse(text) == "<a href=\"http://google.com\">google.com</a>;"

      text = "google.com:"
      assert parse(text) == "<a href=\"http://google.com\">google.com</a>:"

      text = "hack google.com, please"
      assert parse(text) == "hack <a href=\"http://google.com\">google.com</a>, please"

      text = "(check out google.com)"
      assert parse(text) == "(check out <a href=\"http://google.com\">google.com</a>)"
    end

    test "do not link urls" do
      text = "google.com"
      assert parse(text, url: false) == text
    end

    test "do not link `:test.test`" do
      text = ":test.test"

      assert parse(text, %{
               scheme: true,
               extra: true,
               class: false,
               strip_prefix: false,
               new_window: false,
               rel: false
             }) == text
    end
  end

  def valid_number?([list], number) do
    assert List.last(list) == number
  end

  def valid_number?(_, _), do: false

  def valid_scheme_urls,
    do: [
      "https://www.example.com",
      "http://www2.example.com",
      "http://home.example-site.com",
      "http://blog.example.com",
      "http://www.example.com/product",
      "http://www.example.com/products?id=1&page=2",
      "http://www.example.com#up",
      "http://255.255.255.255",
      "http://www.site.com:8008"
    ]

  def invalid_scheme_urls,
    do: [
      "http://invalid.com/perl.cgi?key= | http://web-site.com/cgi-bin/perl.cgi?key1=value1&key2"
    ]

  def valid_non_scheme_urls,
    do: [
      "www.example.com",
      "www2.example.com",
      "www.example.com:2000",
      "www.example.com?abc=1",
      "example.example-site.com",
      "example.com",
      "example.ca",
      "example.tv",
      "example.com:999?one=one"
    ]

  def invalid_non_scheme_urls,
    do: [
      "invalid.com/perl.cgi?key= | web-site.com/cgi-bin/perl.cgi?key1=value1&key2",
      "invalid.",
      "hi..there",
      "555.555.5555",
      "255.255.255.255",
      "255.255.255.255:3000?one=1&two=2"
    ]

  def custom_tld_scheme_urls,
    do: [
      "http://whatever.null/",
      "https://example.o/index.html",
      "http://pleroma.i2p/test",
      "http://misskey.loki"
    ]

  def custom_tld_non_scheme_urls,
    do: [
      "whatever.null/",
      "example.o/index.html",
      "pleroma.i2p/test",
      "misskey.loki"
    ]

  def valid_emails, do: ["rms@ai.mit.edu", "vc@cock.li", "guardian@33y6fjyhs3phzfjj.onion"]
  def invalid_emails, do: ["rms[at]ai.mit.edu", "vc@cock"]
  def valid_custom_tld_emails, do: ["hi@company.null"]
end
