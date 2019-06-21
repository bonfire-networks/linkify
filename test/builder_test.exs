defmodule AutoLinker.BuilderTest do
  use ExUnit.Case, async: true
  doctest AutoLinker.Builder

  import AutoLinker.Builder

  test "create_link/2" do
    expected =
      "<a href=\"http://text\" class=\"auto-linker\" target=\"_blank\" rel=\"noopener noreferrer\">text</a>"

    assert create_link("text", %{}) == expected

    expected = "<a href=\"http://text\" class=\"auto-linker\" target=\"_blank\">text</a>"
    assert create_link("text", %{rel: nil}) == expected

    expected =
      "<a href=\"http://text\" class=\"auto-linker\" target=\"_blank\" rel=\"me\">text</a>"

    assert create_link("text", %{rel: "me"}) == expected

    expected = "<a href=\"http://text\" class=\"auto-linker\" target=\"_blank\">t...</a>"

    assert create_link("text", %{truncate: 3, rel: false}) == expected

    expected = "<a href=\"http://text\" class=\"auto-linker\" target=\"_blank\">text</a>"
    assert create_link("text", %{truncate: 2, rel: false}) == expected

    expected = "<a href=\"http://text\" class=\"auto-linker\" target=\"_blank\">http://text</a>"
    assert create_link("http://text", %{rel: false, strip_prefix: false}) == expected
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
    expected =
      "<a href=\"/u/navi\" class=\"auto-linker\" target=\"_blank\" rel=\"noopener noreferrer\">@navi</a>"

    assert create_mention_link("@navi", "hello @navi", %{mention_prefix: "/u/"}) == expected
  end

  test "create_email_link/3" do
    expected = "<a href=\"mailto:user@example.org\" class=\"auto-linker\">user@example.org</a>"
    assert create_email_link("user@example.org", %{}) == expected
    assert create_email_link("user@example.org", %{href: "mailto:user@example.org"}) == expected
  end
end
