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
  instance's tag in the body has, and the block's type itself is held once, in the body's
  `blocks`, by name, where `cal` finds it: `type_of/2` gives it. So a type holds each type
  it nests once, however many instances of it its body declares, and a copy of it that
  keeps no sharing (a message, `:erlang.term_to_binary/1`, `:erlang.phash2/1`) stays
  linear in the depth of nesting whatever the width, where a type held in each instance's
  tag would grow as the width to the power of the depth (M2-5; `docs/organisation.md`
  §4.10, "Held types").

  `body` is nil for the built-in `ton`. For a user function block (M2-5) it is the block's
  compiled body, a `%Logex.Program{}` named after the block, whose tags are its members,
  whose `blocks` holds the types of the instances it declares, and whose rungs `cal` runs
  over an instance's map. `of/1` builds the type from it, and is the definition of a user
  type: one is valid exactly when it is what `of/1` gives for its body, its body holds
  each type its tags name, and no other, under that type's name, its body is one a compile
  gives (`Logex.Compiler.lowered?/1`), every type it holds is valid too, any two it holds
  of one name are one version (`same?/2`), and no type holds an instance of its own name.
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
  user block, `{:block, name}`, the block's type, which `type`'s body holds (M2-5).
  """
  def type_of(%__MODULE__{body: %Program{blocks: blocks}}, %Member{type: {:block, name}}),
    do: Map.fetch!(blocks, name)

  def type_of(_type, %Member{type: type}), do: type

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
  and bodies of one name, source text, rungs and tag table, each type they hold one
  version in turn, by its name. Their warnings are no part of a version, nor is the file a
  body was read from: a block compiled from its file stamps each warning with the path,
  under whatever spelling of it, and one compiled from its text has none. A type compared
  with itself, the usual case, is one term, so no walk is made. It is the one definition
  of a version, for a compile's one-version check (`Logex.Compiler`) and for `user?/1`,
  and expects two types a compile could give.
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
  Whether `type` is a user function block type `Logex.compile/2` could have given: what
  `of/1` gives for its body, its body holding each type its tags name, `{:block, name}`,
  once under that name, and no other, every type it holds the built-in `ton` or valid in
  turn, its body's rungs, tags and warnings what a compile gives over that table
  (`Logex.Compiler.lowered?/1`), and no type in it holding an instance of a type of its
  own name, at any depth. So a type whose body was edited by hand, a rung or a warning,
  is refused where it is given, whether or not the text could say what it holds. Two types
  of one name in it must be one version, by `same?/2`, as a compile takes them, and each is
  checked. Total: a hand-built value of any shape is `false`, never an exception. Each type
  is checked once per call, so the check is linear in the types a value holds, but every
  call checks them all again.
  """
  def user?(type), do: valid(type, %{}, %{}) != :error

  # `{:ok, done}`, the names of the user types checked so far, each to the versions of it
  # checked, newest first, or `:error`. A type is checked once, however many instances of
  # it a tree holds, so the check is linear in the types and not in the instances. Another
  # version of a name already checked is checked too, and must be one version with them
  # (same?/2), as a compile takes it; a name on the path down to a type is refused, which
  # would be recursion.
  defp valid(
         %__MODULE__{name: name, body: %Program{name: name, tags: tags, blocks: blocks}} = type,
         path,
         done
       )
       when is_binary(name) and is_map(tags) and not is_struct(tags) and is_map(blocks),
       do: named(Logex.Declarations.block_name?(name), type, path, done)

  defp valid(_type, _path, _done), do: :error

  # A name a block's first line could give: a name, and no reserved word, nor the word that
  # heads a block's file.
  defp named(false, _type, _path, _done), do: :error

  defp named(true, type, path, done),
    do: known(Map.get(done, type.name, []), type, path, done)

  defp known(versions, type, path, done), do: again(type in versions, versions, type, path, done)

  defp again(true, _versions, _type, _path, done), do: {:ok, done}

  defp again(false, versions, type, path, done),
    do: one_of(versions, fresh(is_map_key(path, type.name), type, path, done), type)

  # Checked in full first, so that same?/2 compares two types a compile could give.
  defp one_of(_versions, :error, _type), do: :error
  defp one_of([], ok, _type), do: ok
  defp one_of([version | _], ok, type), do: one(same?(version, type), ok)

  defp one(true, ok), do: ok
  defp one(false, _ok), do: :error

  defp fresh(true, _type, _path, _done), do: :error

  defp fresh(false, %__MODULE__{body: body} = type, path, done),
    do:
      built(
        Enum.all?(body.tags, &declared?/1) and held?(body) and of(body) == type,
        type,
        path,
        done
      )

  defp built(false, _type, _path, _done), do: :error

  # Each type the body holds is checked once, however many of its tags name it.
  defp built(true, %__MODULE__{name: name, body: %Program{} = body} = type, path, done) do
    path = Map.put(path, name, true)

    Enum.map(body.tags, fn {_, tag} -> tag.type end)
    |> Kernel.++(Map.values(body.blocks))
    |> Enum.reduce({:ok, done}, &holds(&1, path, &2))
    |> lowered(type)
    |> add(type)
  end

  # What a compiled body holds of the user block types its instances are of (Logex.Compiler,
  # docs/organisation.md §4.10, "Held types"): each type a tag names, `{:block, name}`, under
  # that name, and no other, so that each is held once, whatever the number of its
  # instances. The built-in `ton` is not among them: each timer's tag holds it, as a
  # program's tags hold every type.
  defp held?(%Program{tags: tags, blocks: blocks}) do
    named = for {_, %Tag{type: {:block, held}}} <- tags, into: %{}, do: {held, true}

    map_size(named) == map_size(blocks) and
      Enum.all?(named, fn {held, _} -> named?(held, Map.get(blocks, held)) end)
  end

  defp named?(name, %__MODULE__{name: name, body: %Program{}}), do: true
  defp named?(_name, _type), do: false

  # The body, once every type it holds is valid, is one a compile gives: its rungs lower
  # to themselves (Logex.Compiler.lowered?/1), so a hand-edited rung is refused here, where
  # the type is given, and never reaches the runtime or an edit.
  defp lowered(:error, _type), do: :error
  defp lowered(ok, type), do: relowered(Logex.Compiler.lowered?(type.body), ok)

  defp relowered(true, ok), do: ok
  defp relowered(false, _ok), do: :error

  defp holds(_type, _path, :error), do: :error
  defp holds(type, _path, ok) when type in [:bool, :dint], do: ok
  defp holds({:block, _held}, _path, ok), do: ok
  defp holds(%__MODULE__{body: nil} = type, _path, ok), do: ton?(type == ton(), ok)
  defp holds(type, path, {:ok, done}), do: valid(type, path, done)

  defp ton?(true, ok), do: ok
  defp ton?(false, _ok), do: :error

  defp add(:error, _type), do: :error
  defp add({:ok, done}, type), do: {:ok, Map.update(done, type.name, [type], &[type | &1])}

  # What a compiled body's tag table holds: a tag per name, with a line, or none for a tag
  # declared from Elixir (Logex.Tag.new!/4), a section, and an
  # initial value a declaration line could give, or for a timer the preset the compiler
  # gives it (Logex.Compiler). An instance of a user block names its type, which the body
  # holds (held?/1). Its type is looked at by holds/3.
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
