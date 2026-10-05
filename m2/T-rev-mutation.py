#!/usr/bin/env python3
"""T-rev: revert every rule of the design one at a time, the full suite each time.

Usage: T-synth-mutation.py [ID ...]. Each mutant replaces one text that must occur exactly
once in one file of a copy of T-rev-work; the copy's file is written back after the run.
Mutants run in parallel, one per copy (scratchpad/m2/T-rev-mut0..3), each copy made from
T-rev-work before the run. Results go to T-rev-mutation.jsonl and T-rev-mutation.log.
Plain `mix test` is used, not --warnings-as-errors, because some mutants leave a clause that
can never match, and a warning would fail them for the wrong reason; the log records
whether a run printed one.
"""
import json, os, re, shutil, subprocess, sys
from concurrent.futures import ThreadPoolExecutor

M2 = "/tmp/claude-0/-home-user-logex/f07aea59-53a1-5b8d-b560-6e6d2e330709/scratchpad/m2"
WORK = f"{M2}/T-rev-work"
ENV = f"{M2}/../toolchain/env.sh"
C = "lib/logex/configuration.ex"
T = "lib/logex/configuration/text.ex"
D = "lib/logex/declarations.ex"
L = "lib/logex.ex"
N = "docs/naming.md"
P = "lib/logex/compiler.ex"

