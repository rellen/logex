defmodule Logex.Configuration.Text do
  @moduledoc """
  A configuration file's text (`.logex`, decision 35; `docs/organisation.md` §4.4).

  Its words are data, as a `.ld` file's section and type words are in
  `Logex.Declarations`: a word of a configuration file's lines is a row of `@keywords`,
  and owes a stanza in `docs/naming.md`, which `test/logex/naming_test.exs` checks. Each
  Milestone 2 item brings its own words (`docs/organisation.md` §4.10). M2-2 brings
  `var_global`, `at` and `program`, with a global's two types, `bool` and `dint`.

  A configuration file reserves its words in that file kind only, in any case (§4.8,
  decision 10). Nothing reads a configuration's text yet, so nothing reserves them: a
  configuration from Elixir, `Logex.Configuration.new!/1`, takes a name spelled like one.
  """

  # The words of a configuration file's lines, in the order a line reads them:
  # `var_global <name> <type> [at <location>]`, then `program <instance> <type>`.
  @keywords ~w(var_global bool dint at program)

  @doc "The words of a configuration file's lines, lowercase."
  def keywords, do: @keywords
end
