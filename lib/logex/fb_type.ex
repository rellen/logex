defmodule Logex.FbType do
  @moduledoc """
  A function block type: the schema every instance of it shares (PLAN.md M1-6, decision
  3). An instance is a tag whose type is the schema itself, `var t1 ton`, and its state
  is a map from each member's name to its value, nested in the env under the instance's
  name, so that `.acc` and `.dn` change together in one scan. Every key is a string.

  Each member has a `role`, after IEC's declaration sections inside a function block:

  - `:input`, a value the block is given (IEC's VAR_INPUT);
  - `:output`, a value the block sets (VAR_OUTPUT);
  - `:internal`, a built-in block's bookkeeping: in the state, but no name in a program
    reaches it.

  Every member but an internal one may be read from outside, anywhere an operand of its
  type may go. `write: true` marks the members logic outside the block may also write: of
  a `ton`, `.pre` and `.acc` (decision 4). `initial` is the member's value in a new
  instance; for a member whose type is itself a `%Logex.FbType{}`, it is a map of that
  nested instance's own initial values, by member name.

  M1-6 has one type, the built-in `ton`. A user function block (M2-5) is this struct too,
  with its var_inputs, var_outputs and vars as members (its vars take a fourth role,
  `:local`, which `public/1` leaves out until M2-5 says who may read one), and a nested
  instance is a member whose type is another `%Logex.FbType{}`.
  """

  defmodule Member do
    @moduledoc "One member of a function block type. See `Logex.FbType`."
    @enforce_keys [:name, :type, :role]
    defstruct [:name, :type, :role, write: false, initial: 0]

    @type t :: %__MODULE__{
            name: String.t(),
            type: :bool | :dint | :clock | Logex.FbType.t(),
            role: :input | :output | :internal,
            write: boolean,
            initial: integer | %{String.t() => integer}
          }
  end

  @enforce_keys [:name, :members]
  defstruct [:name, :members]

  @type t :: %__MODULE__{name: String.t(), members: [Member.t()]}

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
  def initial(%__MODULE__{members: members}, overrides \\ %{}),
    do:
      Map.new(members, fn %Member{name: name} = member ->
        {name, Map.get_lazy(overrides, name, fn -> start(member) end)}
      end)

  defp start(%Member{type: %__MODULE__{} = type, initial: overrides}),
    do: initial(type, overrides)

  defp start(%Member{initial: initial}), do: initial

  @doc "The member a program may name, `{:ok, member}`, or `:error` for none or an internal one."
  def member(%__MODULE__{} = type, name), do: found(Enum.find(public(type), &(&1.name == name)))

  defp found(nil), do: :error
  defp found(member), do: {:ok, member}

  @doc """
  The members a program may name, in the type's order: its inputs and outputs, an
  allowlist, so an internal member is not among them, nor will M2-5's `:local` one be.
  """
  def public(%__MODULE__{members: members}),
    do: Enum.filter(members, &(&1.role in [:input, :output]))

  @doc "The members logic outside the block may write, in the type's order."
  def writable(%__MODULE__{} = type), do: Enum.filter(public(type), & &1.write)
end