MUTANTS = [
 # From T1's table (M1-M44), each re-pointed at this spike's code.
 ("M1","compile_file takes only .ld",L,'  defp by_kind({".ld", base}, path) when base != ".ld",','  defp by_kind({_ld, base}, path) when base != ".ld",'),
 ("M2","var_external is a section row",D,'    "var_output" => :var_output,\n    "var_external" => :var_external\n','    "var_output" => :var_output\n'),
 ("M3","a var_external takes no initial value",D,'  defp initial(%Tag{section: :var_external, name: name}),','  defp initial(%Tag{section: :var_external_x, name: name}),'),
 ("M4","a var_external's name is legal in a configuration file",D,'  defp shared(%Tag{section: :var_external, name: name}) when is_binary(name),','  defp shared(%Tag{section: :var_external_x, name: name}) when is_binary(name),'),
 ("M5","the reader refuses ( | )",T,'  defp delimiter?({kind, _location}) when kind in [:bst, :nxb, :bnd], do: true','  defp delimiter?({kind, _location}) when kind in [:bst, :nxb, :bnd], do: false'),
 ("M6","a task's inputs in IEC's order",T,'  defp before(nil, _key), do: :ok','  defp before(_later, _key), do: :ok'),
 ("M7","each task input once",T,'  defp once(nil, key, rank, task),','  defp once(_given, key, rank, task),'),
 ("M8","one driver per sink",C,'  defp driver(nil, global, instance, state, line, connection) do','  defp driver(_driven, global, instance, state, line, connection) do'),
 ("M9","nothing drives an input point by connection",C,'  defp drive({:ok, %{location: {_d, :i, _a}} = global}, _tag, instance, state, line, connection),','  defp drive({:ok, %{location: {_d, :never, _a}} = global}, _tag, instance, state, line, connection),'),
 ("M10a","a var_input's global agrees in type",C,'    agree(global.type == tag.type, global, tag, instance, state, line, connection)','    agree(true, global, tag, instance, state, line, connection)'),
 ("M10b","a var_output's global agrees in type",C,'  defp drive({:ok, %{type: type} = global}, %Tag{type: type}, instance, state, line, connection),','  defp drive({:ok, %{type: _type} = global}, %Tag{type: _}, instance, state, line, connection),'),
 ("M11","every var_input connected (decision 7)",C,'  defp leave(message, state, line), do: problem(state, line, message)','  defp leave(_message, state, _line), do: state'),
 ("M12","a var_input has one source",C,'  defp sourced(nil, tag, instance, state, line, connection) do','  defp sourced(_prior, tag, instance, state, line, connection) do'),
 ("M13","an interval is at least 1",C,'  defp interval(state, line, %{interval: 0, name: name}),','  defp interval(state, line, %{interval: -1, name: name}),'),
 ("M14","a task has a priority",C,'  defp priority(state, line, %{priority: nil, name: name}),','  defp priority(state, line, %{priority: :never, name: name}),'),
 ("M15","a task has an interval or a trigger",C,'  defp scheduling(state, line, %{interval: nil, single: nil, name: name}),','  defp scheduling(state, line, %{interval: :never, single: nil, name: name}),'),
 ("M16","a location's address is integers",C,'    addressed(Enum.all?(address, &digits?/1), device, direction, address)','    addressed(true, device, direction, address)'),
 ("M17","one global a location",C,'  defp taken(nil, state, line, global, key),','  defp taken(_any, state, line, global, key),'),
 ("M18","a name is declared once, one namespace",C,'  defp clash(nil, state, kind, name, line) do','  defp clash(_first, state, kind, name, line) do'),
 ("M19","a keyword names nothing in a configuration",C,'  defp name_problem(kind, name),\n    do: name_problem(Text.keyword?(name),','  defp name_problem(kind, name),\n    do: name_problem(false and Text.keyword?(name),'),
 ("M20","a task's single is a bool",C,'  defp trigger({:ok, %{type: :bool}}, state, _line, source),','  defp trigger({:ok, %{type: _}}, state, _line, source),'),
 ("M21","a var_external agrees in type with its global",C,'  defp bind({:ok, %{type: type} = global}, %Tag{type: type}, state, instance, written),','  defp bind({:ok, %{type: _type} = global}, %Tag{type: _}, state, instance, written),'),
 ("M22","nothing writes an input point through var_external",C,'  defp written_point({_device, :i, _address}, global, state, instance, line)','  defp written_point({_device, :never, _address}, global, state, instance, line)'),
 ("M23","two var_external writers warn",C,'    state = Enum.reduce(later, state, &second_writer(&1, &2, first, global))','    state = Enum.reduce(later, state, fn _, state -> state end)'),
 ("M24","a ton under an event task warns",C,'    |> Enum.filter(&(&1.program != nil and Map.has_key?(events, &1.task)))','    |> Enum.filter(&(&1.program != nil and Map.has_key?(events, &1.task) and false))'),
 ("M25","an unused global warns",C,'    |> Enum.reject(&MapSet.member?(state.uses, &1.name))','    |> Enum.reject(fn _ -> true end)'),
 ("M26","an instance is found by name in one step (growth)",C,'  defp entity(state, :instance, name), do: {:ok, Map.fetch!(state.by_name, {:instances, name})}','  defp entity(state, :instance, name), do: {:ok, Enum.find(state.instances, &(&1.name == name))}'),
 ("M27","a configuration has a program",C,'  defp programs_declared([], state),','  defp programs_declared(:never, state),'),
 ("M28","an input point takes no initial value",C,'  defp initial_problems(state, line, %{name: name, at: at}, {_device, :i, _address})','  defp initial_problems(state, line, %{name: name, at: at}, {_device, :never, _address})'),
 ("M29","a constant fits its var_input",C,'    constant_fits(Declarations.fits?(tag.type, value), tag.type, path, value, state, line)','    constant_fits(true, tag.type, path, value, state, line)'),
 ("M30","a broken line declares its name",T,'  defp declared(kind, line, %{name: name}), do: [{:declared, line, %{kind: kind, name: name}}]','  defp declared(_kind, _line, %{name: _name}), do: []'),
 ("M31","keywords in any case",T,'    do: keyed(Map.get(@keywords, String.downcase(word)), String.downcase(word), first, rest)','    do: keyed(Map.get(@keywords, word), word, first, rest)'),
 ("M32","the loader takes only .lxcf",C,'  defp by_extension({@extension, _base}, path), do: loaded(File.read(path), path)','  defp by_extension({_any, _base}, path), do: loaded(File.read(path), path)'),
 ("M33","unconnected var_inputs in declaration order",C,'    |> Enum.sort_by(&{&1.line || 0, &1.name})\n    |> Enum.map(& &1.name)','    |> Enum.map(& &1.name)'),
 ("M34","diagnostics in line order, unlined last",C,'    do: {:error, Enum.sort_by(early ++ diagnostics(state.problems, :error), &order/1)}','    do: {:error, early ++ diagnostics(state.problems, :error)}'),
 ("M35","a broken connection counts as connected",C,'      | inputs: Map.put(state.inputs, {connection.instance, connection.member}, {:broken, line})','      | inputs: Map.put(state.inputs, {connection.instance, line}, {:broken, line})'),
 ("M36","a var_external writer and a connection driver warn",C,'  defp driven_too(nil, _writers, state, _global), do: state','  defp driven_too(_driven, _writers, state, _global), do: state'),
 ("M37","an output point nothing drives warns",C,'    |> Enum.reject(&(Map.has_key?(state.drivers, &1.name) or Map.has_key?(written, &1.name)))','    |> Enum.reject(fn _ -> true end)'),
 ("M38","a task that runs nothing warns",C,'    |> Enum.reject(&MapSet.member?(running, &1.name))','    |> Enum.reject(fn _ -> true end)'),
 ("M39","an unreadable type file is the configuration's, at its line",C,'         {:error, [%Diagnostic{stage: :file, message: message}]},\n         type,','         {:error, [%Diagnostic{stage: :never, message: message}]},\n         type,'),
 ("M40","an entry's name lexes as one name (data path)",T,'    do: one_name!(Logex.Lexer.tokenize(word), word, entry)','    do: :ok'),
 ("M41","the printer writes a task's inputs in IEC's order",T,'          given("single", task.single) ++\n          given("interval", task.interval) ++ given("priority", task.priority),','          given("interval", task.interval) ++\n          given("single", task.single) ++ given("priority", task.priority),'),
 ("M42","an output point takes no initial value",C,'  defp initial_problems(state, line, %{name: name, at: at}, {_device, :q, _address})','  defp initial_problems(state, line, %{name: name, at: at}, {_device, :never, _address})'),
 ("M43","a var_external with no global is a diagnostic",C,'  defp bind(:absent, tag, state, instance, _written),\n    do: problem(state, instance.line, no_global(state, instance, tag))','  defp bind(:absent, _tag, state, _instance, _written),\n    do: state'),
 ("M44","compile_file points a configuration's file to its loader",L,'  defp not_a_program(configuration, base, configuration),','  defp not_a_program(:never, base, _configuration),'),
 ("M45","a configuration keyword is surveyed (naming.md)",N,'### `task` — declare a task','### `task_unsurveyed` — declare a task'),
 # From JT1's own reverts (J1-J21), the three that survived on T1 first.
 ("J1","a check's diagnostic is at stage :configure",C,'%Diagnostic{stage: :configure, line: line, message: message, severity: severity}','%Diagnostic{stage: :validate, line: line, message: message, severity: severity}'),
 ("J14","W2 only for an output point something reads",C,'    |> Enum.filter(&MapSet.member?(state.uses, &1.name))\n    |> Enum.reject(&(Map.has_key?(state.drivers, &1.name)','    |> Enum.reject(&(Map.has_key?(state.drivers, &1.name)'),
 ("J20","a task's single counts as a use of its global (W1)",C,'  defp trigger({:ok, %{type: :bool}}, state, _line, source),\n    do: %{state | uses: MapSet.put(state.uses, source)}','  defp trigger({:ok, %{type: :bool}}, state, _line, _source),\n    do: state'),
 ("J2","a global a var_external binds counts as used (W1)",C,'bind(found, tag, used(state, found), instance, Map.get(writes, tag.name))','bind(found, tag, state, instance, Map.get(writes, tag.name))'),
 ("J3","a connection may come before its program line",C,'  defp on_instance({:ok, %{program: nil}}, state, _line, _connection), do: state\n','  defp on_instance({:ok, %{program: nil}}, state, _line, _connection), do: state\n  defp on_instance({:ok, %{line: il}}, state, line, connection) when is_integer(il) and is_integer(line) and il > line, do: problem(state, line, "no instance `#{connection.instance}`")\n'),
 ("J4","a type's var_external mistakes are cited once a type",C,'    |> Enum.uniq_by(& &1.type)\n    |> Enum.reduce(state, &bound/2)','    |> Enum.reduce(state, &bound/2)'),
 ("J5","the loader compiles each type once",C,'    |> Enum.uniq_by(fn {type, _line} -> type end)','    |> then(& &1)'),
 ("J8","a dotted name whose first part is an instance is its member (R41)",C,'  defp dotted({:instance, _line}, _location, _state, name, _first),','  defp dotted({:never, _line}, _location, _state, name, _first),'),
 ("J9","two names differing only in case are refused",C,'  defp clash(twin, state, _kind, name, line) do\n    {kind, first} = Map.fetch!(state.names, twin)','  defp clash(_twin, state, kind, name, line), do: clash(nil, state, kind, name, line)\n  defp clash_unused(twin, state, _kind, name, line) do\n    {kind, first} = Map.fetch!(state.names, twin)'),
 ("J11","a var_output never drives a constant",C,'  defp sink({:constant, value}, _tag, instance, state, line, connection),\n    do:\n      problem(','  defp sink({:constant, _value}, _tag, _instance, state, _line, _connection), do: state\n  defp sink_unused({:constant, value}, _tag, instance, state, line, connection),\n    do:\n      problem('),
 ("J13","compile_file takes exactly .ld, not .LD",L,'  defp extension_of(base), do: dotfile(Path.extname(base), base)','  defp extension_of(base), do: dotfile(String.downcase(Path.extname(base)), base)'),
 ("J16","an interval is at most 2147483647 ms",C,'  defp interval(state, line, %{interval: ms, name: name}) when is_integer(ms) and ms > @max,','  defp interval(state, line, %{interval: ms, name: name}) when is_integer(ms) and ms > @max * 2,'),
 ("J17","a priority is at most 2147483647",C,'  defp priority(state, line, %{priority: p, name: name}) when p > @max,','  defp priority(state, line, %{priority: p, name: name}) when p > @max * 2,'),
 ("J18","a broken line's name enters the namespace",C,'    state = Enum.reduce(entries, state, &declare/2)','    state = Enum.reduce(Enum.reject(entries, &match?({:declared, _, %{kind: k}} when k != :connection, &1)), state, &declare/2)'),
 ("J19","a type word or `at` in a global's name place is a missing name",T,'  defp named_global(kind, word, token, _rest, _first, _line) when kind in [:type, :global],','  defp named_global(kind, word, token, _rest, _first, _line) when kind in [:never],'),
 ("J21","a name of the wrong kind says what it is",C,'  defp found({kind, line}, false, _state, name, want, _at),\n    do: {:error, "`#{name}` is #{a(kind)}#{at_line(line)}, not #{a(want)}"}','  defp found({_kind, _line}, false, state, name, want, _at),\n    do: {:error, undeclared(state, name, want)}'),
 # This synthesis's fixes and grafts.
 ("N1","a location where a global is wanted is named as one",C,'  defp dotted(_declared, {kind, key}, _state, name, _first) when kind in [:ok, :respell],','  defp dotted(_declared, {kind, key}, _state, name, _first) when kind in [:never],'),
 ("N2","a location that begins a connection is named as one",C,'  defp begun(false, {kind, _key}, state, line, connection) when kind in [:ok, :respell],','  defp begun(false, {kind, _key}, state, line, connection) when kind in [:never],'),
 ("N3","a member of a declared non-instance says what the name is",C,'      "`#{name}` names a member of `#{first}`, but `#{first}` is #{a(kind)}#{at_line(line)}, " <>\n        "not an instance"','      "`#{name}` names a member of an instance, and there is no instance `#{first}`"'),
 ("N4","lines rise from entry to entry",T,'       when is_integer(line) and (last == nil or line > last),','       when is_integer(line),'),
 ("N5","no nil line beside a line",T,'  defp lined!([nil], _entries, _last), do: :ok','  defp lined!([nil | _], _entries, _last), do: :ok'),
 ("N6","a connection's instance has no `.`",T,'    undotted!(String.contains?(instance, "."), entry)','    undotted!(false, entry)'),
 ("N7","a member is checked as the text reads it, joined to its instance",T,'    name!(instance <> "." <> member, entry)','    name!(member, entry)'),
 ("N8","the printer puts a lined entry on its line",T,'    do: {line + 1, [String.duplicate("\\n", line - next) <> printed(entry) <> "\\n" | text]}','    do: {next + 1, [printed(entry) <> "\\n" | text]}'),
 ("N9","Text.read refuses a non-binary with ArgumentError",T,'  def read(source),\n    do:\n      raise(','  def read_unused(source),\n    do:\n      raise('),
 ("N10","Text.keyword? refuses a non-string with ArgumentError",T,'  def keyword?(word),\n    do:\n      raise(','  def keyword_unused?(word),\n    do:\n      raise('),
 ("N11","Text.print checks its entries first",T,'    entries!(entries)\n    entries |> Enum.reduce','    entries |> Enum.reduce'),
 ("N12","the loader's missing type is an unknown type, not a file error",C,'    on_disk(File.exists?(path), type, line, path, dir, found)','    on_disk(true, type, line, path, dir, found)'),
 ("N13","the loader suggests among the program files beside it",C,'        files_hint(Declarations.suggest(type, types, & &1, "program types"), types)','        files_hint("", types)'),
 ("N14","no message advises declaring a keyword",C,'    do: keyworded(Text.keyword?(name), state, name, kind)','    do: keyworded(false, state, name, kind)'),
 ("N15","a refused global takes no location",C,'  defp located({:ok, key}, state, line, global, true),','  defp located({:ok, key}, state, line, global, _entered),'),
 ("N16","a name's case-only hint says names",C,'    do: no(Declarations.suggest(name, names_of(state, kind), & &1, "names"), name, kind)','    do: no(Declarations.suggest(name, names_of(state, kind)), name, kind)'),
 ("N17","a type's case-only hint says program types",C,'        Declarations.suggest(type, types, & &1, "program types"),\n        type,','        Declarations.suggest(type, types),\n        type,'),
 ("N18","a member's case-only hint says members",C,'        Declarations.suggest(connection.member, names, & &1, "members")','        Declarations.suggest(connection.member, names)'),
 ("N19","a connection after a broken one still has its source checked",C,'  defp sourced({:broken, _first}, tag, instance, state, line, connection),\n    do: source(connection.to, tag, instance, state, line, connection)','  defp sourced({:broken, _first}, _tag, _instance, state, _line, _connection),\n    do: state'),
 ("N20","an address field has no leading zero (one spelling)",C,'  defp spelled({:ok, key}, at), do: canonical(canonical_text(key) == at, key)','  defp spelled({:ok, key}, _at), do: canonical(true, key)'),
 ("N21","the loader names the type's file in a message citing its line",C,'  defp in_type_file(file, line), do: " on line #{line} of #{file}"','  defp in_type_file(_file, line), do: " on its line #{line}"'),
 ("N22","the loader passes each type's file to the checks",C,'    files = Map.new(programs, fn {type, _program} -> {type, Path.join(dir, type <> ".ld")} end)','    files = %{}'),
 ("N23","W6 covers a task with single and interval",C,'      for %{single: s, name: name} = task <- state.tasks, s != nil, into: %{}, do: {name, task}','      for %{single: s, interval: nil, name: name} = task <- state.tasks, s != nil, into: %{}, do: {name, task}'),
 ("N24","new!/3 raises every problem, not the first",C,'    do: raise(ArgumentError, Enum.map_join(diagnostics, "\\n", &Diagnostic.format/1))','    do: raise(ArgumentError, Diagnostic.format(hd(diagnostics)))'),
 ("N25","new!/3 refuses a line on an entry from Elixir",C,'  defp unlined!({_kind, nil, _fields}), do: :ok','  defp unlined!(_entry), do: :ok'),
 ("N26","a location's i or q is lowercase",C,'  defp parsed([device, direction, _ | _] = parts) when direction in ["i", "q", "I", "Q"] do','  defp parsed([device, direction, _ | _] = parts) when direction in ["i", "q"] do'),
 ("N27","compile_file names a bare .ld as no program",L,'  defp not_a_program(".ld", ".ld", _configuration),','  defp not_a_program(".never", ".ld", _configuration),'),
 ("N28","new!/3 checks with the same checks (warnings ride)",C,'    built(checked(name, entries, programs, MapSet.new(), []))','    built({:ok, %__MODULE__{name: name, programs: programs}})'),
 # Rules the first table left without a mutant of their own (R5-R52), each reverted alone.
 ("X1","a type's own diagnostics come after the configuration's (R5)",C,'  defp in_file({{:error, ours}, theirs}, path), do: {:error, stamp(ours, path) ++ theirs}','  defp in_file({{:error, ours}, theirs}, path), do: {:error, theirs ++ stamp(ours, path)}'),
 ("X2","a failed type's instances are not checked further (R5, C6)",C,'  defp known_type(:error, true, state, _line, _type), do: {state, nil}','  defp known_type(:error, :never, state, _line, _type), do: {state, nil}'),
 ("X3","a configuration's file name is shaped like a name (R6)",C,'  defp shaped(true, _name, _path), do: []','  defp shaped(_shaped, _name, _path), do: []'),
 ("X4","an unknown line has a did-you-mean among the line keywords (R7)",T,'    do: suggested(Declarations.suggest(word, ["task", "var_global", "program"]), word)','    do: suggested("", word)'),
 ("X5","a keyword that belongs on a line names that line (R8)",T,'    do: {:error, fail(first, placed(word, where)), []}','    do: {:error, fail(first, unknown(word)), []}'),
 ("X6","words after a connection's source are refused (R12, T34)",T,'  defp wire([], connection, line, first, path),','  defp wire([{:name, _, global} | _], connection, line, _first, _path),\n    do: {:ok, {:connection, line, Map.put(connection, :to, {:global, global})}}\n\n  defp wire([], connection, line, first, path),'),
 ("X7","a name has no `.` (R14)",C,'    do: name_problem(Text.keyword?(name), String.contains?(name, "."), kind, name)','    do: name_problem(Text.keyword?(name), false, kind, name)'),
 ("X8","a keyword cannot name a program type (R16)",C,'  defp type_problem(_name?, true, state, line, type),','  defp type_problem(_name?, :never, state, line, type),'),
 ("X9","`with` names a declared task (R21)",C,'  defp in_task({:error, message}, state, line), do: problem(state, line, message)','  defp in_task({:error, _message}, state, _line), do: state'),
 ("X10","an unlocated global's initial value fits its type (R22)",C,'    do: fits(Declarations.fits?(type, value), state, line, type, name, value)','    do: fits(true, state, line, type, name, value)'),
 ("X11","a program line's type is one of the types given (R27)",C,'  defp known_type(:error, false, state, line, type),\n    do: {problem(state, line, unknown_type(type, Map.keys(state.programs))), nil}','  defp known_type(:error, false, state, _line, _type),\n    do: {state, nil}'),
 ("X12","a connection names no path deeper than one member (R30)",C,'    do: member(String.contains?(connection.member, "."), instance, state, line, connection)','    do: member(false, instance, state, line, connection)'),
 ("X13","a var is internal: it does not connect (R31)",C,'  defp sectioned(%Tag{section: :var} = _tag, instance, state, line, connection),','  defp sectioned(%Tag{section: :never} = _tag, instance, state, line, connection),'),
 ("X14","a var_external does not connect (R31)",C,'  defp sectioned(%Tag{section: :var_external}, instance, state, line, connection),','  defp sectioned(%Tag{section: :never}, instance, state, line, connection),'),
 ("X15","a var_input may read an output point back (R34)",C,'  defp read_global({:ok, global}, tag, instance, state, line, connection) do','  defp read_global({:ok, %{location: {_, :q, _}}}, _tag, _instance, state, line, _connection),\n    do: problem(state, line, "read back")\n\n  defp read_global({:ok, global}, tag, instance, state, line, connection) do'),
 ("X16","a var_external is no function block instance (R42, V2)",D,'       when section in [:var_input, :var_output, :var_external],','       when section in [:var_input, :var_output],'),
 # This revision's fixes, each reverted alone (the refutation pass's findings).
 ("P1","entries!/1 refuses an improper list with its pinned message (rf-T-correct-1)",T,'  defp proper!([_entry | rest], entries), do: proper!(rest, entries)','  defp proper!([_entry | _rest], _entries), do: :ok'),
 ("P2","a line broken by a delimiter declares what its words name (rf-T-correct-2)",T,'       before_delimiter(Enum.take_while(tokens, &(not delimiter?(&1))))}','       []}'),
 ("P3a","no task is named by a task input word (rf-T-correct-3)",T,'    not_read_as!(n, Map.keys(@inputs), "a task\'s name", entry)\n','\n'),
 ("P3b","no task's single is a task input word (rf-T-correct-3)",T,'    not_read_as!(s, Map.keys(@inputs), "a task\'s `single`", entry)\n','\n'),
 ("P3c","no global is named by a type word or `at` (rf-T-correct-3)",T,'    not_read_as!(n, ["at" | Map.keys(@types)], "a global\'s name", entry)\n','\n'),
 ("P3d","no program type is `with` (rf-T-correct-3)",T,'    not_read_as!(t, ["with"], "a program\'s type", entry)\n','\n'),
 ("P4","a dotted name after `with` is told a task's name has no `.` (rf-T-correct-4)",C,'  defp undeclared(true, state, name, :task),','  defp undeclared(true, state, name, :never),'),
 ("P5a","Logex.compile_file names an empty path (rf-T-correct-5)",L,'  defp file_kind(""), do: :empty','  defp file_kind(:never), do: :empty'),
 ("P5b","Logex.compile_file names a directory (rf-T-correct-5)",L,'  defp in_directory(true, _path), do: :directory','  defp in_directory(:never, _path), do: :directory'),
 ("P5c","Logex.compile_file reads a dotfile as all extension (rf-T-correct-5)",L,'  defp dotfile("", "." <> _ = base), do: {base, base}','  defp dotfile(:never, "." <> _ = base), do: {base, base}'),
 ("P5d","the loader names an empty path (rf-T-correct-5)",C,'  defp file_kind(""), do: :empty','  defp file_kind(:never), do: :empty'),
 ("P5e","the loader names a directory (rf-T-correct-5)",C,'  defp in_directory(true, _path), do: :directory','  defp in_directory(:never, _path), do: :directory'),
 ("P5f","the loader reads a dotfile as all extension (rf-T-correct-5)",C,'  defp dotfile("", "." <> _ = base), do: {base, base}','  defp dotfile(:never, "." <> _ = base), do: {base, base}'),
 ("P5g","the loader says a bare .lxcf names no configuration (rf-T-correct-5)",C,'  defp by_extension({@extension, @extension}, path),','  defp by_extension({@extension, :never}, path),'),
 ("P6","an event task's interval 0 is told to leave interval out (rf-T-correct-6)",C,'  defp interval(state, line, %{interval: 0, single: single, name: name} = task)\n       when single != nil,','  defp interval(state, line, %{interval: 0, single: single, name: name} = task)\n       when single == :never,'),
 ("P7","a location's advice is in its one spelling (rf-T-correct-7)",C,'    do: "`#{name}` is a location, " <> where_located(nil, canonical_text(key))','    do: "`#{name}` is a location, " <> where_located(nil, name)'),
 ("P8","a name refused as a keyword or for its `.` is not reported again where it is used (rf-T-correct-8)",C,'    do: {%{problem(state, line, message) | broken: MapSet.put(state.broken, name)}, false}','    do: {problem(state, line, message), false}'),
 ("P10","a declared location reads first, whatever its device is called (rf-T-correct-10)",C,'    do: declared_point(Map.get(state.points, key), location, state, name)','    do: declared_point(nil, location, state, name)'),
 ("P11","a location in a .ld rung is named as one (TF-11)",P,'    do: [{:undeclared, line, head, located(String.split(name, "."), name)} | diagnostics]','    do: [{:undeclared, line, head, :member} | diagnostics]'),
 ("P13","a block type given as a program has its own message (X13)",C,'  defp program!({type, %Logex.FbType{name: name}}) when is_binary(type),','  defp program!({type, %Logex.FbType{name: name}}) when is_binary(type) and type == :never,'),
 ("X17","a broken line's name passes the name checks (R52)",C,'  defp declare({:declared, line, %{kind: kind, name: name}}, state) do\n    {state, _entered} = enter(state, kind, name, line)','  defp declare({:declared, line, %{kind: kind, name: name}}, state) do\n    {state, _entered} = named(nil, state, kind, name, line)'),
]

