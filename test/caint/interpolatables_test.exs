defmodule Caint.InterpolatablesTest do
  use ExUnit.Case

  alias Caint.Interpolatables
  alias Caint.Translations.Translation
  alias Expo.Message.Plural

  describe "plural_numbered_string/2" do
    test "works" do
      translation =
        %Translation{
          message: %Plural{
            msgid: ["%{count} category"],
            msgstr: %{0 => [""], 1 => [""]},
            msgctxt: ["context"],
            msgid_plural: ["%{count} categories"]
          },
          context: "context",
          domain: "domain",
          locale: "en"
        }

      assert Interpolatables.plural_numbered_string(translation, 1) == "1 category"
      assert Interpolatables.plural_numbered_string(translation, 2) == "2 categories"
    end

    test "works for multi-line msgids" do
      translation =
        %Translation{
          message: %Plural{msgid: ["", "%{count} long ", "category"], msgid_plural: ["", "%{count} long ", "categories"]},
          context: nil,
          domain: "domain",
          locale: "en"
        }

      assert Interpolatables.plural_numbered_string(translation, 1) == "1 long category"
      assert Interpolatables.plural_numbered_string(translation, 3) == "3 long categories"
    end

    test "returns incomplete string when missing bindings" do
      translation =
        %Translation{
          message: %Plural{
            msgid: ["%{count} category for %{name}"],
            msgstr: %{0 => [""], 1 => [""]},
            msgctxt: ["context"],
            msgid_plural: ["%{count} categories"]
          },
          context: "context",
          domain: "domain",
          locale: "en"
        }

      assert Interpolatables.plural_numbered_string(translation, 1) == "1 category for %{name}"
    end
  end
end
