# Copyright © 2017-2018 E-MetroTel
# Copyright © 2019-2022 Pleroma Authors
# SPDX-License-Identifier: MIT

defmodule Linkify.BuilderTest do
  use ExUnit.Case, async: true
  doctest Linkify.Builder

  import Linkify.Builder

  test "create_link/2" do
    expected = "<a href=\"http://text\">text</a>"

    assert create_link("text", %{}) == expected

    expected = "<a href=\"http://text\" target=\"_blank\">text</a>"

    assert create_link("text", %{new_window: true}) == expected

    expected = "<a href=\"http://text\" class=\"linkified\">text</a>"
    assert create_link("text", %{class: "linkified"}) == expected

    expected = "<a href=\"http://text\" rel=\"me\">text</a>"

    assert create_link("text", %{rel: "me"}) == expected

    expected = "<a href=\"http://text\">t...</a>"

    assert create_link("text", %{truncate: 3}) == expected

    expected = "<a href=\"http://text\">text</a>"
    assert create_link("text", %{truncate: 2}) == expected

    expected = "<a href=\"http://text\">http://text</a>"
    assert create_link("http://text", %{strip_prefix: false}) == expected
  end

  test "format_hashtag/3" do
    expected = "<a href=\"/t/girls\">#girls</a>"
    assert format_hashtag(%{href: "/t/girls"}, "girls", nil) == expected
  end

  test "format_email/3" do
    expected = "<a href=\"mailto:user@example.org\">mailto:user@example.org</a>"

    assert format_email(%{href: "mailto:user@example.org"}, "mailto:user@example.org", nil) ==
             expected
  end

  test "format_mention/3" do
    expected = "<a href=\"url\">@user@host</a>"
    assert format_mention(%{href: "url"}, "user@host", nil) == expected
  end

  test "create_mention_link/3" do
    expected = "<a href=\"/u/navi\">@navi</a>"

    assert create_mention_link("@navi", "hello @navi", %{mention_prefix: "/u/"}) == expected
  end

  test "create_email_link/3" do
    expected = "<a href=\"mailto:user@example.org\">user@example.org</a>"
    assert create_email_link("user@example.org", %{}) == expected
    assert create_email_link("user@example.org", %{href: "mailto:user@example.org"}) == expected
  end
end
