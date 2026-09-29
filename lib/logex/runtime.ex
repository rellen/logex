defmodule Logex.Runtime do
  @moduledoc """
  Runs a compiled program as instances, one scan at a time. Nothing here reads a clock:
  the host injects time.

  - `instance/1` makes an instance's state, every tag at its initial value.
  - `call/4` is one scan of one instance: copy the inputs in, run every rung, give the
    outputs back. It is what a configuration's scheduler calls for each instance it runs.
  - `put_inputs/3`, `scan/2` and `scan/3` are the task-less sugar: the implicit
    configuration of one instance, whose var_inputs are the host's input image.
  - `restart/3` starts an instance again.

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

  defp run(%Instance{env: env} = state, program, %Scan{now: now}) do
    {_power_flow, env} = Logex.Compiler.evaluate(program, {true, env})
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
end
