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
  `first`. A state is matched to its program by name, and its values are not checked each
  scan: an instance kept across a recompile of the same name keeps them until `restart/3`.
  A tag the recompile adds reads 0 until then, so an added timer starts at a `.pre` of 0,
  and a tag whose type it changes keeps its old value, a timer's map reaching the outputs
  and the contacts. `restart/3` starts every tag again but the `var_input`s whose values
  fit their types. A `%Logex.Program{}` or `%Logex.Instance{}` built or edited by hand is
  outside this contract.
  """

  alias Logex.{Declarations, FbType, Instance, Program, Scan, Tag}

  @comparisons [:eq, :ne, :lt, :gt, :le, :ge]

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
  Starts an instance again: every tag back at its initial value except the `var_input`s
  whose values fit their types, the next scan marked first, and the clock kept, since time
  never goes backwards.

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

  # A var_input whose value does not fit its type, as after a recompile of the same name
  # that changed the type, starts again with the rest.
  defp inputs(%Program{tags: tags}, env),
    do:
      for(
        {name, %Tag{section: :var_input, type: type}} <- tags,
        {:ok, value} <- [Map.fetch(env, name)],
        Declarations.fits?(type, value),
        into: %{},
        do: {name, value}
      )

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
    [head | path] = String.split(key, ".")
    undeclared(Map.get(tags, head), path, key, tags)
  end

  defp declared({:ok, %Tag{section: :var_input} = tag}, _key, value, _tags), do: fit(tag, value)

  defp declared({:ok, %Tag{} = tag}, key, _value, _tags),
    do:
      "input #{label(key)} is a #{tag.section}#{on_line(tag)}, not a var_input: " <>
        "only a var_input is set from outside"

  # M1-6: the host never sets anything inside an instance. A key naming a declared tag was
  # found before this, so here a key found by its first part has a `.`, and it is called a
  # member only when the compiler would take it for one: `t1.dn`, never `t1.last`,
  # `t1.zz` or `t1.dn.x`, which reach into `t1` all the same.
  defp undeclared(%Tag{type: %FbType{} = type} = tag, path, key, _tags),
    do:
      "input #{label(key)} #{reaches(member(type, path))} `#{tag.name}`, a #{type.name}: " <>
        "only a var_input is set from outside"

  defp undeclared(_tag, _path, key, tags) do
    inputs = for {name, %Tag{section: :var_input}} <- tags, do: name

    "input #{label(key)} is not declared" <>
      hint(Declarations.suggest(key, inputs), Enum.sort(inputs))
  end

  defp member(type, [name]), do: FbType.member(type, name)
  defp member(_type, _deeper), do: :error

  defp reaches({:ok, _member}), do: "names a member of"
  defp reaches(:error), do: "reaches into"

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

  # A key is quoted as a name when every `.` part of it is one, so `t1.dn` reads as written.
  defp label(key), do: labelled(Enum.all?(String.split(key, "."), &Declarations.name?/1), key)

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
  # clause for an energised rung and one for a de-energised one (CLAUDE.md). An operand is
  # `{:name, _, tag}`, `{:int_lit, _, value}` or, since M1-6, `{:member, _, path}`; read/2
  # and write/3 take all three, so no instruction clause cares which it got.
  defp evaluate({:xic, _, [operand]}, {true, env}, _scan) do
    {closed?(read(env, operand)), env}
  end

  defp evaluate({:xic, _, _}, {false, env}, _scan) do
    {false, env}
  end

  defp evaluate({:xio, _, [operand]}, {true, env}, _scan) do
    {not closed?(read(env, operand)), env}
  end

  defp evaluate({:xio, _, _}, {false, env}, _scan) do
    {false, env}
  end

  defp evaluate({:ote, _, [operand]}, {true, env}, _scan) do
    {true, write(env, operand, 1)}
  end

  defp evaluate({:ote, _, [operand]}, {false, env}, _scan) do
    {false, write(env, operand, 0)}
  end

  defp evaluate({:otl, _, [operand]}, {true, env}, _scan) do
    {true, write(env, operand, 1)}
  end

  defp evaluate({:otl, _, _}, {false, env}, _scan) do
    {false, env}
  end

  defp evaluate({:otu, _, [operand]}, {true, env}, _scan) do
    {true, write(env, operand, 0)}
  end

  defp evaluate({:otu, _, _}, {false, env}, _scan) do
    {false, env}
  end

  defp evaluate({:move, _, [source, destination]}, {true, env}, _scan) do
    {true, write(env, destination, read(env, source))}
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
  defp evaluate({:ons, _, [storage]}, {true, env}, %Scan{first: first}) do
    {not first and not closed?(read(env, storage)), write(env, storage, 1)}
  end

  defp evaluate({:ons, _, [storage]}, {false, env}, _scan) do
    {false, write(env, storage, 0)}
  end

  # The six comparisons (docs/naming.md, `eq` to `ge`) are input instructions, as a contact
  # is: energised, power is the comparison of the first operand with the second, `lt a b`
  # reading a < b; de-energised, no power. Neither writes anything.
  defp evaluate({op, _, [a, b]}, {true, env}, _scan) when op in @comparisons do
    {compare(op, read(env, a), read(env, b)), env}
  end

  defp evaluate({op, _, _}, {false, env}, _scan) when op in @comparisons do
    {false, env}
  end

  # The on-delay timer (docs/naming.md, `ton`; docs/organisation.md §4.6). Rung power is
  # its IN. `last` is the time this `ton` last ran, energised or not (decision 5), and
  # energised, `.acc` gains `now - last`, unless `.en` shows it was not already enabled:
  # timing starts at the scan that first sees the rung true, which adds nothing. `.acc`
  # stays in 0..max(.pre, 0), so it never leaves a dint however long the gap, and `.dn` is
  # set when it gets there. De-energised, `.acc .dn .tt .en` go to 0. `last` changes only
  # here, so a timer that does not run (a frozen function block, M2-5) catches up when it
  # next does. The preset operand is not read: it is the timer's starting `.pre`, and logic
  # may have written another. Nothing may follow a `ton` on its path (Logex.Compiler), so
  # the power each clause hands on is never read; which it should be is not settled.
  defp evaluate({:ton, _, [timer, _preset]}, {true, env}, %Scan{now: now}) do
    {true, write(env, timer, timing(as_map(read(env, timer)), now))}
  end

  defp evaluate({:ton, _, [timer, _preset]}, {false, env}, %Scan{now: now}) do
    {false, write(env, timer, reset(as_map(read(env, timer)), now))}
  end

  # `ne`, `ge` and `le` are the negations of `eq`, `lt` and `gt`, so each pair is
  # complementary by construction, as `xic` and `xio` are (M1-4). Erlang's term order is
  # total, so a comparison of whatever a hand-built env holds never raises.
  defp compare(:eq, a, b), do: a == b
  defp compare(:ne, a, b), do: not compare(:eq, a, b)
  defp compare(:lt, a, b), do: a < b
  defp compare(:ge, a, b), do: not compare(:lt, a, b)
  defp compare(:gt, a, b), do: a > b
  defp compare(:le, a, b), do: not compare(:gt, a, b)

  # Whatever a hand-built env left in a timer, a well-formed one comes back: a member that
  # is not an integer reads 0, `.en` is read as a contact, and a `last` that is not an
  # integer, or is later than now, adds nothing. A negative `.acc`, which logic may write,
  # counts from 0: it is floored before the time is added, not after.
  defp timing(timer, now) do
    pre = integer(Map.get(timer, "pre"))
    limit = max(pre, 0)
    elapsed = elapsed(closed?(Map.get(timer, "en")), Map.get(timer, "last"), now)
    acc = min(max(integer(Map.get(timer, "acc")), 0) + elapsed, limit)
    done = acc == limit

    %{
      "pre" => pre,
      "acc" => acc,
      "dn" => one(done),
      "tt" => one(not done),
      "en" => 1,
      "last" => now
    }
  end

  defp reset(timer, now),
    do: %{
      "pre" => integer(Map.get(timer, "pre")),
      "acc" => 0,
      "dn" => 0,
      "tt" => 0,
      "en" => 0,
      "last" => now
    }

  defp elapsed(true, last, now) when is_integer(last), do: max(now - last, 0)
  defp elapsed(_enabled, _last, _now), do: 0

  defp integer(value) when is_integer(value), do: value
  defp integer(_not_an_integer), do: 0

  defp one(true), do: 1
  defp one(false), do: 0

  # An operand's value: a literal's own, a tag's, or a member's, reached by its path. A tag
  # or member the env leaves out, or one whose instance a hand-built env left as anything
  # but a map, reads as 0, as a missing tag always has, so `move` copies a 0, not a nil.
  defp read(_env, {:int_lit, _, value}), do: value
  defp read(env, {:name, _, name}), do: Map.get(env, name, 0)
  defp read(env, {:member, _, path}), do: walk(env, path)

  defp walk(value, []), do: value
  defp walk(%{} = map, [key | path]), do: walk(Map.get(map, key, 0), path)
  defp walk(_not_a_map, _path), do: 0

  # A write to a member puts an instance back together where a hand-built env broke it:
  # what is not a map on the way becomes one.
  defp write(env, {:name, _, name}, value), do: Map.put(env, name, value)
  defp write(env, {:member, _, path}, value), do: put_path(env, path, value)

  defp put_path(map, [key], value), do: Map.put(map, key, value)

  defp put_path(map, [key | path], value),
    do: Map.put(map, key, put_path(as_map(Map.get(map, key)), path, value))

  defp as_map(%{} = map), do: map
  defp as_map(_not_a_map), do: %{}

  # M1-4: `xic` reads this and `xio` its negation, so the two are complementary by
  # construction, whatever the env holds. The compiler lets only a bool reach a contact,
  # but an env the host builds by hand can hold a 5, a 0.0, a `false`, a nil, or leave a
  # tag out. A number is read by value, nonzero closed (PLAN.md §5), and a boolean as
  # itself; nil and a missing tag are open; anything else is closed. A member is read
  # the same way (M1-6).
  defp closed?(value) when is_number(value), do: value != 0
  defp closed?(value) when value in [nil, false], do: false
  defp closed?(_value), do: true
end
