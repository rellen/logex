defmodule Logex.NamingTest do
  @moduledoc """
  The naming survey is a step in the recipe, not a good intention.

  `docs/naming.md` records what IEC 61131-3 and the major vendors call each
  operation, and why logex chose the name it did. This test fails if a mnemonic
  reaches `@instructions`, a section or type word reaches `Logex.Declarations`, a
  word that heads a file of another kind reaches `Logex.Declarations.kinds/0`, or a
  word of a configuration file's lines reaches `Logex.Configuration.Text`, without a
  stanza there.

  The check is deliberately one-way: a stanza with no implementation is fine and
  encouraged — surveying an instruction long before building it is the point.
  """
  use ExUnit.Case

  @survey Path.expand("../../docs/naming.md", __DIR__)

  # Stanza headings live under the "## Stanzas" section. Anchoring there rather
  # than grepping the whole file keeps the blank template in "Adding a stanza",
  # which sits inside a fenced block, from counting as a survey entry.
  #
  # A family of words may share one stanza (docs/organisation.md §4.12's routine choice, M5-3:
  # the 56 integer conversions), headed by one of them, its `**Members:**` line naming each,
  # and every word that line names is surveyed by it.
  defp surveyed_mnemonics, do: MapSet.union(headed(), MapSet.new(Enum.concat(families())))

  defp stanzas do
    @survey
    |> File.read!()
    |> String.split("\n## Stanzas\n", parts: 2)
    |> Enum.at(1)
    |> Kernel.||("")
  end

  defp headed do
    ~r/^### `([a-z_][a-z0-9_]*)`/m
    |> Regex.scan(stanzas())
    |> Enum.map(fn [_, mnemonic] -> mnemonic end)
    |> MapSet.new()
  end

  # Each family stanza's members, as data: one list a `**Members:**` line.
  defp families do
    for [_, line] <- Regex.scan(~r/^\*\*Members:\*\* (.*)$/m, stanzas()),
        do: for([_, word] <- Regex.scan(~r/`([a-z_][a-z0-9_]*)`/, line), do: word)
  end

  test "docs/naming.md exists and has a Stanzas section" do
    assert File.exists?(@survey), "expected the naming survey at #{@survey}"
    assert File.read!(@survey) =~ "\n## Stanzas\n"
  end

  # M5-3 (decision 148): the integer conversions' stanza names every ordered pair of the
  # eight integer types, each once, and its heading is one of them. M5-8 (decisions 148 and
  # 155): so do the bit strings' two, the 12 between two bit strings and the 64 between a
  # bit string and an integer type, either way: 132 conversions in three families. M5-10
  # (decisions 148 and 162): and the reals' two, the 34 between a real and an integer type
  # either way and between the two reals, and the 16 truncations: 182 in five.
  test "a family stanza's members are read as data: the 182 conversions" do
    integers = ~w(sint int dint lint usint uint udint ulint)
    bits = ~w(byte word dword lword)
    reals = ~w(real lreal)
    pairs = for from <- integers, to <- integers, from != to, do: "#{from}_to_#{to}"
    between = for from <- bits, to <- bits, from != to, do: "#{from}_to_#{to}"

    mixed =
      for(from <- bits, to <- integers, do: "#{from}_to_#{to}") ++
        for from <- integers, to <- bits, do: "#{from}_to_#{to}"

    real =
      for(from <- reals, to <- integers, do: "#{from}_to_#{to}") ++
        for(from <- integers, to <- reals, do: "#{from}_to_#{to}") ++
        ~w(real_to_lreal lreal_to_real)

    truncations = for from <- reals, to <- integers, do: "#{from}_trunc_#{to}"

    assert [members, bit_members, mixed_members, real_members, trunc_members] = families()

    assert {length(pairs), length(between), length(mixed), length(real), length(truncations)} ==
             {56, 12, 64, 34, 16}

    assert Enum.sort(members) == Enum.sort(pairs)
    assert Enum.sort(bit_members) == Enum.sort(between)
    assert Enum.sort(mixed_members) == Enum.sort(mixed)
    assert Enum.sort(real_members) == Enum.sort(real)
    assert Enum.sort(trunc_members) == Enum.sort(truncations)

    all = members ++ bit_members ++ mixed_members ++ real_members ++ trunc_members
    assert length(all) == 182
    assert Enum.uniq(all) == all

    assert "dint_to_int" in headed()
    assert "byte_to_word" in headed()
    assert "word_to_int" in headed()
    assert "real_to_int" in headed()
    assert "real_trunc_int" in headed()
  end

  test "every implemented instruction has been surveyed" do
    implemented = Logex.Compiler.instructions() |> Map.keys() |> MapSet.new()
    unsurveyed = MapSet.difference(implemented, surveyed_mnemonics())

    assert MapSet.equal?(unsurveyed, MapSet.new()), """
    These instructions are in @instructions but have no stanza in docs/naming.md:

        #{unsurveyed |> Enum.sort() |> Enum.join(", ")}

    Survey the name before shipping it — see the recipe in CLAUDE.md. Copy the
    template from the "Adding a stanza" section of docs/naming.md, fill every
    dialect row, and mark anything you could not check `unverified`.
    """
  end

  test "every section and type word of a declaration line has been surveyed" do
    words = Logex.Declarations.keywords() |> MapSet.new()
    unsurveyed = MapSet.difference(words, surveyed_mnemonics())

    assert MapSet.equal?(unsurveyed, MapSet.new()), """
    These declaration words are in Logex.Declarations but have no stanza in docs/naming.md:

        #{unsurveyed |> Enum.sort() |> Enum.join(", ")}

    A section or type word is reserved like a mnemonic, and is surveyed like one.
    """
  end

  # The test above reads `keywords/0`, so the list is pinned, as a configuration file's
  # is below: a word dropped from it would drop its survey from the check unseen, and so
  # every word a declaration line reserves as a section or type, each key of
  # `Logex.FbType.builtins/0` among them, is one of it (M5-5's review: `ctu_dint`,
  # `ctd_dint` and `ctud_dint` left out of the list kept their reservation and lost their
  # survey's check).
  test "a declaration line's words are those of the items that have landed" do
    # M1-3: the sections and `bool` and `dint`; M1-6: `ton`; M2-4: `var_external`; M3-1:
    # the counters; M3-2: the other timers; M5-3: the seven other integer types; M5-5:
    # the twelve typed counters and the three dint aliases (decisions 158 and 163); M5-6:
    # the four long timers (decision 158); M5-8: the four bit strings (decision 155);
    # M5-10: the two reals (decision 144).
    counters =
      for kind <- ~w(ctu ctd ctud), count <- ~w(int dint lint udint ulint), do: "#{kind}_#{count}"

    assert Enum.sort(Logex.Declarations.keywords()) ==
             Enum.sort(
               ~w(var var_input var_output var_external) ++
                 ~w(bool sint int dint lint usint uint udint ulint) ++
                 ~w(real lreal) ++
                 ~w(byte word dword lword) ++
                 ~w(ton tof tp rto ctu ctd ctud) ++
                 counters ++
                 ~w(ton_ltime tof_ltime tp_ltime rto_ltime)
             )

    for word <- Map.keys(Logex.FbType.builtins()) do
      assert word in Logex.Declarations.keywords()
      assert Logex.Declarations.reserved(word) in [:type, :mnemonic]
    end
  end

  test "every word that heads a file of another kind has been surveyed (M2-5)" do
    words = Logex.Declarations.kinds() |> MapSet.new()
    unsurveyed = MapSet.difference(words, surveyed_mnemonics())

    # A guard over no words guards nothing: a function block's file is headed by
    # `function_block` (docs/organisation.md §4.3).
    assert "function_block" in words

    assert MapSet.equal?(unsurveyed, MapSet.new()), """
    These words head a file in Logex.Declarations.kinds/0 but have no stanza in
    docs/naming.md:

        #{unsurveyed |> Enum.sort() |> Enum.join(", ")}
    """
  end

  test "every word of a configuration file has been surveyed" do
    words = Logex.Configuration.Text.keywords() |> MapSet.new()
    unsurveyed = MapSet.difference(words, surveyed_mnemonics())

    assert MapSet.equal?(unsurveyed, MapSet.new()), """
    These words of a configuration file are in Logex.Configuration.Text but have no stanza
    in docs/naming.md:

        #{unsurveyed |> Enum.sort() |> Enum.join(", ")}

    Survey a configuration file's word as a mnemonic is surveyed; docs/organisation.md §4.8
    says where it is reserved.
    """
  end

  # The test above reads this list, so the list is pinned: each Milestone 2 item brings
  # its own words with their stanzas (docs/organisation.md §4.10), and a word dropped
  # from the list would drop its survey from the check unseen.
  test "a configuration file's words are those of the items that have landed" do
    # M2-2: `var_global <name> <type> [at <location>]` and `program <instance> <type>`;
    # M2-3: `task <name> interval <ms> priority <p>` and `program <instance> <type> with
    # <task>`; M2-6: `task <name> single <global> [interval <ms>] priority <p>`; M4-2:
    # `task <name> continuous [watchdog <ms>]` and `... priority <p> watchdog <ms>`; M5-3:
    # the seven other integer type words of `var_global <name> <type>`; M5-8: the four
    # bit strings' (decision 156); M5-10: the two reals' (decision 156).
    assert Enum.sort(Logex.Configuration.Text.keywords()) ==
             [
               "at",
               "bool",
               "byte",
               "continuous",
               "dint",
               "dword",
               "int",
               "interval",
               "lint",
               "lreal",
               "lword",
               "priority",
               "program",
               "real",
               "single",
               "sint",
               "task",
               "udint",
               "uint",
               "ulint",
               "usint",
               "var_global",
               "watchdog",
               "with",
               "word"
             ]
  end

  test "the check is one-way: a surveyed but unimplemented mnemonic is allowed" do
    # Surveying an instruction long before building it is the point, so this
    # direction must never fail. Asserted against a synthetic survey rather than
    # the real one: `assert MapSet.subset?(implemented, surveyed)` would restate
    # the test above, and an unsurveyed instruction would then fail twice — the
    # second time under a name pointing at the opposite mistake.
    implemented = Logex.Compiler.instructions() |> Map.keys() |> MapSet.new()
    surveyed_ahead = MapSet.put(implemented, "ton_surveyed_but_not_built")

    assert MapSet.equal?(
             MapSet.difference(implemented, surveyed_ahead),
             MapSet.new()
           ),
           "the guard must ignore stanzas that have no implementation yet"
  end
end
