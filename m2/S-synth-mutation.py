#!/usr/bin/env python3
"""S-synth mutation table: each rule of the M2-1 design reverted alone, in a copy of the
spike (S-synth-probe/mutcopy). For each mutant: exact text replacement (must match once),
`mix compile --warnings-as-errors` (a mutant that does not compile cleanly is reported and
never counted), then `mix test --warnings-as-errors` on the whole suite, judged by exit
code, with the failing tests listed. The file is restored after each mutant."""
import subprocess, re, sys, os, json, shutil, filecmp

SP = '/tmp/claude-0/-home-user-logex/f07aea59-53a1-5b8d-b560-6e6d2e330709/scratchpad'
WORK = SP + '/m2/S-synth-work'
W = SP + '/m2/S-synth-probe/mutcopy'
ENV = 'source ' + SP + '/toolchain/env.sh'
C = 'lib/logex/configuration.ex'
R = 'lib/logex/runtime.ex'

M = [
 # --- Logex.Configuration: new!/1's own -------------------------------------------------
 ("NW-1", "new!/1 takes a keyword list", C,
  "defp keyword?(_not_keyword), do: false", "defp keyword?(_not_keyword), do: true"),
 ("NW-2", "new!/1: no unknown field, none given twice", C,
  "    for(key <- Enum.uniq(keys), key not in @fields, do: unknown_field(key)) ++\n      for key <- Enum.uniq(keys -- Enum.uniq(keys)), do: \"#{key}: is given twice\"",
  "    _ = {keys, @fields, &unknown_field/1}\n    []"),
 ("NW-3", "new!/1 refuses an element from Elixir that brings a line", C,
  "when module in [Logex.Configuration.Task, Global, Instance, Connection] and line != nil,",
  "when module in [Logex.Configuration.Task, Global, Instance, Connection] and line == :never,"),
 ("NW-4", "new!/1 checks such an element without its line (one mistake, one message)", C,
  "         {[%{item | line: nil} | items],", "         {[item | items],"),
 ("CF-3c", "new!/1: two programs of one name refused", C,
  "do: program_named(Map.has_key?(programs, name), program, {programs, problems})",
  "do: program_named(Process.get(:logex_mutant, false), program, {programs, problems})"),
 ("CF-3d", "new!/1: an unnamed program refused as unnamed", C,
  "  defp program_from(%Program{name: nil}, {programs, problems}),",
  "  defp program_from(%Program{name: :never}, {programs, problems}),"),
 # --- Logex.Configuration.check/1 ---------------------------------------------------------
 ("CF-1", "a name is a name", C,
  "do: name_shaped(Declarations.name?(name), element, {named, folded, problems})",
  "do: name_shaped(Process.get(:logex_mutant, true), element, {named, folded, problems})"),
 ("CF-2", "one namespace: a name taken twice is refused", C,
  "taken(Map.get(folded, key), element, key, {named, folded, problems})",
  "taken(Process.get(:logex_mutant, nil), element, key, {named, folded, problems})"),
 ("CF-2b", "the namespace is taken in line order", C,
  "      elements\n      |> Enum.sort_by(&line_key/1)\n", "      elements\n"),
 ("CF-2c", "a case-only twin is refused", C,
  "    key = String.downcase(name)\n", "    key = name\n"),
 ("CF-3a", "a program is under its own name", C,
  """  defp program(key, %Program{name: name, tags: tags, rungs: rungs}, ok, problems)
       when is_map(tags) and is_list(rungs),
       do:
         {ok,
          [
            diagnostic(nil, "the program under #{label(key)} is named #{label(name)}")
            | problems
          ]}""",
  """  defp program(_key, %Program{name: _name, tags: tags, rungs: rungs}, ok, problems)
       when is_map(tags) and is_list(rungs),
       do: {ok, problems}"""),
 ("CF-3b", "a program's name is a name", C,
  "do: program_shaped(Declarations.name?(name), program, ok, problems)",
  "do: program_shaped(Process.get(:logex_mutant, true), program, ok, problems)"),
 ("CF-4", "a line is a positive integer or nil", C,
  "defp line(%{line: line} = item, {ok, problems})\n       when line == nil or (is_integer(line) and line > 0),",
  "defp line(%{line: line} = item, {ok, problems})\n       when line == nil or is_integer(line),"),
 ("CF-4b", "each part is a proper list (fix F8)", C,
  """      proper(list, &element(&1, &2, module, one), {[], []}, fn _tail, {ok, problems} ->
        {ok,
         [
           diagnostic(
             nil,
             "#{field} must be a list of %#{inspect(module)}{}, got: #{inspect(list)}"
           )
           | problems
         ]}
      end)""",
  """      proper(list, &element(&1, &2, module, one), {[], []}, fn _tail, {ok, problems} ->
        _ = field
        {ok, problems}
      end)"""),
 ("CF-5", "an interval is 1..2147483647", C,
  "@interval 1..2_147_483_647", "@interval 0..4_294_967_295"),
 ("CF-6", "a priority is 0..2147483647", C,
  "@priority 0..2_147_483_647", "@priority -1..4_294_967_295"),
 ("CF-7", "a global is a bool or a dint", C,
  "defp global(%Global{type: type} = global) when type in [:bool, :dint],",
  "defp global(%Global{type: type} = global) when is_atom(type),"),
 ("CF-8", "an initial value fits", C,
  'do: fit(Declarations.fits?(type, v), type, v, "global `#{name}`", line)',
  'do: fit(Process.get(:logex_mutant, true), type, v, "global `#{name}`", line)'),
 ("CF-9", "an initial value is not negative", C,
  "defp fit(true, :dint, v, what, line) when v < 0,",
  "defp fit(true, :dint, v, what, line) when v < -2_147_483_648,"),
 ("CF-10a", "an input point takes no initial value", C,
  'defp initial(%Global{name: name, line: line}, {:ok, {_device, "i", _address}}),',
  'defp initial(%Global{name: name, line: line}, {:ok, {_device, "x", _address}}),'),
 ("CF-10b", "an output point takes no initial value", C,
  'defp initial(%Global{name: name, line: line}, {:ok, {_device, "q", _address}}),',
  'defp initial(%Global{name: name, line: line}, {:ok, {_device, "y", _address}}),'),
 ("CF-11", "a location is <device>.i|q.<address>", C,
  'defp address([device, io | fields]) when io in ["i", "q"] and fields != [],',
  'defp address([device, io | fields]) when fields != [],'),
 ("CF-11b", "an address field has no leading zero", C,
  "defp number({n, \"\"}, <<digit, _::binary>>, rest, numbers, device, io) when digit in ?1..?9,",
  "defp number({n, \"\"}, <<digit, _::binary>>, rest, numbers, device, io) when digit in ?0..?9,"),
 ("CF-12", "one address holds one global", C,
  "do: address_taken(Map.get(taken, address), global, address, {taken, problems})",
  "do: address_taken(Process.get(:logex_mutant, nil), global, address, {taken, problems})"),
 ("CF-13", "an instance names a program", C,
  "    on_task(instance, tasks, {runnable, [diagnostic(instance.line, message) | problems]})\n  end",
  "    _ = message\n    on_task(instance, tasks, {runnable, problems})\n  end"),
 ("CF-14", "an instance's task is declared", C,
  "do: task_known(Map.has_key?(tasks, task), instance, tasks, {runnable, problems})",
  "do: task_known(Process.get(:logex_mutant, true), instance, tasks, {runnable, problems})"),
 ("CF-15", "a connection names a declared instance", C,
  "    {inputs, driven, [diagnostic(connection.line, message) | problems]}\n  end\n\n  defp member_of",
  "    _ = message\n    {inputs, driven, problems}\n  end\n\n  defp member_of"),
 ("CF-16", "a connection names a declared member", C,
  "do: unknown_member(String.contains?(connection.member, \".\"), program, connection, acc)",
  "do: unknown_member(Process.get(:logex_mutant, true), program, connection, acc)"),
 ("CF-17", "only a var_input or var_output connects", C,
  """  defp of_member({:ok, %Tag{section: section}}, program, connection, acc, _globals),
    do:
      problem(
        acc,
        connection,
        "`#{connection.instance}.#{connection.member}` is internal to `#{program.name}` " <>
          "(declared `#{section}`): only a var_input or var_output connects"
      )""",
  """  defp of_member({:ok, %Tag{section: _section}}, _program, _connection, acc, _globals),
    do: acc"""),
 ("CF-18", "a var_input is connected once", C,
  "    once(\n      Map.get(inputs, key),", "    once(\n      Process.get(:logex_mutant, nil),"),
 ("CF-19", "a var_input's global is of its type", C,
  "do: same_type(global.type == tag.type, global, connection, tag, acc)",
  "do: same_type(Process.get(:logex_mutant, true), global, connection, tag, acc)"),
 ("CF-20", "a constant fits its var_input", C,
  'do: constant(Declarations.fits?(type, to), connection, tag, acc)',
  'do: constant(Declarations.fits?(type, to) or Process.get(:logex_mutant, true), connection, tag, acc)'),
 ("CF-21", "a connection's instance and member are names", C,
  '    do:\n      {inputs, driven,\n       [\n         diagnostic(\n           connection.line,\n           "a connection\'s instance and member are names, as in `m1.start`, found " <>\n             "#{inspect(connection.instance)} and #{inspect(connection.member)}"\n         )\n         | problems\n       ]}',
  '    do:\n      {inputs, driven,\n       tl([\n         diagnostic(\n           connection.line,\n           "a connection\'s instance and member are names, as in `m1.start`, found " <>\n             "#{inspect(connection.instance)} and #{inspect(connection.member)}"\n         )\n         | problems\n       ])}'),
 ("CF-22", "a var_output drives no constant", C,
  """  defp output(%Connection{to: to} = connection, _tag, acc, _globals) when is_integer(to),
    do:
      problem(
        acc,
        connection,
        "`#{connection.instance}.#{connection.member}` is a var_output: it drives a global, " <>
          "and a constant cannot be driven"
      )""",
  """  defp output(%Connection{to: to} = _connection, _tag, acc, _globals) when is_integer(to),
    do: acc"""),
 ("CF-23", "a var_output never drives an input point", C,
  'defp drives({:ok, {_device, "i", _address}}, global, connection, _tag, acc),',
  'defp drives({:ok, {_device, "x", _address}}, global, connection, _tag, acc),'),
 ("CF-24", "a var_output's global is of its type", C,
  "do: typed_sink(global.type == tag.type, global, connection, tag, acc)",
  "do: typed_sink(Process.get(:logex_mutant, true), global, connection, tag, acc)"),
 ("CF-25", "one connection drives a global", C,
  "do: driver(Map.get(driven, global.name), global, connection, {inputs, driven, problems})",
  "do: driver(Process.get(:logex_mutant, nil), global, connection, {inputs, driven, problems})"),
 ("CF-26", "every var_input is connected (decision 7)", C,
  "not Map.has_key?(inputs, {instance.name, name}),",
  "not Map.has_key?(inputs, {instance.name, name}) and Process.get(:logex_mutant, false),"),
 ("CF-27", "at least one program instance", C,
  'defp empty([]), do: [diagnostic(nil, "a configuration runs at least one program instance")]',
  'defp empty([]), do: []'),
 ("CF-28a", "problems in line order", C, "    |> Enum.sort_by(&line_order/1)\n",
  "    |> Enum.sort_by(&line_order/1, fn _, _ -> true end)\n"),
 ("CF-28b", "problems carry the configuration's file", C,
  "    |> Enum.map(&%{&1 | file: file})\n", "    |> Enum.map(&%{&1 | file: (_ = file; nil)})\n"),
 ("CF-28c", "a problem's stage is :configure", C,
  "do: %Diagnostic{stage: :configure, line: line, message: message}",
  "do: %Diagnostic{stage: :validate, line: line, message: message}"),
 ("CF-29a", "a junk instance name is never offered as a did-you-mean", C,
  "    declared =\n      for %Instance{name: name} <- instances, is_binary(name), into: MapSet.new(), do: name",
  "    declared = MapSet.new(instances, & &1.name)"),
 ("CF-29b", "a var_input to a global of a refused type is not checked again", C,
  """  defp of_global({:ok, %Global{type: type}}, _connection, _tag, acc, _globals)
       when type not in [:bool, :dint],
       do: acc
""", ""),
 ("CF-29c", "a var_output to a global of a refused type is not checked again", C,
  """  defp sink({:ok, %Global{type: type}}, _connection, _tag, acc, _globals)
       when type not in [:bool, :dint],
       do: acc
""", ""),
 ("CF-30", "a configuration has a name", C,
  '    do: [diagnostic(nil, ~s|a configuration needs a name, as in name: "plant"|)]',
  '    do: []'),
 ("CF-31", "a configuration's file is a name or nil", C,
  "defp file(file) when is_binary(file) or file == nil, do: {file, []}",
  "defp file(file) when not is_tuple(file), do: {file, []}"),
 # --- Logex.Runtime: start/1 ------------------------------------------------------------
 ("RT-1", "start/1 checks the configuration again", R,
  "    configured!(Configuration.check(config))\n", "    configured!(Enum.take(Configuration.check(config), 0))\n"),
 ("RT-2", "start/1 builds each instance as instance/1 (F14)", R,
  "Map.new(config.instances, &{&1.name, instance(Map.fetch!(config.programs, &1.type))}),",
  "Map.new(config.instances, &{&1.name, %{instance(Map.fetch!(config.programs, &1.type)) | first: false}}),"),
 ("RT-3", "every task is due at start", R,
  "tasks: Map.new(config.tasks, &{&1.name, task_state(0)}),",
  "tasks: Map.new(config.tasks, &{&1.name, task_state(&1.interval)}),"),
 # --- cycle/3 ---------------------------------------------------------------------------
 ("CY-0", "the runtime is checked before elapsed_ms", R,
  "    %__MODULE__{now: now} = runtime = runtime!(runtime)\n    elapsed = elapsed!(elapsed_ms)\n",
  "    elapsed = elapsed!(elapsed_ms)\n    %__MODULE__{now: now} = runtime = runtime!(runtime)\n"),
 ("CY-1", "time advances by elapsed_ms", R,
  "runtime = %{runtime | now: now + elapsed, globals: image!(runtime, inputs)}",
  "runtime = %{runtime | now: now + 0 * elapsed, globals: image!(runtime, inputs)}"),
 ("CY-2", "the input image persists between cycles", R,
  "    imaged(problems, globals, inputs)\n  end",
  "    imaged(problems, Map.merge(globals, Map.new(wiring.inputs, fn {k, _} -> {k, 0} end)), inputs)\n  end"),
 ("CY-3", "a periodic task is due when its due time has come", R, "      next <= now,", "      next < now,"),
 ("CY-4a", "due tasks by priority first", R,
  "do: {{priority, next, index}, task}", "do: {{0 * priority, next, index}, task}"),
 ("CY-4b", "then by the earlier due time", R,
  "do: {{priority, next, index}, task}", "do: {{priority, 0 * next, index}, task}"),
 ("CY-4c", "then by declaration (mutant: reversed)", R,
  "do: {{priority, next, index}, task}", "do: {{priority, next, -index}, task}"),
 ("CY-4d", "then by declaration (mutant: by name)", R,
  "do: {{priority, next, index}, task}", "do: {{priority, next, name, index}, task}"),
 ("CY-5", "the phase is kept: next due moves by whole intervals", R,
  "next_due: next + (missed + 1) * interval", "next_due: runtime.now + interval"),
 ("CY-6a", "a missed period is reported", R,
  "defp overlap(missed, task), do: [{:overlap, task, missed}]", "defp overlap(_missed, _task), do: []"),
 ("CY-6b", "a missed period is counted", R,
  "overlaps: overlaps + missed}", "overlaps: overlaps + 0 * missed}"),
 ("CY-7a", "task-less instances run after every due task", R,
  """    {runtime, events} = Enum.reduce(due(runtime), {runtime, []}, &run_task/2)

    {runtime, events} =
      Enum.reduce(runtime.wiring.taskless, {runtime, events}, &scanned(&1, :none, &2))""",
  """    {runtime, events} =
      Enum.reduce(runtime.wiring.taskless, {runtime, []}, &scanned(&1, :none, &2))

    {runtime, events} = Enum.reduce(due(runtime), {runtime, events}, &run_task/2)"""),
 ("CY-7b", "task-less instances run in every cycle", R,
  "taskless: Map.get(by_task, nil, []),", "taskless: [],"),
 ("CY-7c", "a task's instances in declaration order (mutant: by name)", R,
  "{task.name, task.interval, task.priority, index, Map.get(by_task, task.name, [])}",
  "{task.name, task.interval, task.priority, index, Enum.sort(Map.get(by_task, task.name, []))}"),
 ("CY-7d", "a task's instances in declaration order (mutant: reversed)", R,
  "{task.name, task.interval, task.priority, index, Map.get(by_task, task.name, [])}",
  "{task.name, task.interval, task.priority, index, Enum.reverse(Map.get(by_task, task.name, []))}"),
 ("CY-7e", "task-less instances in declaration order (mutant: by name)", R,
  "taskless: Map.get(by_task, nil, []),", "taskless: Enum.sort(Map.get(by_task, nil, [])),"),
 ("CY-7f", "task-less instances in declaration order (mutant: reversed)", R,
  "taskless: Map.get(by_task, nil, []),", "taskless: Enum.reverse(Map.get(by_task, nil, [])),"),
 ("CY-8a", "copy in: a constant", R,
  "defp value(constant, _globals), do: constant", "defp value(_constant, _globals), do: 0"),
 ("CY-8b", "copy in: a global's current value", R,
  "defp value(global, globals) when is_binary(global), do: Map.fetch!(globals, global)",
  "defp value(global, globals) when is_binary(global), do: 0 * Map.fetch!(globals, global)"),
 ("CY-8c", "copy out: a var_output to its global, at once", R,
  "        Map.put(globals, global, Map.fetch!(outputs, member))",
  "        _ = Map.fetch!(outputs, member)\n        Map.put(globals, global, Map.fetch!(globals, global))"),
 ("CY-9", "the outputs are the output points only", R,
  'outputs: for({global, {:ok, {_, "q", _}}} <- points, do: global.name),',
  'outputs: for({global, {:ok, {_, _, _}}} <- points, do: global.name),'),
 ("EV-1", "a task-less scan is reported with :none", R,
  "&scanned(&1, :none, &2))", "&scanned(&1, nil, &2))"),
 ("EV-2", "an overlap is reported just before its task's scans", R,
  "    Enum.reduce(instances, {runtime, overlap(missed, name) ++ events}, &scanned(&1, name, &2))",
  "    {runtime, events} = Enum.reduce(instances, {runtime, events}, &scanned(&1, name, &2))\n    {runtime, overlap(missed, name) ++ events}"),
 # --- inputs ----------------------------------------------------------------------------
 ("IN-1a", "only an input point is set: an output point or unlocated global refused", R,
  '    do:\n      "input #{label(key)} is #{not_input(Configuration.location(global.at), global)}: " <>\n        "only an input point is set from outside"',
  '    do: (_ = {label(key), not_input(Configuration.location(global.at), global)}; nil)'),
 ("IN-1b", "a path into an instance is refused as one", R,
  '  defp reaching(true, head, key, _wiring),\n    do:\n      "input #{label(key)} reaches into the program instance `#{head}`: " <>\n        "only an input point is set from outside"',
  '  defp reaching(true, head, key, wiring),\n    do: (_ = head; no_point(key, wiring))'),
 ("IN-1c", "a key that is not a string is refused as one", R,
  "  defp point_problem(key, _value, _wiring) when not is_binary(key),",
  "  defp point_problem(key, _value, _wiring) when is_tuple(key),"),
 ("IN-2", "an input point's value fits it", R,
  "do: fit(%Tag{name: key, type: type, section: :var_input}, value)",
  "do: (_ = {type, value, key}; nil)"),
 ("IN-3", "every input problem in one raise", R,
  "  defp imaged(problems, _globals, _inputs), do: raise(ArgumentError, Enum.join(problems, \"\\n\"))",
  "  defp imaged(problems, _globals, _inputs), do: raise(ArgumentError, hd(problems))"),
 # --- next_due_in/1, overlaps/1 ---------------------------------------------------------
 ("NX-1a", "next_due_in is :infinity with no task", R,
  "defp due_in(nil, _now), do: :infinity", "defp due_in(nil, _now), do: 0"),
 ("NX-1b", "next_due_in is the soonest task", R,
  "|> Enum.min(fn -> nil end) |> due_in(now)", "|> Enum.max(fn -> nil end) |> due_in(now)"),
 ("NX-2", "overlaps/1 reads each task's count", R,
  "Map.new(tasks, fn {name, %{overlaps: overlaps}} -> {name, overlaps} end)",
  "Map.new(tasks, fn {name, %{overlaps: _overlaps}} -> {name, 0} end)"),
 # --- get/2 -----------------------------------------------------------------------------
 ("GT-1", "get/2 never reads an internal member", R,
  "do: member_at(FbType.member(type, member), type, at, {member, deeper}, {walked, path}, env)",
  "do: member_at(Enum.find_value(type.members, :error, &(&1.name == member && {:ok, &1})), type, at, {member, deeper}, {walked, path}, env)"),
 ("GT-2", "get/2 refuses an instance named whole", R,
  '  defp at_path(:error, {:ok, type}, {head, [], _path}, runtime),\n    do:\n      raise(\n        ArgumentError,\n        "`#{head}` is a program instance, a `#{type}`: an access path names one of its tags" <>\n          example_tag(Map.fetch!(runtime.config.programs, type), head)\n      )',
  '  defp at_path(:error, {:ok, type}, {head, [], _path}, runtime),\n    do: (_ = example_tag(Map.fetch!(runtime.config.programs, type), head); 0)'),
 ("GT-3", "get/2 refuses a path past a bool or a dint", R,
  '  defp in_program({:ok, %Tag{type: type}}, {head, tag, _members, path}, _program, _env),\n    do:\n      raise(\n        ArgumentError,\n        "`#{path}` goes too deep: `#{head}.#{tag}` is a #{type}, which has no members"\n      )',
  '  defp in_program({:ok, %Tag{type: type}}, {head, tag, _members, path}, _program, env),\n    do: (_ = {type, head, path}; walk(env, [tag]))'),
 ("GT-4a", "a whole block's example is an output member first", R,
  "do: example_member(Enum.find(members, &(&1.role == :output)), members, at)",
  "do: example_member(Enum.find(members, &(&1.role == :input)), members, at)"),
 ("GT-4b", "else any public member, else none", R,
  "  defp example_member(nil, [%FbType.Member{name: name} | _], at), do: \", as in `#{at}.#{name}`\"",
  "  defp example_member(nil, [%FbType.Member{} | _], _at), do: \", and it has none a path can name\""),
 ("GT-6", "an instance whole: one of its tags as the example, else none", R,
  '  defp tag_example([], _head), do: ", and it declares none"',
  '  defp tag_example([], head), do: ", as in `#{head}.`"'),
 ("GT-7", "a block with no public member says so when a member is not found", R,
  '  defp block_hint("", []), do: ": it has no member a path can name"\n', ''),
 ("GT-5", "an access path lexes as one name token", R,
  "  defp path!(path) when is_binary(path), do: path_lexed(Logex.Lexer.tokenize(path), path)",
  "  defp path!(path) when is_binary(path), do: path_lexed({:ok, [{:name, 1, path}], []}, path)"),
 # --- restart/2 -------------------------------------------------------------------------
 ("RS-0", "restart/2 checks the runtime, then the mode", R,
  "    %__MODULE__{now: now, config: config} = runtime = runtime!(runtime)\n    mode!(mode)\n",
  "    mode!(mode)\n    %__MODULE__{now: now, config: config} = runtime = runtime!(runtime)\n"),
 ("RS-1", "restart/2 zeroes every overlap count", R,
  "fn {name, _state} -> {name, task_state(now)} end",
  "fn {name, state} -> {name, %{task_state(now) | overlaps: state.overlaps}} end"),
 ("RS-2", "restart/2 makes every task due at the next cycle", R,
  "fn {name, _state} -> {name, task_state(now)} end",
  "fn {name, state} -> {name, %{task_state(now) | next_due: state.next_due}} end"),
 ("RS-3", "restart/2 keeps the input image", R,
  "do: input_kept(Map.has_key?(runtime.wiring.inputs, name), global, runtime)",
  "do: input_kept(Map.has_key?(runtime.wiring.inputs, name) and Process.get(:logex_mutant, false), global, runtime)"),
 ("RS-4", "restart/2 restarts each instance through restart/3", R,
  "{name, restart(Map.fetch!(config.programs, state.type), state, mode)}",
  "{name, (_ = Map.fetch!(config.programs, state.type); state)}"),
 ("RS-5", "restart/2 puts every other global back at its initial value", R,
  "  defp input_kept(false, global, _runtime), do: initial_value(global)",
  "  defp input_kept(false, global, runtime), do: Map.fetch!(runtime.globals, global.name)"),
 ("RS-6", "restart/2 keeps the clock", R,
  "    %{\n      runtime\n      | globals: Map.new(config.globals, &{&1.name, restarted(&1, runtime)}),",
  "    %{\n      runtime\n      | now: 0 * now,\n        globals: Map.new(config.globals, &{&1.name, restarted(&1, runtime)}),"),
 # --- plain data, growth -----------------------------------------------------------------
 ("PD-1", "a runtime is plain data", R,
  "      globals: Map.new(config.globals, &{&1.name, &1})\n    }",
  "      globals: Map.new(config.globals, &{&1.name, &1}),\n      clock: &System.monotonic_time/0\n    }"),
 ("GR-1", "a cycle is linear in the instances it runs (an event list rebuilt per scan)", R,
  "     [{:ran, task, name, now} | events]}",
  "     Enum.reverse(Enum.reverse(events) ++ [{:ran, task, name, now}])}"),
 ("GR-2", "a cycle is linear in the tasks due", R,
  "    %{next_due: next, overlaps: overlaps} = state = Map.fetch!(runtime.tasks, name)\n",
  "    %{next_due: next, overlaps: overlaps} = state = Map.fetch!(runtime.tasks, name)\n    _ = Enum.count(runtime.wiring.tasks, &(elem(&1, 0) == name))\n"),
 ("GR-3", "check/1 (so new!/1 and start/1) is linear in the instances", C,
  "      Enum.reduce(instances, {%{}, []}, fn instance, {runnable, problems} ->\n",
  "      Enum.reduce(instances, {%{}, []}, fn instance, {runnable, problems} ->\n        _ = Enum.count(instances, &(&1 == instance))\n"),
 ("GR-4", "start/1 is linear in the instances (its own part)", R,
  "    by_task = Enum.group_by(config.instances, & &1.task, & &1.name)\n",
  "    by_task = Enum.group_by(config.instances, & &1.task, & &1.name)\n    _ = Enum.map(config.instances, fn i -> Enum.count(config.instances, &(&1 == i)) end)\n"),
]

