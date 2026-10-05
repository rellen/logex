#!/usr/bin/env python3
"""F-synth mutation table: revert each rule of the M2-5 design alone, run the whole suite,
and record the exit code and the failing tests. Usage:
  F-synth-mutation.py check        # each pattern found exactly once in F-synth-work
  F-synth-mutation.py run [ids...] # run, in parallel copies, writing F-synth-mutation.json/.log
"""
import subprocess, sys, re, os, json, shutil, threading, queue

P = '/tmp/claude-0/-home-user-logex/f07aea59-53a1-5b8d-b560-6e6d2e330709/scratchpad/m2'
W = f'{P}/F-synth-work'
OUT = f'{P}/F-synth-mutation'
ENV = 'source /tmp/claude-0/-home-user-logex/f07aea59-53a1-5b8d-b560-6e6d2e330709/scratchpad/toolchain/env.sh'
WORKERS = 4

M = []
def m(mid, rule, path, old, new):
    M.append((mid, rule, path, old, new))

C, D, E, F, R, L, WR = ('lib/logex/compiler.ex', 'lib/logex/declarations.ex', 'lib/logex/edit.ex',
                        'lib/logex/fb_type.ex', 'lib/logex/runtime.ex', 'lib/logex.ex',
                        'lib/logex/warnings.ex')

# ---- a block's file -------------------------------------------------------------------
m('R1', 'the header word is recognised in any case', C,
  'heads(String.downcase(word) == "function_block", rest, line, rungs, all)',
  'heads(word == "function_block", rest, line, rungs, all)')
m('R2', 'a var is a :local member', F,
  'defp role(:var), do: :local', 'defp role(:var), do: :internal')
m('R3', 'a block is named after its file', L,
  '''  defp named_as({:ok, %FbType{name: block}}, {line, _block}, _source, name),
    do: {:error, [misnamed(line, block, name)]}''',
  '''  defp named_as({:ok, %FbType{} = type}, {_line, _block}, _source, _name),
    do: {:ok, type}''')
m('R4', 'a block\'s name is no reserved word', C,
  '''  defp reserved_block(reserved, name, line),
    do: [''', '''  defp reserved_block(reserved, name, line) when reserved == :never,
    do: [''')
m('R5', 'function_block names no block (org §4.8)', C,
  'do: header_word(String.downcase(name) in Declarations.kinds(), name, line)',
  'do: header_word(String.downcase(name) == :never, name, line)')
m('R6', 'function_block names no tag in a block\'s file', C,
  '''  defp header_tags({:block, _name}, tags),
    do:''', '''  defp header_tags({:block, _name}, tags) when tags == :never,
    do:''')
m('R7', 'function_block outside the first line has its own message', C,
  'defp unknown("function_block", word),', 'defp unknown("function_block_never", word),')
m('R8', 'the runtime refuses a block type with its own message', R,
  '''  defp program!(%FbType{name: name}) when is_binary(name),''',
  '''  defp program!(%FbType{name: name}) when is_binary(name) and name == :never,''')
m('R9', 'the edit refuses a block type with its own message', E,
  '''  defp program!(%FbType{name: name}) when is_binary(name),''',
  '''  defp program!(%FbType{name: name}) when is_binary(name) and name == :never,''')
m('R10', 'members follow declaration order, those from Elixir first', F,
  'defp order(%Tag{line: nil, name: name}), do: {0, name}',
  'defp order(%Tag{line: nil, name: name}), do: {2, name}')

# ---- the types a compile is given -------------------------------------------------------
m('R11', 'types: holds only types user?/1 accepts', C,
  'given!(FbType.user?(type), type, library)', 'given!(is_struct(type, FbType), type, library)')
m('R12', 'user?/1 is what of/1 gives for its body', F,
  'and of(type.body) == type, type, path, done)', 'and is_list(type.members), type, path, done)')
m('R13', 'user?/1 refuses a name no block could have', F,
  'do: named(Logex.Declarations.block_name?(name), type, path, done)',
  'do: named(is_binary(name), type, path, done)')
m('R14', 'user?/1 accepts a member declared from Elixir', F,
  'when ((is_integer(line) and line > 0) or is_nil(line)) and',
  'when ((is_integer(line) and line > 0) or (is_nil(line) and false)) and')
