defmodule LinkifyTest do
  use ExUnit.Case, async: true
  doctest Linkify

  test "default link" do
    assert Linkify.link("google.com") ==
             "<a href=\"http://google.com\">google.com</a>"
  end

  test "default link iodata" do
    assert Linkify.link_to_iodata("google.com") ==
             [["<a ", "href=\"http://google.com\"", ">", "google.com", "</a>"]]
  end

  test "default link safe iodata" do
    assert Linkify.link_safe("google.com") ==
             [
               [
                 {:safe, ["<a ", "href=\"http://google.com\"", ">"]},
                 "google.com",
                 {:safe, "</a>"}
               ]
             ]
  end

  test "does on link existing links" do
    text = ~s(<a href="http://google.com">google.com</a>)
    assert Linkify.link(text) == text
  end

  test "all kinds of links" do
    text = "hello google.com https://ddg.com user@email.com irc:///mIRC"

    expected =
      "hello <a href=\"http://google.com\">google.com</a> <a href=\"https://ddg.com\">https://ddg.com</a> <a href=\"mailto:user@email.com\">user@email.com</a> <a href=\"irc:///mIRC\">irc:///mIRC</a>"

    assert Linkify.link(text,
             email: true,
             extra: true
           ) == expected
  end

  test "all kinds of links iodata" do
    text = "hello google.com https://ddg.com user@email.com irc:///mIRC"

    expected = [
      "hello",
      " ",
      ["<a ", "href=\"http://google.com\"", ">", "google.com", "</a>"],
      " ",
      ["<a ", "href=\"https://ddg.com\"", ">", "https://ddg.com", "</a>"],
      " ",
      ["<a ", "href=\"mailto:user@email.com\"", ">", "user@email.com", "</a>"],
      " ",
      ["<a ", "href=\"irc:///mIRC\"", ">", "irc:///mIRC", "</a>"]
    ]

    assert Linkify.link_to_iodata(text,
             email: true,
             extra: true
           ) == expected
  end

  test "class attribute" do
    assert Linkify.link("google.com", class: "linkified") ==
             "<a href=\"http://google.com\" class=\"linkified\">google.com</a>"
  end

  test "class attribute iodata" do
    assert Linkify.link_to_iodata("google.com", class: "linkified") ==
             [
               [
                 "<a ",
                 "href=\"http://google.com\" class=\"linkified\"",
                 ">",
                 "google.com",
                 "</a>"
               ]
             ]
  end

  test "rel attribute" do
    assert Linkify.link("google.com", rel: "noopener noreferrer") ==
             "<a href=\"http://google.com\" rel=\"noopener noreferrer\">google.com</a>"
  end

  test "rel attribute iodata" do
    assert Linkify.link_to_iodata("google.com", rel: "noopener noreferrer") ==
             [
               [
                 "<a ",
                 "href=\"http://google.com\" rel=\"noopener noreferrer\"",
                 ">",
                 "google.com",
                 "</a>"
               ]
             ]
  end

  test "rel as function" do
    text = "google.com"

    expected = "<a href=\"http://google.com\" rel=\"com\">google.com</a>"

    custom_rel = fn url ->
      url |> String.split(".") |> List.last()
    end

    assert Linkify.link(text, rel: custom_rel) == expected

    text = "google.com"

    expected = "<a href=\"http://google.com\">google.com</a>"

    custom_rel = fn _ -> nil end

    assert Linkify.link(text, rel: custom_rel) == expected
  end

  test "strip parens" do
    assert Linkify.link("(google.com)") ==
             "(<a href=\"http://google.com\">google.com</a>)"
  end

  test "strip parens iodata" do
    assert Linkify.link_to_iodata("(google.com)") ==
             [["(", ["<a ", "href=\"http://google.com\"", ">", "google.com", "</a>"], ")"]]
  end

  test "link_map/2" do
    assert Linkify.link_map("google.com", []) ==
             {"<a href=\"http://google.com\">google.com</a>", []}
  end

  describe "custom handlers" do
    test "mentions handler" do
      text = "hello @user, @valid_user and @invalid_user"
      valid_users = ["user", "valid_user"]

      handler = fn "@" <> user = mention, buffer, _opts, acc ->
        if Enum.member?(valid_users, user) do
          link = ~s(<a href="https://example.com/user/#{user}" data-user="#{user}">#{mention}</a>)
          {link, %{acc | mentions: MapSet.put(acc.mentions, {mention, user})}}
        else
          {buffer, acc}
        end
      end

      {result_text, %{mentions: mentions}} =
        Linkify.link_map(text, %{mentions: MapSet.new()},
          mention: true,
          mention_handler: handler
        )

      assert result_text ==
               "hello <a href=\"https://example.com/user/user\" data-user=\"user\">@user</a>, <a href=\"https://example.com/user/valid_user\" data-user=\"valid_user\">@valid_user</a> and @invalid_user"

      assert mentions |> MapSet.to_list() |> Enum.map(&elem(&1, 1)) == valid_users
    end

    test "hashtags handler" do
      text = "#hello #world"

      handler = fn hashtag, buffer, opts, acc ->
        link = Linkify.Builder.create_hashtag_link(hashtag, buffer, opts)
        {link, %{acc | tags: MapSet.put(acc.tags, hashtag)}}
      end

      {result_text, %{tags: tags}} =
        Linkify.link_map(text, %{tags: MapSet.new()},
          hashtag: true,
          hashtag_handler: handler,
          hashtag_prefix: "https://example.com/user/",
          rel: false
        )

      assert result_text ==
               "<a href=\"https://example.com/user/hello\">#hello</a> <a href=\"https://example.com/user/world\">#world</a>"

      assert MapSet.to_list(tags) == ["#hello", "#world"]

      text = "#cofe <br><a href=\"https://pleroma.social/\">Source</a>"

      {_result_text, %{tags: tags}} =
        Linkify.link_map(text, %{tags: MapSet.new()},
          hashtag: true,
          hashtag_handler: handler,
          hashtag_prefix: "https://example.com/tag/"
        )

      assert MapSet.to_list(tags) == ["#cofe"]

      text = "#cofe<br><a href=\"https://pleroma.social/\">Source</a>"

      {_result_text, %{tags: tags}} =
        Linkify.link_map(text, %{tags: MapSet.new()},
          hashtag: true,
          hashtag_handler: handler,
          hashtag_prefix: "https://example.com/tag/"
        )

      assert MapSet.to_list(tags) == ["#cofe"]

      text = "#cofe<a href=\"https://pleroma.social/\">Source</a>"

      {_result_text, %{tags: tags}} =
        Linkify.link_map(text, %{tags: MapSet.new()},
          hashtag: true,
          hashtag_handler: handler,
          hashtag_prefix: "https://example.com/tag/"
        )

      assert MapSet.to_list(tags) == ["#cofe"]

      text = "#cofe<code>fetch()</code>"

      {_result_text, %{tags: tags}} =
        Linkify.link_map(text, %{tags: MapSet.new()},
          hashtag: true,
          hashtag_handler: handler,
          hashtag_prefix: "https://example.com/tag/"
        )

      assert MapSet.to_list(tags) == ["#cofe"]

      text = "#cofe<pre>fetch()</pre>"

      {_result_text, %{tags: tags}} =
        Linkify.link_map(text, %{tags: MapSet.new()},
          hashtag: true,
          hashtag_handler: handler,
          hashtag_prefix: "https://example.com/tag/"
        )

      assert MapSet.to_list(tags) == ["#cofe"]
    end

    test "mention handler and hashtag prefix" do
      text =
        "Hello again, @user.&lt;script&gt;&lt;/script&gt;\nThis is on another :moominmamma: line. #2hu #epic #phantasmagoric"

      handler = fn "@" <> user = mention, _, _, _ ->
        ~s(<span class="h-card"><a href="#/user/#{user}">@<span>#{mention}</span></a></span>)
      end

      expected =
        ~s(Hello again, @user.&lt;script&gt;&lt;/script&gt;\nThis is on another :moominmamma: line. <a href="/tag/2hu" target="_blank">#2hu</a> <a href="/tag/epic" target="_blank">#epic</a> <a href="/tag/phantasmagoric" target="_blank">#phantasmagoric</a>)

      assert Linkify.link(text,
               mention: true,
               mention_handler: handler,
               hashtag: true,
               hashtag_prefix: "/tag/",
               new_window: true
             ) == expected
    end

    test "mentions handler with hostname/@user links" do
      text =
        "hi @user, take a look at this post: https://example.com/@valid_user/posts/9w5AkQp956XIh74apc"

      valid_users = ["user", "valid_user"]

      handler = fn "@" <> user = mention, buffer, _opts, acc ->
        if Enum.member?(valid_users, user) do
          link = ~s(<a href="https://example.com/user/#{user}" data-user="#{user}">#{mention}</a>)
          {link, %{acc | mentions: MapSet.put(acc.mentions, {mention, user})}}
        else
          {buffer, acc}
        end
      end

      {result_text, %{mentions: mentions}} =
        Linkify.link_map(text, %{mentions: MapSet.new()},
          mention: true,
          mention_handler: handler,
          new_window: true
        )

      assert result_text ==
               "hi <a href=\"https://example.com/user/user\" data-user=\"user\">@user</a>, take a look at this post: <a href=\"https://example.com/@valid_user/posts/9w5AkQp956XIh74apc\" target=\"_blank\">https://example.com/@valid_user/posts/9w5AkQp956XIh74apc</a>"

      assert mentions |> MapSet.to_list() |> Enum.map(&elem(&1, 1)) == ["user"]
    end

    test "mentions handler and extra links" do
      text =
        "hi @user, text me asap xmpp:me@cofe.ai, (or contact me at me@cofe.ai), please.<br>cofe.ai."

      valid_users = ["user", "cofe"]

      handler = fn "@" <> user = mention, buffer, _opts, acc ->
        if Enum.member?(valid_users, user) do
          link = ~s(<a href="https://example.com/user/#{user}" data-user="#{user}">#{mention}</a>)
          {link, %{acc | mentions: MapSet.put(acc.mentions, {mention, user})}}
        else
          {buffer, acc}
        end
      end

      {result_text, %{mentions: mentions}} =
        Linkify.link_map(text, %{mentions: MapSet.new()},
          mention: true,
          mention_handler: handler,
          extra: true,
          email: true
        )

      assert result_text ==
               "hi <a href=\"https://example.com/user/user\" data-user=\"user\">@user</a>, text me asap <a href=\"xmpp:me@cofe.ai\">xmpp:me@cofe.ai</a>, (or contact me at <a href=\"mailto:me@cofe.ai\">me@cofe.ai</a>), please.<br><a href=\"http://cofe.ai\">cofe.ai</a>."

      assert MapSet.to_list(mentions) == [{"@user", "user"}]
    end

    test "mentions handler and emails" do
      text = "hi @friend, here is my email<br><br>user@user.me"

      valid_users = ["user", "friend"]

      handler = fn "@" <> user = mention, buffer, _opts, acc ->
        if Enum.member?(valid_users, user) do
          link = ~s(<a href="https://example.com/user/#{user}" data-user="#{user}">#{mention}</a>)
          {link, %{acc | mentions: MapSet.put(acc.mentions, {mention, user})}}
        else
          {buffer, acc}
        end
      end

      {result_text, %{mentions: mentions}} =
        Linkify.link_map(text, %{mentions: MapSet.new()},
          mention: true,
          mention_handler: handler,
          extra: true,
          email: true
        )

      assert result_text ==
               "hi <a href=\"https://example.com/user/friend\" data-user=\"friend\">@friend</a>, here is my email<br><br><a href=\"mailto:user@user.me\">user@user.me</a>"

      assert MapSet.to_list(mentions) == [{"@friend", "friend"}]
    end

    test "href handler" do
      text = ~s(google.com)

      result_text = Linkify.link(text, href_handler: &"/redirect?#{URI.encode_query(to: &1)}")

      assert result_text == ~s(<a href="/redirect?to=http%3A%2F%2Fgoogle.com">google.com</a>)
    end
  end

  describe "mentions" do
    test "simple mentions" do
      expected =
        ~s{hello <a href="https://example.com/user/user" target="_blank">@user</a> and <a href="https://example.com/user/anotherUser" target="_blank">@anotherUser</a>.}

      assert Linkify.link("hello @user and @anotherUser.",
               mention: true,
               mention_prefix: "https://example.com/user/",
               new_window: true
             ) == expected
    end

    test "mentions inside html tags" do
      text =
        "<p><strong>hello world</strong></p>\n<p><`em>another @user__test and @user__test google.com paragraph</em></p>\n"

      expected =
        "<p><strong>hello world</strong></p>\n<p><`em>another <a href=\"u/user__test\">@user__test</a> and <a href=\"u/user__test\">@user__test</a> <a href=\"http://google.com\">google.com</a> paragraph</em></p>\n"

      assert Linkify.link(text, mention: true, mention_prefix: "u/") == expected

      text = "<p>hi</p><p>@user @anotherUser</p>"

      expected =
        "<p>hi</p><p><a href=\"u/user\">@user</a> <a href=\"u/anotherUser\">@anotherUser</a></p>"

      assert Linkify.link(text, mention: true, mention_prefix: "u/") == expected
    end

    test "mention @user@example.com" do
      text = "hey @user@example.com"

      expected =
        "hey <a href=\"https://example.com/user/user@example.com\" target=\"_blank\">@user@example.com</a>"

      assert Linkify.link(text,
               mention: true,
               mention_prefix: "https://example.com/user/",
               new_window: true
             ) == expected

      text = "That's @user@example.com's server"

      assert Linkify.link(text, mention: true, mention_prefix: "https://example.com/user/") ==
               text
    end

    test "mentions with no word-separation before them" do
      text = "@@example hey! >@@test@example.com idolm@ster"

      assert Linkify.link(text, mention: true, mention_prefix: "/users/") == text
    end

    test "invalid mentions" do
      text = "hey user@example"

      assert Linkify.link(text, mention: true, mention_prefix: "/users/") == text
    end

    test "IDN domain" do
      text = "hello @lain@我爱你.com"

      expected = "hello <a href=\"/users/lain@我爱你.com\">@lain@我爱你.com</a>"

      assert Linkify.link(text, mention: true, mention_prefix: "/users/") == expected

      text = "hello @lain@xn--6qq986b3xl.com"

      expected = "hello <a href=\"/users/lain@xn--6qq986b3xl.com\">@lain@xn--6qq986b3xl.com</a>"

      assert Linkify.link(text, mention: true, mention_prefix: "/users/") == expected
    end

    test ".onion domain" do
      text = "Hey @admin@vww6ybal4bd7szmgncyruucpgfkqahzddi37ktceo3ah7ngmcopnpyyd.onion"

      expected =
        "Hey <a href=\"/users/admin@vww6ybal4bd7szmgncyruucpgfkqahzddi37ktceo3ah7ngmcopnpyyd.onion\">@admin@vww6ybal4bd7szmgncyruucpgfkqahzddi37ktceo3ah7ngmcopnpyyd.onion</a>"

      assert Linkify.link(text, mention: true, mention_prefix: "/users/") == expected
    end
  end

  describe "hashtag links" do
    test "hashtag" do
      expected =
        " one <a href=\"https://example.com/tag/2two\" target=\"_blank\">#2two</a> three <a href=\"https://example.com/tag/four\" target=\"_blank\">#four</a>."

      assert Linkify.link(" one #2two three #four.",
               hashtag: true,
               hashtag_prefix: "https://example.com/tag/",
               new_window: true
             ) == expected
    end

    test "must have non-numbers" do
      expected = "<a href=\"/t/1ok\">#1ok</a> #42 #7"

      assert Linkify.link("#1ok #42 #7",
               hashtag: true,
               hashtag_prefix: "/t/",
               rel: false
             ) == expected
    end

    test "support French" do
      text = "#administrateur·rice·s #ingénieur·e·s"

      expected =
        "<a href=\"/t/administrateur·rice·s\">#administrateur·rice·s</a> <a href=\"/t/ingénieur·e·s\">#ingénieur·e·s</a>"

      assert Linkify.link(text,
               hashtag: true,
               hashtag_prefix: "/t/",
               rel: false
             ) == expected
    end

    test "support Telugu" do
      text = "#చక్రం #కకకకక్ #కకకకాక #కకకక్రకకకక"

      expected =
        "<a href=\"/t/చక్రం\">#చక్రం</a> <a href=\"/t/కకకకక్\">#కకకకక్</a> <a href=\"/t/కకకకాక\">#కకకకాక</a> <a href=\"/t/కకకక్రకకకక\">#కకకక్రకకకక</a>"

      assert Linkify.link(text,
               hashtag: true,
               hashtag_prefix: "/t/",
               rel: false
             ) == expected
    end

    test "do not turn urls with hashes into hashtags" do
      text = "google.com#test #test google.com/#test #tag"

      expected =
        "<a href=\"http://google.com#test\">google.com#test</a> <a href=\"https://example.com/tag/test\">#test</a> <a href=\"http://google.com/#test\">google.com/#test</a> <a href=\"https://example.com/tag/tag\">#tag</a>"

      assert Linkify.link(text,
               hashtag: true,
               rel: false,
               hashtag_prefix: "https://example.com/tag/"
             ) == expected
    end

    test "works with non-latin characters" do
      text = "#漢字 #は #тест #ทดสอบ"

      expected =
        "<a href=\"https://example.com/tag/漢字\">#漢字</a> <a href=\"https://example.com/tag/は\">#は</a> <a href=\"https://example.com/tag/тест\">#тест</a> <a href=\"https://example.com/tag/ทดสอบ\">#ทดสอบ</a>"

      assert Linkify.link(text,
               rel: false,
               hashtag: true,
               hashtag_prefix: "https://example.com/tag/"
             ) == expected
    end
  end

  describe "links" do
    test "turning urls into links" do
      text = "Hey, check out http://www.youtube.com/watch?v=8Zg1-TufF%20zY?x=1&y=2#blabla ."

      expected =
        "Hey, check out <a href=\"http://www.youtube.com/watch?v=8Zg1-TufF%20zY?x=1&y=2#blabla\" target=\"_blank\">http://www.youtube.com/watch?v=8Zg1-TufF%20zY?x=1&y=2#blabla</a> ."

      assert Linkify.link(text, new_window: true) == expected

      # no scheme
      text = "Hey, check out www.youtube.com/watch?v=8Zg1-TufF%20zY?x=1&y=2#blabla ."

      expected =
        "Hey, check out <a href=\"http://www.youtube.com/watch?v=8Zg1-TufF%20zY?x=1&y=2#blabla\" target=\"_blank\">www.youtube.com/watch?v=8Zg1-TufF%20zY?x=1&y=2#blabla</a> ."

      assert Linkify.link(text, new_window: true) == expected
    end

    test "turn urls with schema into urls" do
      text = "📌https://google.com"

      expected = "📌<a href=\"https://google.com\">https://google.com</a>"

      assert Linkify.link(text, rel: false) == expected

      text = "http://www.cs.vu.nl/~ast/intel/"

      expected = "<a href=\"http://www.cs.vu.nl/~ast/intel/\">http://www.cs.vu.nl/~ast/intel/</a>"

      assert Linkify.link(text) == expected

      text = "https://forum.zdoom.org/viewtopic.php?f=44&t=57087"

      expected =
        "<a href=\"https://forum.zdoom.org/viewtopic.php?f=44&t=57087\">https://forum.zdoom.org/viewtopic.php?f=44&t=57087</a>"

      assert Linkify.link(text) == expected

      text = "https://en.wikipedia.org/wiki/Sophia_(Gnosticism)#Mythos_of_the_soul"

      expected =
        "<a href=\"https://en.wikipedia.org/wiki/Sophia_(Gnosticism)#Mythos_of_the_soul\">https://en.wikipedia.org/wiki/Sophia_(Gnosticism)#Mythos_of_the_soul</a>"

      assert Linkify.link(text) == expected

      text = "https://en.wikipedia.org/wiki/Duff's_device"

      expected =
        "<a href=\"https://en.wikipedia.org/wiki/Duff's_device\">https://en.wikipedia.org/wiki/Duff's_device</a>"

      assert Linkify.link(text) == expected

      text = "https://1.1.1.1/"

      expected = "<a href=\"https://1.1.1.1/\">https://1.1.1.1/</a>"

      assert Linkify.link(text) == expected

      text = "https://1.1.1.1:8080/"

      expected = "<a href=\"https://1.1.1.1:8080/\">https://1.1.1.1:8080/</a>"

      assert Linkify.link(text) == expected
    end

    test "strip prefix" do
      assert Linkify.link("http://google.com", strip_prefix: true) ==
               "<a href=\"http://google.com\">google.com</a>"

      assert Linkify.link("http://www.google.com", strip_prefix: true) ==
               "<a href=\"http://www.google.com\">google.com</a>"
    end

    test "hostname/@user" do
      text = "https://example.com/@user"

      expected =
        "<a href=\"https://example.com/@user\" target=\"_blank\">https://example.com/@user</a>"

      assert Linkify.link(text, new_window: true) == expected

      text = "https://example.com:4000/@user"

      expected =
        "<a href=\"https://example.com:4000/@user\" target=\"_blank\">https://example.com:4000/@user</a>"

      assert Linkify.link(text, new_window: true) == expected

      text = "https://example.com:4000/@user"

      expected =
        "<a href=\"https://example.com:4000/@user\" target=\"_blank\">https://example.com:4000/@user</a>"

      assert Linkify.link(text, new_window: true) == expected

      text = "@username"

      expected = "@username"

      assert Linkify.link(text, new_window: true) == expected
    end
  end

  describe "non http links" do
    test "xmpp" do
      text = "xmpp:user@example.com"

      expected = "<a href=\"xmpp:user@example.com\">xmpp:user@example.com</a>"

      assert Linkify.link(text, extra: true) == expected
    end

    test "wrong xmpp" do
      text = "xmpp:user.example.com"

      assert Linkify.link(text, extra: true) == text
    end

    test "email" do
      text = "user@example.com"
      expected = "<a href=\"mailto:user@example.com\">user@example.com</a>"
      assert Linkify.link(text, email: true) == expected
    end

    test "magnet" do
      text =
        "magnet:?xt=urn:btih:a4104a9d2f5615601c429fe8bab8177c47c05c84&dn=ubuntu-18.04.1.0-live-server-amd64.iso&tr=http%3A%2F%2Ftorrent.ubuntu.com%3A6969%2Fannounce&tr=http%3A%2F%2Fipv6.torrent.ubuntu.com%3A6969%2Fannounce"

      expected =
        "<a href=\"magnet:?xt=urn:btih:a4104a9d2f5615601c429fe8bab8177c47c05c84&dn=ubuntu-18.04.1.0-live-server-amd64.iso&tr=http%3A%2F%2Ftorrent.ubuntu.com%3A6969%2Fannounce&tr=http%3A%2F%2Fipv6.torrent.ubuntu.com%3A6969%2Fannounce\">magnet:?xt=urn:btih:a4104a9d2f5615601c429fe8bab8177c47c05c84&dn=ubuntu-18.04.1.0-live-server-amd64.iso&tr=http%3A%2F%2Ftorrent.ubuntu.com%3A6969%2Fannounce&tr=http%3A%2F%2Fipv6.torrent.ubuntu.com%3A6969%2Fannounce</a>"

      assert Linkify.link(text, extra: true) == expected
    end

    test "dweb" do
      text =
        "dweb://584faa05d394190ab1a3f0240607f9bf2b7e2bd9968830a11cf77db0cea36a21+v1.0.0/path/to/file.txt"

      expected =
        "<a href=\"dweb://584faa05d394190ab1a3f0240607f9bf2b7e2bd9968830a11cf77db0cea36a21+v1.0.0/path/to/file.txt\">dweb://584faa05d394190ab1a3f0240607f9bf2b7e2bd9968830a11cf77db0cea36a21+v1.0.0/path/to/file.txt</a>"

      assert Linkify.link(text, extra: true) == expected
    end
  end

  describe "TLDs" do
    test "parse with scheme" do
      text = "https://google.com"

      expected = "<a href=\"https://google.com\">https://google.com</a>"

      assert Linkify.link(text) == expected
    end

    test "only existing TLDs with scheme" do
      text = "this url https://google.foobar.blah11blah/ has invalid TLD"

      expected = "this url https://google.foobar.blah11blah/ has invalid TLD"
      assert Linkify.link(text) == expected

      text = "this url https://google.foobar.com/ has valid TLD"

      expected =
        "this url <a href=\"https://google.foobar.com/\">https://google.foobar.com/</a> has valid TLD"

      assert Linkify.link(text) == expected
    end

    test "only existing TLDs without scheme" do
      text = "this url google.foobar.blah11blah/ has invalid TLD"
      assert Linkify.link(text) == text

      text = "this url google.foobar.com/ has valid TLD"

      expected =
        "this url <a href=\"http://google.foobar.com/\">google.foobar.com/</a> has valid TLD"

      assert Linkify.link(text) == expected
    end

    test "only existing TLDs with and without scheme" do
      text = "this url http://google.foobar.com/ has valid TLD"

      expected =
        "this url <a href=\"http://google.foobar.com/\">http://google.foobar.com/</a> has valid TLD"

      assert Linkify.link(text) == expected

      text = "this url google.foobar.com/ has valid TLD"

      expected =
        "this url <a href=\"http://google.foobar.com/\">google.foobar.com/</a> has valid TLD"

      assert Linkify.link(text) == expected
    end

    test "FQDN (with trailing period)" do
      text =
        "Check out this article: https://www.wired.com./story/marissa-mayer-startup-sunshine-contacts/"

      expected =
        "Check out this article: <a href=\"https://www.wired.com./story/marissa-mayer-startup-sunshine-contacts/\">https://www.wired.com./story/marissa-mayer-startup-sunshine-contacts/</a>"

      assert Linkify.link(text) == expected
    end

    test "Do not link trailing punctuation" do
      text = "You can find more info at https://pleroma.social."

      expected =
        "You can find more info at <a href=\"https://pleroma.social\">https://pleroma.social</a>."

      assert Linkify.link(text) == expected

      text = "Of course it was google.com!!"

      expected = "Of course it was <a href=\"http://google.com\">google.com</a>!!"

      assert Linkify.link(text) == expected

      text =
        "First I had to login to hotmail.com, then I had to delete emails because my 15MB quota was full."

      expected =
        "First I had to login to <a href=\"http://hotmail.com\">hotmail.com</a>, then I had to delete emails because my 15MB quota was full."

      assert Linkify.link(text) == expected

      text = "I looked at theonion.com; it was no longer funny."

      expected =
        "I looked at <a href=\"http://theonion.com\">theonion.com</a>; it was no longer funny."

      assert Linkify.link(text) == expected
    end

    test "IDN and punycode domain" do
      text = "FrauBücher.com says Neiiighhh!"

      expected = "<a href=\"http://FrauBücher.com\">FrauBücher.com</a> says Neiiighhh!"

      assert Linkify.link(text) == expected

      text = "xn--fraubcher-u9a.com says Neiiighhh!"

      expected =
        "<a href=\"http://xn--fraubcher-u9a.com\">xn--fraubcher-u9a.com</a> says Neiiighhh!"

      assert Linkify.link(text) == expected
    end

    test ".onion domain" do
      text =
        "The riseup.net hidden service is at vww6ybal4bd7szmgncyruucpgfkqahzddi37ktceo3ah7ngmcopnpyyd.onion"

      expected =
        "The <a href=\"http://riseup.net\">riseup.net</a> hidden service is at <a href=\"http://vww6ybal4bd7szmgncyruucpgfkqahzddi37ktceo3ah7ngmcopnpyyd.onion\">vww6ybal4bd7szmgncyruucpgfkqahzddi37ktceo3ah7ngmcopnpyyd.onion</a>"

      assert Linkify.link(text) == expected
    end

    test "IPv4 is linked" do
      text = "1.1.1.1"

      expected = "<a href=\"http://1.1.1.1\">1.1.1.1</a>"

      assert Linkify.link(text) == expected
    end

    test "shortened IPv4 are not linked" do
      text = "109.99"

      expected = "109.99"

      assert Linkify.link(text) == expected
    end
  end
end