def copies(n):
    paths = []
    for i in range(n):
        p = f"{M2}/T-rev-mut{i}"
        shutil.rmtree(p, ignore_errors=True)
        shutil.copytree(WORK, p, symlinks=True)
        paths.append(p)
    return paths

def run_one(copy, m):
    mid, rule, f, old, new = m
    path = os.path.join(copy, f)
    src = open(path).read()
    n = src.count(old)
    if n != 1:
        return {"id": mid, "rule": rule, "file": f, "result": f"NOT APPLIED (found {n} times)", "exit": None, "failing": []}
    open(path, "w").write(src.replace(old, new))
    try:
        cmd = "mix test test/logex/naming_test.exs" if f == N else "mix test"
        p = subprocess.run(["bash", "-c", f"source {ENV} && cd {copy} && {cmd} 2>&1"], capture_output=True, text=True, timeout=1200)
        out = p.stdout
    finally:
        open(path, "w").write(src)
    result = (re.findall(r"Result: [^\n]*", out) or ["NO RESULT"])[-1]
    failing = re.findall(r"^\s+\d+\) test (.*?) \((Logex[\w.]*|LogexTest)\)$", out, re.M)
    ratio = re.findall(r"4x the instances took [0-9.]+x the reductions", out)
    return {"id": mid, "rule": rule, "file": f, "command": cmd, "exit": p.returncode, "result": result,
            "warned": "warning:" in out, "compile_error": "CompileError" in out or "== Compilation error" in out,
            "failing": [f"{mod}: {t}" for t, mod in failing], "ratio": ratio}