m('R15', 'types: holds no two blocks of one name', C,
  '''  defp given!(true, %FbType{name: name}, _library),''',
  '''  defp given!(true, %FbType{name: name}, _library) when name == :never,''')
m('R16', 'one version of each block name, in the types given', C,
  '''    Enum.reduce(Map.values(library), library, &one_version!/2)
    library''', '''    library''')
m('R17', 'the unknown-type message suggests a block given', D,
  '<> suggest(type, blocks, & &1, "type names")', '<> suggest(type, [], & &1, "type names")')
m('R18', 'an instance of a user block takes no initial value (Elixir)', D,
  '''  defp instance(%Tag{name: name, type: %FbType{body: %Logex.Program{}}} = tag),''',
  '''  defp instance(%Tag{name: name, type: %FbType{body: %Logex.Program{}}} = tag) when name == :never,''')

# ---- recursion ---------------------------------------------------------------------------
m('R19', 'a block never holds an instance of itself', C,
  '''    library |> Map.merge(marks) |> Map.put(name, {:recursive, [name, name]})''',
  '''    Map.merge(library, marks)''')
m('R20', 'nor of a type given that holds it, at any depth', C,
  '''    library |> Map.merge(marks) |> Map.put(name, {:recursive, [name, name]})''',
  '''    _ = marks
    Map.put(library, name, {:recursive, [name, name]})''')
m('R21', 'nor through a tag declared from Elixir (ArgumentError)', C,
  '''    holds_itself!(kind, declared)
''', '''    _ = &holds_itself!/2
''')
m('R22', 'a recursive declaration\'s uses are excused: one message', C,
  'defp excused?({:undeclared, _line, name, _slot}, excused), do: is_map_key(excused, name)',
  'defp excused?({:undeclared, _line, name, _slot}, excused), do: is_map_key(excused, name) and false')

# ---- cal at compile time -----------------------------------------------------------------
m('R23', 'cal on a ton is refused, naming ton', C,
  'defp not_run(nil, {:ok, %Tag{type: %FbType{name: type}} = tag}, line, name, word),',
  'defp not_run(nil, {:ok, %Tag{type: %FbType{name: type}} = tag}, line, name, word) when name == :never,')
m('R24', 'cal on a bool or a dint is refused', C,
  '''  defp not_run(nil, {:ok, tag}, line, name, word),''',
  '''  defp not_run(nil, {:ok, tag}, line, name, word) when name == :never,''')
m('R25', 'an arity error names every formal', C,
  '''  defp cal_count(formals, operands, _rest, _instance, diagnostics)
       when length(operands) == length(formals),''',
  '''  defp cal_count(formals, operands, _rest, _instance, diagnostics)
       when length(operands) == length(formals) or true,''')
m('R26', 'an operand of the wrong type names its formal', C,
  '''  defp typed_formal(diagnostics, _type, found, name, {formal, line, at}),''',
  '''  defp typed_formal(diagnostics, _type, found, name, {formal, line, at}) when name == :never,''')
m('R27', 'a var_input where cal writes is refused', C,
  '''  defp input_formal(diagnostics, :write, %Tag{section: :var_input} = tag, {formal, line, at}),''',
  '''  defp input_formal(diagnostics, :write, %Tag{section: :var_input} = tag, {formal, line, at}) when line == :never,''')
m('R28', 'a member logic may not write, where cal writes, is refused', C,
  '''  defp member_formal(diagnostics, :write, tag, %Member{write: false}, name, {formal, line, at}),''',
  '''  defp member_formal(diagnostics, :write, tag, %Member{write: false}, name, {formal, line, at}) when line == :never,''')
m('R29', 'a literal that does not fit an input is refused', C,
  'do: fits_formal(Declarations.fits?(type, value), formal, value, {line, at}, diagnostics)',
  'do: fits_formal(Declarations.fits?(type, value) or true, formal, value, {line, at}, diagnostics)')
m('R30', 'one cal runs an instance', C, '    calls = calls(instructions)', '    calls = []')

# ---- members, warnings -----------------------------------------------------------------------
m('R31', 'a block\'s inputs and outputs are read anywhere', F,
  'do: Enum.filter(members, &(&1.role in [:input, :output]))',
  'do: Enum.filter(members, &(&1.role in [:output]))')
m('R32', 'a block\'s own var is hidden from outside', F,
  'do: Enum.filter(members, &(&1.role in [:input, :output]))',
  'do: Enum.filter(members, &(&1.role in [:input, :output, :local]))')
