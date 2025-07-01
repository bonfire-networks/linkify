# Copyright © 2017-2018 E-MetroTel
# Copyright © 2019-2022 Pleroma Authors
# SPDX-License-Identifier: MIT

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
      text = " foo (https://example.local/path/folder/), bar"

      expected =
        " foo (<a href=\"https://example.local/path/folder/\">https://example.local/path/folder/</a>), bar"

      assert parse(text, class: false, rel: false, scheme: true, validate_tld: false) == expected

      text = " foo (example.com/path/folder/), bar"

      expected =
        " foo (<a href=\"http://example.com/path/folder/\">example.com/path/folder/</a>), bar"

      assert parse(text, class: false, rel: false) == expected
    end

    test "do not link reserved chars (punctuation marks) in the end" do
      text = "google.com;"
      assert parse(text) == "<a href=\"http://google.com\">google.com</a>;"

      text = "google.com:"
      assert parse(text) == "<a href=\"http://google.com\">google.com</a>:"

      text = "hack google.com, please"
      assert parse(text) == "hack <a href=\"http://google.com\">google.com</a>, please"

      text = "(check out google.com)"
      assert parse(text) == "(check out <a href=\"http://google.com\">google.com</a>)"
    end

    test "links include periods at the end" do
      text =
        "The article is at https://en.wikipedia.org/wiki/Revlon,_Inc._v._MacAndrews_%26_Forbes_Holdings,_Inc."

      assert parse(text) ==
               "The article is at <a href=\"https://en.wikipedia.org/wiki/Revlon,_Inc._v._MacAndrews_%26_Forbes_Holdings,_Inc.\">https://en.wikipedia.org/wiki/Revlon,_Inc._v._MacAndrews_%26_Forbes_Holdings,_Inc.</a>"
    end

    test "double dot in link is allowed" do
      text = "https://example.to/something..mp3"
      assert parse(text) == "<a href=\"#{text}\">#{text}</a>"
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

    test "markdown doc links with trailing parens does not raise" do
      text = "# **mix gettext.merge**\n\nMerges PO/POT files with PO files.\n\nThis task is used when messages in the source code change: when they do, [`mix gettext.extract`](https://hexdocs.pm/gettext/Mix.Tasks.Gettext.Extract.html) is usually used to extract the new messages to POT files. At this point, developers or translators can use this task to \"sync\" the newly-updated POT files with the existing locale-specific PO files. All the metadata for each message (like position in the source code, comments, and so on) is taken from the newly-updated POT file; the only things taken from the PO file are the actual translated strings.\n\n#### **Fuzzy Matching**\n\nMessages in the updated PO/POT file that have an exact match (a message with the same `msgid`) in the old PO file are merged as described above. When a message in the updated PO/POT files has no match in the old PO file, Gettext attemps a **fuzzy match** for that message. For example, imagine we have this POT file:\n\n```\nmsgid \"hello, world!\"\nmsgstr \"\"copy\n```\n\nand we merge it with this PO file:\n\n```\n# No exclamation point here in the msgid\nmsgid \"hello, world\"\nmsgstr \"ciao, mondo\"copy\n```\n\nSince the two messages are similar, Gettext takes the `msgstr` from the existing message over to the new message, which it however marks as *fuzzy*:\n\n```\n#, fuzzy\nmsgid \"hello, world!\"\nmsgstr \"ciao, mondo\"copy\n```\n\nGenerally, a `fuzzy` flag calls for review from a translator.\n\nFuzzy matching can be configured (for example, the threshold for message similarity can be tweaked) or disabled entirely. Look at the [\"Options\" section](https://hexdocs.pm/gettext/Mix.Tasks.Gettext.Merge.html#module-options).\n\n## **Usage**\n\n```\nmix gettext.merge OLD_FILE UPDATED_FILE [OPTIONS]\nmix gettext.merge DIR [OPTIONS]\ncopy\n```\n\nIf two files are given as arguments, `OLD_FILE` must be a `.po` file and `UPDATE_FILE` must be a `.po`/`.pot` file. The first one is the old PO file, while the second one is the last generated one. They are merged and written over the first file. For example:\n\n```\nmix gettext.merge priv/gettext/en/LC_MESSAGES/default.po priv/gettext/default.pot\ncopy\n```\n\nIf only one argument is given, then that argument must be a directory containing Gettext messages (with `.pot` files at the root level alongside locale directories - this is usually a \"backend\" directory used by a Gettext backend, see [`Gettext.Backend`](https://hexdocs.pm/gettext/Gettext.Backend.html)). For example:\n\n```\nmix gettext.merge priv/gettext\ncopy\n```\n\nIf the `--locale LOCALE` option is given, then only the PO files in `<DIR>/<LOCALE>/LC_MESSAGES` will be merged with the POT files in `DIR`. If no options are given, then all the PO files for all locales under `DIR` are merged with the POT files in `DIR`.\n\n## **Plural Forms**\n\nBy default, Gettext will determine the number of plural forms for newly-generated messages by checking the value of `nplurals` in the `Plural-Forms` header in the existing `.po` file. If a `.po` file doesn't already exist and Gettext is creating a new one or if the `Plural-Forms` header is not in the `.po` file, Gettext will use the number of plural forms that the plural module (see [`Gettext.Plural`](https://hexdocs.pm/gettext/Gettext.Plural.html)) returns for the locale of the file being created. The content of the `Plural-Forms` header can be forced through the `--plural-forms-header` option (see below).\n\n## **Options**\n\n* `--locale` - a string representing a locale. If this is provided, then only the PO files in `<DIR>/<LOCALE>/LC_MESSAGES` will be merged with the POT files in `DIR`. This option can only be given when a single argument is passed to the task (a directory).\n* `--no-fuzzy` - don't perform fuzzy matching when merging files.\n* `--fuzzy-threshold` - a float between `0` and `1` which represents the minimum Jaro distance needed for two messages to be considered a fuzzy match. Overrides the global `:fuzzy_threshold` option (see the docs for[`Gettext`](https://hexdocs.pm/gettext/Gettext.html) for more information on this option).\n* `--plural-forms` - (**deprecated in v0.22.0**) an integer strictly greater than `0`. If this is passed, new messages in the target PO files will have this number of empty plural forms. This is deprecated in favor of passing the `--plural-forms-header`, which contains the whole plural-forms specification. See the \"Plural forms\" section above.\n* `--plural-forms-header` - the content of the `Plural-Forms` header as a string. If this is passed, new messages in the target PO files will use this content to determine the number of plurals. See the [\"Plural Forms\" section](https://hexdocs.pm/gettext/Mix.Tasks.Gettext.Merge.html#module-plural-forms).\n* `--on-obsolete` - controls what happens when **obsolete** messages are found. If `mark_as_obsolete`, messages are kept and marked as obsolete. If `delete`, obsolete messages are deleted. Defaults to `delete`.\n* `--store-previous-message-on-fuzzy-match` - controls if the previous messages are recorded on fuzzy matches. Is off by default.\n\n# **Summary**\n\n## **[Functions](https://hexdocs.pm/gettext/Mix.Tasks.Gettext.Merge.html#functions)**\n\n**[locale\\_dir(pot\\_dir, locale)](https://hexdocs.pm/gettext/Mix.Tasks.Gettext.Merge.html#locale_dir/2)**\n\n# **Functions**\n\n[Link to this function](https://hexdocs.pm/gettext/Mix.Tasks.Gettext.Merge.html#locale_dir/2 \"Link to this function\")\n\n# **locale\\_dir(pot\\_dir, locale)**\n\n[View Source](https://github.com/elixir-gettext/gettext/blob/v0.26.2/lib/mix/tasks/gettext.merge.ex#L199 \"View Source\")\n\n"

      assert Linkify.Parser.parse(text) |> is_binary()
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