def sh(cmd, timeout=1500):
    return subprocess.run(['bash', '-c', ENV + ' && cd ' + W + ' && ' + cmd],
                          capture_output=True, text=True, timeout=timeout)

def main():
    # `python3 S-synth-mutation.py K N [ids...]`: worker K of N takes every Nth mutant, in
    # its own copy of the spike, so that N workers run the table in parallel.
    global W
    k, workers = int(sys.argv[1]), int(sys.argv[2])
    only = sys.argv[3:]
    W = W + '-%d' % k
    if os.path.exists(W): shutil.rmtree(W)
    shutil.copytree(WORK, W, symlinks=True)
    for i, (mid, rule, f, old, new) in enumerate(M):
        if i % workers != k: continue
        if only and mid not in only: continue
        path = os.path.join(W, f)
        src = open(path).read()
        n = src.count(old)
        if n != 1:
            print(json.dumps({'id': mid, 'rule': rule, 'error': 'text found %d times' % n}), flush=True)
            continue
        open(path, 'w').write(src.replace(old, new))
        try:
            c = sh('mix compile --warnings-as-errors 2>&1')
            if c.returncode != 0:
                print(json.dumps({'id': mid, 'rule': rule, 'compile': c.returncode,
                                  'note': 'did not compile cleanly: ' + c.stdout[-400:]}), flush=True)
                continue
            r = sh('mix test --warnings-as-errors 2>&1')
            out = r.stdout
            fails = re.findall(r'^\s+\d+\) (?:test|doctest) (.*?) \((Logex[\w.]*)\)$', out, re.M)
            files = sorted(set(m for _, m in fails))
            res = re.findall(r'^Result: .*$', out, re.M)
            print(json.dumps({'id': mid, 'rule': rule, 'file': f, 'compile': 0, 'exit': r.returncode,
                              'result': res[-1] if res else '', 'failed': len(fails),
                              'modules': files, 'tests': [t for t, _ in fails][:8]}), flush=True)
        finally:
            open(path, 'w').write(src)
    # The copy is back to the spike, file by file.
    for f in [C, R]:
        assert filecmp.cmp(os.path.join(W, f), os.path.join(WORK, f), shallow=False), f
    print(json.dumps({'restored': True}), flush=True)

main()
