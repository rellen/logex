defmodule Logex.Runtime do
  @moduledoc """
  Runs a compiled program as instances, one scan at a time. Nothing here reads a clock:
  the host injects time.

  - `instance/1` makes an instance's state, every tag at its initial value.
  - `call/4` is one scan of one instance: copy the inputs in, run every rung, give the
    outputs back. It is what a configuration's scheduler calls for each instance it runs.
  - `put_inputs/3`, `scan/2` and `scan/3` are the task-less sugar: the implicit
    configuration of one instance, whose var_inputs are the host's input image.
  - `restart/3` starts an instance again, keeping its input image and its clock.

  **The host contract.** A mistake by the host raises `ArgumentError` (a host bug, not a
  PLC event, `docs/organisation.md` §4.6); a mistake in the source is a diagnostic from
  `Logex.compile/2`. Only a declared `var_input` may be set, by its name as a string, with
  a value that fits its type exactly: a bool is 0 or 1, a dint an integer of 32 bits. Every
  input problem in one call comes in one raise, a line each, in key order. Inputs merge
  into the instance, so a host sends only what changed. Outputs are every `var_output`.
  Time never goes backwards for an instance, and a `%Logex.Scan{}` must agree with it about
  `first`. A state is matched to its program by name. A `%Logex.Program{}` or
  `%Logex.Instance{}` built or edited by hand is outside this contract.
  """

  alias Logex.{Declarations, Instance, Program, Scan, Tag}

  @doc "A new instance of `program`: every tag at its initial value, before its first scan."
  def instance(program) do
    program!(program)
    %Instance{type: program.name, env: Program.initial_env(program), now: 0, first: true}
  end

  @doc """
  One scan of one instance, at `scan.now`: `inputs` are copied in, every rung runs, and
  `{outputs, state}` comes back, the outputs being every `var_output`.
  """
  def call(program, state, inputs, scan) do
    program!(program)
    state = state!(state, program)
    scan = scan!(scan, state)
    state |> merge!(program, inputs) |> run(program, scan)
  end

  @doc """
  Sets inputs in an instance's input image, checked as `call/4` checks them, for the next
  `scan/2` or `scan/3`.
  """
  def put_inputs(program, state, inputs) do
    program!(program)
    state!(state, program) |> merge!(program, inputs)
  end

  @doc """
  One scan of the implicit configuration: `elapsed_ms` after the last one (none for
  `scan/2`), with the inputs `put_inputs/3` set.
  """
  def scan(program, state, elapsed_ms \\ 0) do
    program!(program)
    %Instance{now: now, first: first} = state = state!(state, program)
    call(program, state, %{}, %Scan{now: now + elapsed!(elapsed_ms), first: first})
  end

  @doc """
  Starts an instance again: every tag back at its initial value except the `var_input`s,
  the next scan marked first, and the clock kept, since time never goes backwards.

  The `var_input`s are the host's input image, not the program's state: IEC leaves inputs
  "initialized in an implementation-dependent manner" (Ed 2 §2.4.2 rule 4), and keeping
  them is what makes `scan/2` agree with a configuration, whose copy-in refreshes them
  every scan. `:warm` is `:cold` until `retain` exists: nothing is retained yet.
  """
  def restart(program, state, mode) do
    program!(program)
    %Instance{env: env} = state = state!(state, program)
    mode!(mode)
    %{state | env: Map.merge(Program.initial_env(program), inputs(program, env)), first: true}
  end

  defp inputs(%Program{tags: tags}, env),
    do: Map.take(env, for({name, %Tag{section: :var_input}} <- tags, do: name))

  defp mode!(mode) when mode in [:cold, :warm], do: :ok

  defp mode!(mode),
    do: raise(ArgumentError, "restart takes :cold or :warm, got: #{inspect(mode)}")

  defp run(%Instance{env: env} = state, %Program{rungs: rungs} = program, %Scan{now: now} = scan) do
    env = Enum.reduce(rungs, env, &rung(&1, &2, scan))
    {outputs(program, env), %{state | env: env, now: now, first: false}}
  end

  # A var_output a hand-built env leaves out reads 0, as a contact reads it (M1-4).
  defp outputs(%Program{tags: tags}, env),
    do:
      for(
        {name, %Tag{section: :var_output}} <- tags,
        into: %{},
        do: {name, Map.get(env, name, 0)}
      )

  # The arguments, checked in order: program, state, the state's owner, scan, inputs.
  defp program!(%Program{tags: tags, rungs: rungs}) when is_map(tags) and is_list(rungs), do: :ok

  defp program!(other),
    do:
      raise(
        ArgumentError,
        "expected a %Logex.Program{} from Logex.compile/2, got: #{inspect(other)}"
      )

  defp state!(%Instance{type: type}, _program) when not is_binary(type) and type != nil,
    do: raise(ArgumentError, "state.type must be a program name, got: #{inspect(type)}")

  defp state!(%Instance{env: env}, _program) when not is_map(env) or is_struct(env),
    do:
      raise(ArgumentError, "state.env must be a map of tag names to values, got: #{inspect(env)}")

  defp state!(%Instance{now: now}, _program) when not is_integer(now) or now < 0,
    do: raise(ArgumentError, "state.now must be #{ms()}, got: #{inspect(now)}")

  defp state!(%Instance{first: first}, _program) when not is_boolean(first),
    do: raise(ArgumentError, "state.first must be true or false, got: #{inspect(first)}")

  defp state!(%Instance{type: name} = state, %Program{name: name}), do: state

  defp state!(%Instance{type: type}, %Program{name: name}),
    do: raise(ArgumentError, "this state is an instance of #{named(type)}, not of #{named(name)}")

  defp state!(other, _program),
    do:
      raise(
        ArgumentError,
        "expected a %Logex.Instance{} from Logex.Runtime.instance/1, got: #{inspect(other)}"
      )

  defp named(nil), do: "an unnamed program"
  defp named(name), do: "`#{name}`"

  defp scan!(%Scan{now: now}, _state) when not is_integer(now) or now < 0,
    do: raise(ArgumentError, "scan.now must be #{ms()}, got: #{inspect(now)}")

  defp scan!(%Scan{first: first}, _state) when not is_boolean(first),
    do: raise(ArgumentError, "scan.first must be true or false, got: #{inspect(first)}")

  defp scan!(%Scan{now: now}, %Instance{now: last}) when now < last,
    do:
      raise(
        ArgumentError,
        "time went backwards: this scan is at #{now} ms, " <>
          "but the instance was last scanned at #{last} ms"
      )

  defp scan!(%Scan{first: first} = scan, %Instance{first: first}), do: scan

  defp scan!(%Scan{first: false}, _state),
    do:
      raise(
        ArgumentError,
        "scan.first is false, but this is the instance's first scan since it started or restarted"
      )

  defp scan!(%Scan{first: true}, _state),
    do:
      raise(
        ArgumentError,
        "scan.first is true, but the instance has been scanned since it started or restarted"
      )

  defp scan!(other, _state),
    do: raise(ArgumentError, "expected a %Logex.Scan{}, got: #{inspect(other)}")

  defp elapsed!(ms) when is_integer(ms) and ms >= 0, do: ms

  defp elapsed!(other),
    do: raise(ArgumentError, "elapsed_ms must be #{ms()}, got: #{inspect(other)}")

  defp ms, do: "a non-negative integer of milliseconds"

  # Every input problem, a line each in key order, or the inputs merged into the state.
  defp merge!(%Instance{env: env} = state, %Program{tags: tags}, inputs)
       when is_map(inputs) and not is_struct(inputs) do
    problems =
      for {key, value} <- Enum.sort(inputs), problem = problem(key, value, tags), do: problem

    merged(problems, state, env, inputs)
  end

  defp merge!(_state, _program, inputs),
    do:
      raise(
        ArgumentError,
        ~s|inputs must be a map of var_input names to values, as in %{"start" => 1}, | <>
          "got: #{inspect(inputs)}"
      )

  defp merged([], state, env, inputs), do: %{state | env: Map.merge(env, inputs)}

  defp merged(problems, _state, _env, _inputs),
    do: raise(ArgumentError, Enum.join(problems, "\n"))

  defp problem(key, _value, _tags) when not is_binary(key),
    do:
      "input #{inspect(key)} is not a tag name: inputs are keyed by tag name, as a string, " <>
        ~s|as in %{"start" => 1}|

  defp problem(key, value, tags), do: declared(Map.fetch(tags, key), key, value, tags)

  defp declared(:error, key, _value, tags) do
    inputs = for {name, %Tag{section: :var_input}} <- tags, do: name

    "input #{label(key)} is not declared" <>
      hint(Declarations.suggest(key, inputs), Enum.sort(inputs))
  end

  defp declared({:ok, %Tag{section: :var_input} = tag}, _key, value, _tags), do: fit(tag, value)

  defp declared({:ok, %Tag{} = tag}, key, _value, _tags),
    do:
      "input #{label(key)} is a #{tag.section}#{on_line(tag)}, not a var_input: " <>
        "only a var_input is set from outside"

  defp hint("", []), do: ": this program has no var_input"
  defp hint("", inputs), do: ": the var_inputs are " <> Enum.map_join(inputs, ", ", &"`#{&1}`")
  defp hint(suggestion, _inputs), do: suggestion

  defp fit(%Tag{type: :dint} = tag, value) when not is_integer(value),
    do: "input `#{tag.name}` is a dint: its value must be an integer, found #{inspect(value)}"

  defp fit(%Tag{type: type} = tag, value), do: fits(Declarations.fits?(type, value), tag, value)

  defp fits(true, _tag, _value), do: nil

  defp fits(false, %Tag{type: :bool} = tag, value),
    do: "input `#{tag.name}` is a bool: only 0 or 1 fit, found #{inspect(value)}"

  defp fits(false, %Tag{type: :dint} = tag, value),
    do: "input `#{tag.name}` is a dint: #{value} does not fit in 32 bits"

  defp label(key), do: labelled(Declarations.name?(key), key)

  defp labelled(true, key), do: "`#{key}`"
  defp labelled(false, key), do: inspect(key)

  defp on_line(%Tag{line: nil}), do: ""
  defp on_line(%Tag{line: line}), do: " (declared on line #{line})"

  # The evaluator (B5): private, so no logic runs past the checks above. Each rung starts
  # with power, and `{power_flow, env}` threads through its elements in order. The scan is
  # read-only and the same for every instruction of every rung of one call (M1-6).
  defp rung({:rung, elements}, env, scan) do
    {_power_flow, env} = series(elements, {true, env}, scan)
    env
  end

  defp series(elements, acc, scan), do: Enum.reduce(elements, acc, &element(&1, &2, scan))

  # Every leg runs, from the power flowing into the group, with the env threading through
  # the legs in order, so a leg sees what an earlier one wrote. The group passes power if
  # any leg does: branches do not short-circuit.
  defp element({:branches, legs}, {power, env}, scan) do
    {powers, env} =
      Enum.map_reduce(legs, env, fn leg, env -> series(leg, {power, env}, scan) end)

    {Enum.any?(powers), env}
  end

  defp element(instruction, acc, scan), do: evaluate(instruction, acc, scan)

  # One instruction: `(instruction, {power_flow, env}, %Scan{})` to `{power_flow, env}`, a
  # clause for an energised rung and one for a de-energised one (CLAUDE.md).
  defp evaluate({:xic, _, [{:name, _, arg}]}, {true, env}, _scan) do
    {bit(env, arg), env}
  end

  defp evaluate({:xic, _, _}, {false, env}, _scan) do
    {false, env}
  end

  defp evaluate({:xio, _, [{:name, _, arg}]}, {true, env}, _scan) do
    {not bit(env, arg), env}
  end

  defp evaluate({:xio, _, _}, {false, env}, _scan) do
    {false, env}
  end

  defp evaluate({:ote, _, [{:name, _, arg}]}, {true, env}, _scan) do
    {true, Map.put(env, arg, 1)}
  end

  defp evaluate({:ote, _, [{:name, _, arg}]}, {false, env}, _scan) do
    {false, Map.put(env, arg, 0)}
  end

  defp evaluate({:otl, _, [{:name, _, arg}]}, {true, env}, _scan) do
    {true, Map.put(env, arg, 1)}
  end

  defp evaluate({:otl, _, _}, {false, env}, _scan) do
    {false, env}
  end

  defp evaluate({:otu, _, [{:name, _, arg}]}, {true, env}, _scan) do
    {true, Map.put(env, arg, 0)}
  end

  defp evaluate({:otu, _, _}, {false, env}, _scan) do
    {false, env}
  end

  defp evaluate({:move, _, [arg1, {:name, _, arg2}]}, {true, env}, _scan) do
    {true, Map.put(env, arg2, get_arg(env, arg1))}
  end

  defp evaluate({:move, _, _}, {false, env}, _scan) do
    {false, env}
  end

  # The one-shot on the rung condition (docs/naming.md, `ons`): power for the one scan in
  # which the power reaching it rises. The storage bit holds the power it received last
  # scan, read as a contact reads a bit. On an instance's first scan it passes none,
  # whatever the storage bit holds: the conventional ONS's "set to true to prevent an
  # invalid trigger during the first scan", read from the scan rather than set by a
  # prescan (PLAN.md M1-6, decision 3).
  defp evaluate({:ons, _, [{:name, _, storage}]}, {true, env}, %Scan{first: first}) do
    {not first and not bit(env, storage), Map.put(env, storage, 1)}
  end

  defp evaluate({:ons, _, [{:name, _, storage}]}, {false, env}, _scan) do
    {false, Map.put(env, storage, 0)}
  end

  defp get_arg(_env, {:int_lit, _, val}), do: val
  defp get_arg(env, {:name, _, name}), do: Map.get(env, name, 0)

  # M1-4: `xic` reads this and `xio` its negation, so the two are complementary by
  # construction, whatever the env holds. The compiler lets only a bool reach a contact,
  # but an env the host builds by hand can hold a 5, a 0.0, a `false`, a nil, or leave a
  # tag out. A number is read by value, nonzero closed (PLAN.md §5), and a boolean as
  # itself; nil and a missing tag are open; anything else is closed. A missing tag reads
  # as 0 in get_arg/2 too, so `move` copies a 0 rather than a nil.
  defp bit(env, name), do: closed?(Map.get(env, name))

  defp closed?(value) when is_number(value), do: value != 0
  defp closed?(value) when value in [nil, false], do: false
  defp closed?(_value), do: true
end