m('R33', 'no member of a user block is written from outside', F,
  'do: %Member{name: name, type: type, role: role(section), initial: starts(type, initial)}',
  'do: %Member{name: name, type: type, role: role(section), initial: starts(type, initial), write: section == :var_output}')
m('R34', 'an instance no cal runs is warned about, saying cal', WR,
  '''  defp uncalled(false, tag),''', '''  defp uncalled(false, _tag), do: []
  defp uncalled(:never, tag),''')
m('R35', 'a cal\'s operands are uses with its block\'s signature (warnings)', WR,
  '''    for {slot, _formal} <- FbType.signature(type), do: slot''',
  '''    for {{_access, t}, _formal} <- FbType.signature(type), do: {:read, t}''')
m('R36', 'a block\'s body is warned about, in its type', C,
  '''      tags: tags,
      warnings: Logex.Warnings.of(rungs, tags)
    }''', '''      tags: tags,
      warnings: Enum.take(Logex.Warnings.of(rungs, tags), 0)
    }''')

# ---- running a block -------------------------------------------------------------------------
m('R37', 'a false EN runs nothing (decision 12)', R,
  '''  defp evaluate({:cal, _, _}, {false, env}, _scan) do
    {false, env}
  end''', '''  defp evaluate({:cal, _, _} = cal, {false, env}, scan) do
    {_power, env} = evaluate(cal, {true, env}, scan)
    {false, env}
  end''')
m('R38', 'the inputs are copied in', R,
  '''  defp copy_in({{{:value, _}, %Member{name: name}}, operand}, state, env),''',
  '''  defp copy_in({{{:value, _}, %Member{name: name}}, operand}, state, env) when name == :never,''')
m('R39', 'the outputs are copied out', R,
  '''    Enum.reduce(slots, Map.put(env, instance, state), &copy_out(&1, &2, state))''',
  '''    _ = &copy_out/3
    Map.put(env, instance, state)''')
m('R40', 'ENO is EN', R,
  'do: {true, called(Map.get(tags, instance), instance, operands, env, scan)}',
  'do: {false, called(Map.get(tags, instance), instance, operands, env, scan)}')
m('R41', 'first is the program instance\'s inside a body', R,
  '''    body = %{scan | tags: own, ons_blocked: as_map(Map.get(blocked, instance))}''',
  '''    body = %{scan | tags: own, ons_blocked: as_map(Map.get(blocked, instance)), first: false}''')
m('R42', 'the body sees only its own instance\'s blocked bits', R,
  '''    body = %{scan | tags: own, ons_blocked: as_map(Map.get(blocked, instance))}''',
  '''    body = %{scan | tags: own, ons_blocked: blocked}''')
m('R43', 'scan.tags is the runtime\'s', R,
  '''  defp scan!(%Scan{tags: tags}, _state) when tags != nil,''',
  '''  defp scan!(%Scan{tags: tags}, _state) when tags != nil and false,''')
m('R44', 'an instance left as no map runs from an empty one', R,
  '''    state = Enum.reduce(slots, as_map(Map.get(env, instance)), &copy_in(&1, &2, env))''',
  '''    state = Enum.reduce(slots, Map.get(env, instance), &copy_in(&1, &2, env))''')
m('R45', 'a hand-built cal of no block runs nothing', R,
  '''  defp called(_not_a_block, _instance, _operands, env, _scan), do: env''',
  '''  defp called(:never, _instance, _operands, env, _scan), do: env''')

# ---- the online edit ---------------------------------------------------------------------------
m('R46', 'a block\'s body is not its type: an edit may change it', E,
  '''  defp changes(
         %FbType{name: name, body: %Program{}} = was,
         %FbType{name: name, body: %Program{}} = type,
         path
       ),''', '''  defp changes(
         %FbType{name: name, body: %Program{}} = was,
         %FbType{name: name, body: %Program{}} = type,
         path
       )
       when was == type,''')
m('R47', 'a member\'s kind change is cited as a member\'s', E,
  '''  defp whose(true), do: "a member's"''', '''  defp whose(true), do: "a tag's"''')
m('R48', 'the nested migration starts a member the state lacks or the candidate adds', E,
  '''    starts?(Map.fetch(elem(acc, 0), name), not kept?, type, first?)
    |> started(name, path, initial, acc)''', '''    _ = first?

    false
    |> started(name, path, initial, acc)''')
