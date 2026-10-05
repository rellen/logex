defmodule Logex.FbType do
  @moduledoc """
  A function block type: the schema every instance of it shares (PLAN.md M1-6, decision
  3). An instance is a tag whose type is the schema itself, `var t1 ton` or `var s1 seal`,
  and its state is a map from each member's name to its value, nested in the env under the
  instance's name, so that `.acc` and `.dn` change together in one scan. Every key is a
  string.

  Each member has a `role`, after IEC's declaration sections inside a function block:

  - `:input`, a value the block is given (IEC's VAR_INPUT);
  - `:output`, a value the block sets (VAR_OUTPUT);
  - `:local`, a user block's own `var`, an instance it holds included (IEC's VAR): in the
    state, and named only inside the block's own body (M2-5);
  - `:internal`, a built-in block's bookkeeping: in the state, but no name in a program
    reaches it.

  Every input and output may be read from outside, anywhere an operand of its type may go.
  `write: true` marks the members logic outside the block may also write: of a `ton`,
  `.pre` and `.acc` (decision 9); of a user block, none (M2-5). `initial` is the member's
  value in a new instance; for a member whose type is itself a `%Logex.FbType{}`, it is a
  map of that nested instance's own initial values, by member name.

  A member holding an instance of a user block has the type `{:block, name}`, as the
  instance's tag in the body has, and the block's type itself is held once per outermost
  type (decision 53; `docs/organisation.md` §4.10, "Held types"): the type a compile gives
  holds, in its body's `blocks`, every user block type its instances are of at any depth,
  by name, each held with no table of its own (`held/1`), and every instance at any depth
  names its type, so that a `cal` finds it there and `type_of/2` gives it. A program holds
  its types so too (`Logex.Program`). A copy of a type that keeps no sharing (a message,
  `:erlang.term_to_binary/1`, `:erlang.phash2/1`) then grows with the number of distinct
  types it holds, whatever the shape: a type reached through two holders at every level,
  as when each level has two types and each holds both of the level below, is written out
  once, as one reached through one is. An instance's state still grows with the instances
  it nests, at any depth.

  `body` is nil for the built-in `ton`. For a user function block (M2-5) it is the block's
  compiled body, a `%Logex.Program{}` named after the block, whose tags are its members,
  whose `blocks` holds the types of the instances it declares at any depth, whose rungs
  `cal` runs over an instance's map, and whose `source` is the block's text. `of/1` builds
  the type from it. A user type is valid exactly when it is the one its text compiles to
  (decision 54; `user?/1`): `of/1` of the body `Logex.compile/2` gives for its `source`, a
  block of its name, the file it was read from aside, and every type its table holds the
  one its own text compiles to in turn, each under its own name, with no table of its own,
  and none holding an instance of a type of its own name, at any depth.
  """

  alias Logex.{Program, Tag}

  defmodule Member do
    @moduledoc "One member of a function block type. See `Logex.FbType`."
    @enforce_keys [:name, :type, :role]
    defstruct [:name, :type, :role, write: false, initial: 0]

    @type t :: %__MODULE__{
            name: String.t(),
            type: :bool | :dint | :clock | Logex.FbType.t() | {:block, String.t()},
            role: :input | :output | :local | :internal,
            write: boolean,
            initial: integer | %{String.t() => integer}
          }
  end

  @enforce_keys [:name, :members]
  defstruct [:name, :members, body: nil]

  @type t :: %__MODULE__{
          name: String.t(),
          members: [Member.t()],
          body: Logex.Program.t() | nil
        }

  # The on-delay timer (docs/naming.md, `ton`): the conventional TIMER's members,
  # lowercased. `.pre` plays IEC's PT, `.acc` its ET and `.dn` its Q, by an inference
  # docs/organisation.md §8 records; `.tt` and `.en` are the conventional set's. `last` is
  # the time its `ton` last ran, energised or not (docs/organisation.md §4.6): a `:clock`,
  # an unbounded count of milliseconds, which no declaration can give a tag.
  @doc "The built-in on-delay timer, as `var t1 ton` declares it."
  def ton,
    do: %__MODULE__{
      name: "ton",
      members: [
        %Member{name: "pre", type: :dint, role: :input, write: true},
        %Member{name: "acc", type: :dint, role: :output, write: true},
        %Member{name: "dn", type: :bool, role: :output},
        %Member{name: "tt", type: :bool, role: :output},
        %Member{name: "en", type: :bool, role: :output},
        %Member{name: "last", type: :clock, role: :internal}
      ]
    }

  @doc "The built-in function block types, by their lowercase type word."
  def builtins, do: %{"ton" => ton()}

  @doc "The built-in type a word names, in any case, or nil."
  def builtin(word) when is_binary(word), do: Map.get(builtins(), String.downcase(word))

  @doc """
  A new instance's state: every member at its initial value, a nested instance at its
  own, and each member named in `overrides` at the value given there instead.
  """
  def initial(%__MODULE__{members: members} = type, overrides \\ %{}),
    do:
      Map.new(members, fn %Member{name: name} = member ->
        {name, Map.get_lazy(overrides, name, fn -> start(member, type) end)}
      end)

  defp start(%Member{type: %__MODULE__{} = type, initial: overrides}, _owner),
    do: initial(type, overrides)

  defp start(%Member{type: {:block, _name}, initial: overrides} = member, owner),
    do: initial(type_of(owner, member), overrides)

  defp start(%Member{initial: initial}, _owner), do: initial

  @doc """
  The type of `member`, a member of `type`: its own, or for one holding an instance of a
  user block, `{:block, name}`, the block's type, which `type`'s body holds (M2-5), as it
  reads inside `type` (`within/2`), so that the types it holds are found in turn.
  """
  def type_of(%__MODULE__{body: %Program{blocks: blocks}}, %Member{type: {:block, name}}),
    do: within(Map.fetch!(blocks, name), blocks)

  def type_of(_type, %Member{type: type}), do: type

  @doc """
  A type as a table holds it (decision 53): its body with no table of its own, `blocks`
  empty, since the outermost type or program that holds it holds every type below it
  once. A type that holds no instance of a user block is its own held form.
  """
  def held(%__MODULE__{body: %Program{} = body} = type), do: %{type | body: %{body | blocks: %{}}}

  @doc """
  A held type as it reads inside the outermost type or program whose table is `blocks`:
  its body given that table, so that each type its instances name is found there, at any
  depth (decision 53). It builds no copy of the table, which every type read so shares.
  """
  def within(%__MODULE__{body: %Program{} = body} = type, blocks),
    do: %{type | body: %{body | blocks: blocks}}

  @doc "The member a program may name, `{:ok, member}`, or `:error` for none or a hidden one."
  def member(%__MODULE__{} = type, name), do: found(Enum.find(public(type), &(&1.name == name)))

  defp found(nil), do: :error
  defp found(member), do: {:ok, member}

  @doc """
  The members a program may name, in the type's order: its inputs and outputs, an
  allowlist, so neither an internal member nor a user block's own `var` is among them.
  """
  def public(%__MODULE__{members: members}),
    do: Enum.filter(members, &(&1.role in [:input, :output]))

  @doc "The members logic outside the block may write, in the type's order."
  def writable(%__MODULE__{} = type), do: Enum.filter(public(type), & &1.write)

  @doc """
  A user function block's type, from its compiled body (M2-5): the body's tags become its
  members, a `var_input` an `:input`, a `var_output` an `:output` and a `var` a `:local`,
  each of its tag's type, so a member holding an instance of a user block names it,
  `{:block, name}`, as its tag does. Their order is `cal`'s positional order: the tags
  declared from Elixir first, which have no line, by name, then the source's in the order
  they are declared. No member of a user block is written from outside it.
  """
  def of(%Program{name: name, tags: tags} = body),
    do: %__MODULE__{
      name: name,
      members: tags |> Map.values() |> Enum.sort_by(&order/1) |> Enum.map(&member_of/1),
      body: body
    }

  defp order(%Tag{line: nil, name: name}), do: {0, name}
  defp order(%Tag{line: line}), do: {1, line}

  defp member_of(%Tag{name: name, type: type, section: section, initial: initial}),
    do: %Member{name: name, type: type, role: role(section), initial: starts(type, initial)}

  defp role(:var_input), do: :input
  defp role(:var_output), do: :output
  defp role(:var), do: :local

  defp starts(%__MODULE__{}, nil), do: %{}
  defp starts({:block, _name}, nil), do: %{}
  defp starts(_type, nil), do: 0
  defp starts(_type, initial), do: initial

  @doc """
  What `cal` takes for an instance of a user block (M2-5): the instance, then each
  var_input as a value and each var_output as a tag it writes, in declaration order, as
  IL's non-formal CAL (docs/organisation.md §4.3). Each slot is `{access, type}`, as a
  mnemonic's are in `Logex.Compiler.instructions/0`, with the formal it fills.
  """
  def signature(%__MODULE__{name: name, members: members}),
    do: [
      {{:instance, name}, nil}
      | for(%Member{role: :input} = m <- members, do: {{:value, m.type}, m}) ++
          for(%Member{role: :output} = m <- members, do: {{:write, m.type}, m})
    ]

  @doc """
  Whether two user function block types are one version of one block, as a compile takes
  them (M2-5; `docs/organisation.md` §4.10, "Types given"): one name and the same members,
  and bodies of one name, source text, rungs and tag table, each type the first holds one
  version with the type of its name the second holds. Their warnings are no part of a
  version, nor is the file a body was read from: a block compiled from its file stamps each
  warning with the path, under whatever spelling of it, and one compiled from its text has
  none. A type compared with itself, the usual case, is one term, so no walk is made. Two
  held types (`held/1`) hold no table, so comparing them compares their own bodies: a
  compile takes the types of each name across the tables it is given one name at a time
  (decision 53). It is the one definition of a version, for a compile's one-version check
  (`Logex.Compiler`), and expects two types a compile could give, or their held forms.
  """
  def same?(type, type), do: true

  def same?(
        %__MODULE__{name: name, members: members, body: %Program{} = one},
        %__MODULE__{name: name, members: members, body: %Program{} = other}
      ),
      do:
        one.name == other.name and one.source == other.source and one.rungs == other.rungs and
          one.tags == other.tags and
          Enum.all?(one.blocks, fn {held, type} -> same?(type, Map.get(other.blocks, held)) end)

  def same?(_one, _other), do: false

  @doc """
  Whether `type` is a user function block type `Logex.compile/2` gives (decision 54): one
  whose body is the one its own source text compiles to. Each type the value holds, the
  outermost and every type in its body's `blocks`, is compiled again from its body's
  `source`, as a block of its name, over the types its instances name, as the table holds
  them (`Logex.Compiler.recompiled/3`), and must be exactly what that compile gives: its
  members, and its body's name, rungs, tag table and warnings, with the file its body
  keeps, which no text gives: nil, or a path to a file named after the block, as
  `Logex.compile_file/1` reads one, which stamps each warning with it. The table must be
  the one a compile holds (decision 53): each user block type the instances reach at any
  depth, once, under the name they give it, and no other, none reaching itself. Each is
  compiled again before any type that names it, since a body is lowered over the members
  of the types it names.

  So a type edited by hand is refused where it is given, whether or not text could say
  what it holds: a rung edited into another that text could say, the text left as it
  was; a tag, a member or a warning edited, added or dropped; a source text edited, the
  body left as it was; a file that is no such path; or a table that lacks a type, holds
  one no instance reaches, or holds one with a table of its own. A type with no source text,
  which only `Logex.Compiler.instructionize/3` gives, has none to compile again, and is
  refused too. Total: a hand-built value of any shape is `false`, never an exception. The
  table holds each type once, so each is compiled again once a call, however many paths
  of holders reach it, and the check is linear in the source text of the types a value
  holds, but every call compiles them all again (`check/2`).
  """
  def user?(type), do: check(type, %{}) != :error

  @doc """
  `user?/1` for one of several types a compile is given, or holds through its tags
  declared from Elixir (decisions 53 and 54): `{:ok, checked}` where `type` is one
  `user?/1` takes, or `:error`. `checked` is what the calls before it in the same compile
  checked, `%{}` for the first: each type compiled again, under every version of the types
  it names that it was compiled again over. So a type the table holds that an earlier
  type's table held too, the same term over the same types it names, is not compiled
  again: a compile given types, or tags, that share what they hold compiles each shared
  type's source once, and stays linear in the distinct types (`Logex.Declarations.split/4`
  shares it with the tags). Every type given is still walked, and compiled again at full
  depth where it holds anything new.
  """
  def check(%__MODULE__{body: %Program{tags: tags, blocks: blocks}} = type, checked)
      when is_map(tags) and not is_struct(tags) and is_map(blocks) and is_map(checked),
      do: walked(reaches(type, blocks), type, checked)

  def check(_type, _checked), do: :error

  # Each type of the value, every one its table holds, a type before any that names it,
  # then the outermost in its held form, each with the types it names: compiled again over
  # them, unless the same type over the same types was checked already.
  defp walked(:error, _type, _checked), do: :error

  defp walked({:ok, order}, %__MODULE__{body: %Program{blocks: blocks}} = type, checked) do
    fresh =
      for held <- Enum.map(order, &Map.fetch!(blocks, &1)) ++ [held(type)],
          key = {held, Enum.map(named(held), &Map.fetch!(blocks, &1))},
          key not in Map.get(checked, held.name, []),
          do: key

    built(Enum.all?(fresh, &compiles?(&1, blocks)), fresh, checked)
  end

  defp built(false, _fresh, _checked), do: :error

  defp built(true, fresh, checked),
    do:
      {:ok,
       Enum.reduce(fresh, checked, fn {held, _named} = key, checked ->
         Map.update(checked, held.name, [key], &[key | &1])
       end)}

  # Decision 54: a held type is the one its source text compiles to over the types it
  # names, read inside the table, its body keeping the file it was read from: none, or a
  # path to a file named after the block, as Logex.compile_file/1 names one.
  defp compiles?({%__MODULE__{name: name, body: %Program{source: source}} = held, named}, blocks),
    do:
      recompiled(
        Logex.Compiler.recompiled(source, name, Map.new(named, &{&1.name, within(&1, blocks)})),
        held
      )

  defp recompiled(
         {:ok, body},
         %__MODULE__{name: name, body: %Program{source: source, file: file}} = held
       ),
       do: read_from?(file, name) and of(%{filed(body, file) | source: source}) == held

  defp recompiled(:error, _held), do: false

  defp read_from?(nil, _name), do: true
  defp read_from?(file, name) when is_binary(file), do: Path.rootname(Path.basename(file)) == name
  defp read_from?(_file, _name), do: false

  defp filed(%Program{warnings: warnings} = body, file),
    do: %{body | file: file, warnings: Enum.map(warnings, &%{&1 | file: file})}

  # The names in the table, a type before every type that names it, where the table holds
  # exactly the types `type` reaches through it (decision 53): a walk down from `type`,
  # each type entered once, however many paths reach it. A type reached again on the path
  # down to it would hold itself, and a type no walk reaches makes the table hold one too
  # many.
  defp reaches(type, blocks),
    do: exact(reach(named(type), %{type.name => true}, blocks, {:ok, %{}, []}), blocks)

  defp exact({:ok, reached, order}, blocks) when map_size(reached) == map_size(blocks),
    do: {:ok, Enum.reverse(order)}

  defp exact(_reached, _blocks), do: :error

  # The names of the user block types a body's instances are of, as its tags name them.
  defp named(%__MODULE__{body: %Program{tags: tags}}),
    do: for({_, %Tag{type: {:block, held}}} <- tags, do: held)

  defp reach(_names, _path, _blocks, :error), do: :error
  defp reach([], _path, _blocks, ok), do: ok

  defp reach([name | names], path, blocks, ok),
    do: reach(names, path, blocks, visit(name, path, blocks, ok))

  defp visit(_name, _path, _blocks, :error), do: :error
  defp visit(name, path, _blocks, _ok) when is_map_key(path, name), do: :error

  defp visit(name, _path, _blocks, {:ok, reached, _order} = ok) when is_map_key(reached, name),
    do: ok

  defp visit(name, path, blocks, {:ok, reached, order}),
    do: entered(Map.fetch(blocks, name), name, path, {blocks, reached, order})

  defp entered({:ok, %__MODULE__{body: %Program{tags: tags}} = type}, name, path, table)
       when is_map(tags) and not is_struct(tags),
       do: descend(type, name, path, table)

  defp entered(_not_held, _name, _path, _table), do: :error

  defp descend(type, name, path, {blocks, reached, order}),
    do:
      finished(
        reach(
          named(type),
          Map.put(path, name, true),
          blocks,
          {:ok, Map.put(reached, name, true), order}
        ),
        name
      )

  defp finished({:ok, reached, order}, name), do: {:ok, reached, [name | order]}
  defp finished(:error, _name), do: :error
end
