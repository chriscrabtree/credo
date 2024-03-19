defmodule Credo.CheckTest do
  use Credo.Test.Case

  alias Credo.Check
  alias Credo.IssueMeta

  @generated_lines 1000
  test "it should determine the correct scope for long modules in reasonable time" do
    source_file =
      """
      # some_file.ex
      defmodule AliasTest do
        def test do
          [
      #{for _ <- 1..@generated_lines, do: "      :a,\n"}
            :a
          ]

          Any.Thing.test()
        end
      end
      """
      |> to_source_file

    {time_in_microseconds, result} =
      :timer.tc(fn ->
        Check.scope_for(source_file, line: @generated_lines + 9)
      end)

    # Ensures that there are no speed pitfalls like reported here:
    # https://github.com/rrrene/credo/issues/702
    assert time_in_microseconds < 1_000_000
    assert {:def, "AliasTest.test"} == result
  end

  defmodule DocsUriTestCheck do
    use Credo.Check, docs_uri: "https://example.org"

    def run(%SourceFile{} = _source_file, _params \\ []) do
      []
    end
  end

  test "it should use/generate a docs_uri" do
    assert DocsUriTestCheck.docs_uri() == "https://example.org"

    assert Credo.Check.Readability.ModuleDoc.docs_uri() ==
             "https://hexdocs.pm/credo/Credo.Check.Readability.ModuleDoc.html"
  end

  test "it should use/generate an id" do
    assert DocsUriTestCheck.id() == "Credo.CheckTest.DocsUriTestCheck"

    assert Credo.Check.Readability.ModuleDoc.id() == "EX3009"
  end

  test "it should cleanse invalid messages" do
    minimum_meta = IssueMeta.for(%{filename: "nofile.ex"}, %{exit_status: 0})

    invalid_message = <<70, 111, 117, 110, 100, 32, 109, 105, 115, 115, 112, 101, 108, 108, 101, 100, 32, 119, 111, 114, 100, 32, 96, 103, 97, 114, 114, 121, 226, 96, 46>>
    invalid_trigger = <<103, 97, 114, 114, 121, 226>>

    issue =
      Check.format_issue(
        minimum_meta,
        [
          message: invalid_message,
          trigger: invalid_trigger
        ],
        :some_category,
        22,
        __MODULE__
      )

    refute String.valid?(invalid_message)
    refute String.valid?(invalid_trigger)
    refute String.printable?(invalid_message)
    refute String.printable?(invalid_trigger)

    assert String.valid?(issue.message)
    assert String.valid?(issue.trigger)
    assert String.printable?(issue.message)
    assert String.printable?(issue.trigger)

    assert issue.message === "Found misspelled word `garry�`."
    assert issue.trigger === "garry�"
  end
end