m('R49', 'at the first test a nested member that does not fit starts again (decision 26)', E,
  '''    starts?(Map.fetch(elem(acc, 0), name), not kept?, type, first?)''',
  '''    starts?(Map.fetch(elem(acc, 0), name), not kept?, type, first? and kept? and false)''')
m('R50', 'at the first test an instance that is not a map starts again whole', E,
  '''  defp fits?(:block, value), do: is_map(value)''', '''  defp fits?(:block, _value), do: true''')
m('R51', 'a kept member whose initial value changed is reported', E,
  '''  defp initial_changed({:kept, {map, reports, pre}}, {true, old, new}, path) when old != new,''',
  '''  defp initial_changed({:kept, {map, reports, pre}}, {true, old, new}, path) when old != new and false,''')
m('R52', 'assemble and cancel prune a block\'s dropped members', E,
  '''    {kept, inside} = Enum.reduce(plan.nested, {kept, []}, &prune_in/2)''',
  '''    {kept, inside} = {kept, Enum.take(plan.nested, 0)}''')
m('R53', 'prune reaches an instance an instance holds', E,
  '''        nested_prune(Map.get(kept, name), {name, prefix <> "." <> name, inner}, {kept, reports})''',
  '''        nested_prune(Map.get(kept, name <> "\\0"), {name, prefix <> "." <> name, inner}, {kept, reports})''')
m('R54', 'a nested one-shot\'s chain includes the rung that cals its instance', E,
  '''        Enum.reduce(cals, {writes, oned(bits, chain, ons)}, &inside(&1, chain, &2, bodies))''',
  '''        Enum.reduce(cals, {writes, oned(bits, chain, ons)}, &inside(&1, [], &2, bodies))''')
m('R55', 'a one-shot two levels down belongs to the chain too', E,
  '''          inside({prefix <> "." <> name, type}, chain, acc, bodies)''',
  '''          _ = {name, type, chain, bodies}
          acc''')
m('R56', 'a blocked bit inside an instance is reported with its value, by path', E,
  '''  defp bit_at(env, bit), do: path_at(env, String.split(bit, "."))''',
  '''  defp bit_at(env, bit), do: Map.get(env, bit, 0)''')
m('R57', 'a nested block an earlier edit left pending is kept (F2)', E,
  '''      ons_bits: for({_key, bits} <- ons, bit <- bits, into: %{}, do: {bit, true}),''',
  '''      ons_bits: for({_key, bits} <- ons, bit <- bits, not String.contains?(bit, "."), into: %{}, do: {bit, true}),''')
m('R58', 'a timer inside a block meets the preset rules by its path', E,
  '''  defp runs_ton(true, %{} = initial), do: Map.get(initial, "pre")''',
  '''  defp runs_ton(true, %{} = _initial), do: nil''')
m('R59', 'a nested plan is per whether each program runs the instance (decision 23)', E,
  '''    key = {type.name, was != nil, runs}''', '''    key = {type.name, was != nil}''')
m('R60', 'a timer both programs run is not resumed (decision 8)', E,
  '''  defp resumed({nil, to, true}, %{"en" => 1, "last" => last} = timer, name, now)''',
  '''  defp resumed({_from, to, true}, %{"en" => 1, "last" => last} = timer, name, now)''')
m('R61', 'resume only where the program stopped last scanned', E,
  '''  defp resumed({nil, to, true}, %{"en" => 1, "last" => last} = timer, name, now)''',
  '''  defp resumed({nil, to, _stopped_last?}, %{"en" => 1, "last" => last} = timer, name, now)''')
m('R62', 'an undo by path reaches a timer only the stopped version declares (F1, F11)', E,
  '''    {gone, memo} = gone(was, names, memo)''', '''    {gone, memo} = gone(nil, names, memo)''')
m('R63', 'an undo by path reaches an instance only the stopped program declares', E,
  '''    plans ++ gone''', '''    _ = gone
    plans''')
m('R64', 'an output only a cal drove is held (decision 20)', E,
  '''    {wrote(slots, operands, writes), bits, [{instance, type} | cals]}''',
  '''    _ = slots
    {writes, bits, [{instance, type} | cals]}''')
m('R65', 'a hand-built cal of no block writes nothing in the edit\'s walk', E,
  '''  defp calling(_not_a_block, _operands, acc), do: acc''',
  '''  defp calling(:never, _operands, acc), do: acc''')
