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

  test "create_markdown_links/2" do
    expected =
      "<a href='url' class=\"auto-linker\" target=\"_blank\" rel=\"noopener noreferrer\">text</a>"

    assert create_markdown_links("[text](url)", %{}) == expected
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

  describe "create_phone_link" do
    test "finishes" do
      assert create_phone_link([], "", []) == ""
    end

    test "handles one link" do
      phrase = "my exten is x888. Call me."

      expected =
        ~s'my exten is <a href="#" class="phone-number" data-phone="888" test=\"test\">x888</a>. Call me.'

      assert create_phone_link([["x888", ""]], phrase, attributes: [test: "test"]) == expected
    end

    test "handles multiple links" do
      phrase = "555.555.5555 or (555) 888-8888"

      expected =
        ~s'<a href="#" class="phone-number" data-phone="5555555555">555.555.5555</a> or ' <>
          ~s'<a href="#" class="phone-number" data-phone="5558888888">(555) 888-8888</a>'

      assert create_phone_link([["555.555.5555", ""], ["(555) 888-8888"]], phrase, []) == expected
    end
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
