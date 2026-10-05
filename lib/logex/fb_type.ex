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
  whose `blocks` holds the types of the instances it declares at any depth, and whose rungs
  `cal` runs over an instance's map. `of/1` builds the type from it, and is the definition
  of a user type: one is valid exactly when it is what `of/1` gives for its body, its body
  holds each type its instances reach at any depth, and no other, each under its own name
  with no table of its own, every type it holds is what `of/1` gives for its body in turn,
  each body is one a compile gives (`Logex.Compiler.lowered?/1`), and no type holds an
  instance of a type of its own name, at any depth.
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
  Whether `type` has the shape of a user function block type `Logex.compile/2` gives:
  what `of/1` gives for its body; its body's `blocks` the one table of the types it holds
  (decision 53), each user block type its instances reach at any depth, once, under its
  own name, held with no table of its own (`held/1`), and no other; each type in it what
  `of/1` gives for its body in turn; every instance at any depth naming its type,
  `{:block, name}`, and every timer holding the built-in `ton`; each body's rungs, tags
  and warnings what a compile gives over that table (`Logex.Compiler.lowered?/1`); and no
  type in it holding an instance of a type of its own name, at any depth. So a type whose
  body was edited by hand into one no compile gives over its tag table, a rung no text
  lowers to, a tag's line, section or initial value no declaration gives, or a warning its
  rungs do not give, is refused where it is given, and so is a table that lacks a type, holds
  one no instance reaches, or holds one with a table of its own. It never compiles a
  body's source text again, so it does not ask that a body be the one its text gives: a
  rung edited into another that text could say, the text left as it was, a source text or
  file changed, or a key added to a tag, still passes, as a version of its own, which a
  compile that holds the genuine one too refuses (`same?/2` compares source and rungs).
  Total: a hand-built value of any shape is `false`, never an exception. The table holds
  each type once, so each is checked once, however many paths of holders reach it, and the
  check is linear in the types a value holds, but every call checks them all again.
  """
  def user?(type), do: check(type, %{}) != :error

  @doc """
  `user?/1` for one of several types a compile is given (decision 53): `{:ok, checked}`
  where `type` has the shape `user?/1` asks, or `:error`. `checked` is what the calls
  before it in the same compile checked, `%{}` for the first, so a type the table holds
  that an earlier type's table held too, the same term over the same types it names, is
  not checked again: a compile given types that share what they hold checks each shared
  type once, and stays linear in the distinct types. Every type given is still walked,
  and checked at full depth where it holds anything new.
  """
  def check(
        %__MODULE__{name: name, body: %Program{name: name, tags: tags, blocks: blocks}} = type,
        checked
      )
      when is_binary(name) and is_map(tags) and not is_struct(tags) and is_map(blocks) and
             not is_struct(blocks) and is_map(checked),
      do: walked(Logex.Declarations.block_name?(name) and reaches?(type, blocks), type, checked)

  def check(_type, _checked), do: :error

  # Each type of the value, the outermost in its held form and every one its table holds,
  # with the types it names: shaped, then lowered over the table, each unless the same
  # type over the same types was checked already.
  defp walked(false, _type, _checked), do: :error

  defp walked(true, %__MODULE__{body: %Program{blocks: blocks}} = type, checked) do
    fresh =
      for held <- [held(type) | Map.values(blocks)],
          key = {held, Enum.map(named(held), &Map.fetch!(blocks, &1))},
          key not in Map.get(checked, held.name, []),
          do: key

    built(
      Enum.all?(fresh, &shaped?(elem(&1, 0))) and
        Enum.all?(fresh, &Logex.Compiler.lowered?(within(elem(&1, 0), blocks).body)),
      fresh,
      checked
    )
  end

  defp built(false, _fresh, _checked), do: :error

  defp built(true, fresh, checked),
    do:
      {:ok,
       Enum.reduce(fresh, checked, fn {held, _named} = key, checked ->
         Map.update(checked, held.name, [key], &[key | &1])
       end)}

  # Whether the table holds exactly the types `type` reaches through it (decision 53): a
  # walk down from `type`, each type entered once, however many paths reach it, and each
  # one held under its own name with no table of its own. A type reached again on the path
  # down to it would hold itself, and a type no walk reaches makes the table hold one too
  # many.
  defp reaches?(type, blocks),
    do: exact?(reach(named(type), %{type.name => true}, blocks, {:ok, %{}}), blocks)

  defp exact?({:ok, reached}, blocks), do: map_size(reached) == map_size(blocks)
  defp exact?(:error, _blocks), do: false

  # The names of the user block types a body's instances are of, as its tags name them.
  defp named(%__MODULE__{body: %Program{tags: tags}}),
    do: for({_, %Tag{type: {:block, held}}} <- tags, do: held)

  defp reach(_names, _path, _blocks, :error), do: :error
  defp reach([], _path, _blocks, ok), do: ok

  defp reach([name | names], path, blocks, ok),
    do: reach(names, path, blocks, visit(name, path, blocks, ok))

  defp visit(_name, _path, _blocks, :error), do: :error
  defp visit(name, path, _blocks, _ok) when is_map_key(path, name), do: :error
  defp visit(name, _path, _blocks, {:ok, reached} = ok) when is_map_key(reached, name), do: ok

  defp visit(name, path, blocks, {:ok, reached}),
    do: entered(Map.fetch(blocks, name), name, path, {blocks, reached})

  defp entered(
         {:ok,
          %__MODULE__{name: name, body: %Program{name: name, tags: tags, blocks: own}} = type},
         name,
         path,
         {blocks, reached}
       )
       when is_map(tags) and not is_struct(tags) and is_map(own) and map_size(own) == 0,
       do: descend(Logex.Declarations.block_name?(name), type, path, {blocks, reached})

  defp entered(_not_held, _name, _path, _table), do: :error

  defp descend(false, _type, _path, _table), do: :error

  defp descend(true, %__MODULE__{name: name} = type, path, {blocks, reached}),
    do: reach(named(type), Map.put(path, name, true), blocks, {:ok, Map.put(reached, name, true)})

  # One type of the value, the outermost or one its table holds: a tag per name that a
  # declaration gives, each instance of a user block naming its type (declared?/1), each
  # timer the built-in `ton` itself, and the type what `of/1` gives for its body. Every
  # type is shaped before any body is lowered, since a body is lowered over the members of
  # the types it names.
  defp shaped?(%__MODULE__{body: body} = type),
    do:
      Enum.all?(body.tags, &declared?/1) and Enum.all?(body.tags, &timer?/1) and
        of(body) == type

  defp timer?({_name, %Tag{type: %__MODULE__{body: nil} = type}}), do: type == ton()
  defp timer?(_tag), do: true

  # What a compiled body's tag table holds: a tag per name, with a line, or none for a tag
  # declared from Elixir (Logex.Tag.new!/4), a section, and an
  # initial value a declaration line could give, or for a timer the preset the compiler
  # gives it (Logex.Compiler). An instance of a user block names its type, which the
  # outermost type's table holds (reaches?/2). A timer's type is looked at by timer?/1.
  defp declared?({name, %Tag{name: name, line: line, section: section} = tag})
       when ((is_integer(line) and line > 0) or is_nil(line)) and
              section in [:var, :var_input, :var_output],
       do: tag_name?(name) and starts?(tag)

  defp declared?(_entry), do: false

  # A name a declaration line can give in a block's file: no reserved word, no `.`, and not
  # the word that heads the file (Logex.Declarations.check/1 holds the first two).
  defp tag_name?(name),
    do:
      Logex.Declarations.check(%Tag{name: name, type: :bool, section: :var}) == [] and
        String.downcase(name) not in Logex.Declarations.kinds()

  defp starts?(%Tag{type: type, initial: nil}) when type in [:bool, :dint], do: true

  defp starts?(%Tag{type: type, initial: initial, section: section})
       when type in [:bool, :dint] and section != :var_input and is_integer(initial),
       do: Logex.Declarations.fits?(type, initial) and initial >= 0

  defp starts?(%Tag{type: %__MODULE__{body: nil}, initial: nil, section: :var}), do: true
  defp starts?(%Tag{type: {:block, _held}, initial: nil, section: :var}), do: true

  defp starts?(%Tag{
         type: %__MODULE__{body: nil},
         initial: %{"pre" => pre} = preset,
         section: :var
       })
       when map_size(preset) == 1,
       do: Logex.Declarations.preset?(pre)

  defp starts?(_tag), do: false
end