m('R66', 'the nested plan builds a block\'s initial state only where one starts (growth)', E,
  '''    {{:block, name, {type, initial}, old != nil, plan}, memo}''',
  '''    _ = FbType.initial(type, initial)
    {{:block, name, {type, initial}, old != nil, plan}, memo}''')

# ---- loading a block's file ------------------------------------------------------------------
m('R67', 'compile_file finds a block\'s file beside the file that names it', L,
  '''  defp found(false, _word, acc, _context), do: acc''',
  '''  defp found(_exists, _word, acc, _context), do: acc''')
m('R68', 'a mistake in a block\'s file is reported with its file', L,
  '''    do: {:error, Enum.map(diagnostics, &%{&1 | file: &1.file || path})}''',
  '''    do: {:error, Enum.map(diagnostics, &%{&1 | file: path})}''')
m('R69', 'a program\'s file is no type, before any cycle is looked for', L,
  '''    do: kind_of(peek(file), {word, line, file}, {types, problems, loaded}, {path, held})''',
  '''    do: kind_of(peek(file) == :never, {word, line, file}, {types, problems, loaded}, {path, held})''')
m('R70', 'a dotted type word names no file', L,
  '''          Declarations.name?(word),
''', '''          Declarations.name?(word) or true,
''')

# ---- naming --------------------------------------------------------------------------------
m('R71', 'the function_block stanza is in docs/naming.md', 'docs/naming.md',
  '### `function_block` — a function block\'s file', '### `function-block` — a function block\'s file')
m('R72', 'the cal stanza is in docs/naming.md', 'docs/naming.md',
  '### `cal` — run an instance of a user function block', '### `cal-` — run an instance of a user function block')


def check():
    bad = 0
    for mid, rule, path, old, new in M:
        n = open(os.path.join(W, path)).read().count(old)
        if n != 1:
            bad += 1
            print(mid, 'pattern found', n, 'times:', rule)
    print(len(M), 'mutants,', bad, 'bad')


def worker(i, q, results, lock):
    work = f'{P}/F-synth-mut{i}'
    while True:
        try:
            mid, rule, path, old, new = q.get_nowait()
        except queue.Empty:
            return
        f = os.path.join(work, path)
        src = open(f).read()
        open(f, 'w').write(src.replace(old, new))
        try:
            r = subprocess.run(['bash', '-c', f'{ENV}; cd {work}; mix test --warnings-as-errors 2>&1'],
                               capture_output=True, text=True, timeout=1800)
            log = r.stdout + r.stderr
            open(os.path.join(OUT, mid + '.log'), 'w').write(log)
            failed = re.findall(r'^\s+\d+\) test (.*?) \((Logex[\w.]*)\)$', log, re.M)
            res = re.findall(r'^Result: .*$', log, re.M)
            warned = bool(re.search(r'^\s*warning:', log, re.M))
            row = {'id': mid, 'rule': rule, 'file': path, 'exit': r.returncode,
                   'result': res[-1] if res else 'no result line', 'compile_warning': warned,
                   'failed': [f'{mod} :: {t}' for t, mod in failed]}
            with lock:
                results.append(row)
                print(mid, r.returncode, row['result'], 'WARNING' if warned else '', flush=True)
        finally:
            open(f, 'w').write(src)


def run(only):
    os.makedirs(OUT, exist_ok=True)
    for i in range(WORKERS):
        work = f'{P}/F-synth-mut{i}'
        shutil.rmtree(work, ignore_errors=True)
        subprocess.run(['cp', '-a', W, work], check=True)
    q = queue.Queue()
    for row in M:
        if not only or row[0] in only:
            q.put(row)
    results, lock = [], threading.Lock()
    threads = [threading.Thread(target=worker, args=(i, q, results, lock)) for i in range(WORKERS)]
    for t in threads: t.start()
    for t in threads: t.join()
    results.sort(key=lambda r: int(r['id'][1:]))
    name = 'F-synth-mutation.json' if not only else 'F-synth-mutation-partial.json'
    json.dump(results, open(f'{P}/{name}', 'w'), indent=1)
    for i in range(WORKERS):
        shutil.rmtree(f'{P}/F-synth-mut{i}', ignore_errors=True)


if __name__ == '__main__':
    if sys.argv[1] == 'check':
        check()
    else:
        run(sys.argv[2:])