def main():
    only = set(sys.argv[1:])
    todo = [m for m in MUTANTS if not only or m[0] in only]
    n = 4
    cps = copies(n)
    # warm each copy's build once
    for c in cps:
        subprocess.run(["bash", "-c", f"source {ENV} && cd {c} && mix compile >/dev/null 2>&1 && MIX_ENV=test mix compile >/dev/null 2>&1"])
    buckets = [todo[i::n] for i in range(n)]
    results = []
    def worker(i):
        out = []
        for m in buckets[i]:
            r = run_one(cps[i], m)
            print(f"{r['id']}: exit {r['exit']}; {r['result']}; {r['rule']}", flush=True)
            out.append(r)
        return out
    with ThreadPoolExecutor(n) as ex:
        for out in ex.map(worker, range(n)):
            results += out
    order = {m[0]: i for i, m in enumerate(MUTANTS)}
    # A run of some mutants keeps the others' earlier results.
    if only and os.path.exists(f"{M2}/T-rev-mutation.jsonl"):
        kept = [json.loads(l) for l in open(f"{M2}/T-rev-mutation.jsonl")]
        results += [r for r in kept if r["id"] not in only]
    results.sort(key=lambda r: order[r["id"]])
    with open(f"{M2}/T-rev-mutation.jsonl", "w") as fh:
        for r in results:
            fh.write(json.dumps(r) + "\n")
    with open(f"{M2}/T-rev-mutation.log", "w") as fh:
        for r in results:
            fh.write(f"{r['id']} | {r['rule']} | {r['file']} | exit {r['exit']} | {r['result']}"
                     f"{' | compile error' if r.get('compile_error') else ''}{' | ' + r['ratio'][0] if r.get('ratio') else ''}\n")
            for t in r["failing"][:5]:
                fh.write(f"    failed: {t}\n")
            if len(r["failing"]) > 5:
                fh.write(f"    ... and {len(r['failing']) - 5} more\n")
        green = [r["id"] for r in results if r["exit"] == 0]
        na = [r["id"] for r in results if r["exit"] is None]
        fh.write(f"\n{len(results)} mutants; red {len(results) - len(green) - len(na)}; green {green}; not applied {na}\n")
    print("done", flush=True)

main()
