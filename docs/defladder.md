# A `defladder` DSL for logex

A study of the `defladder` DSL, with a recommendation. September 2026.

## About this report

This report obeys ASD-STE100 Issue 9 (January 2025), the Simplified Technical English standard. These rules are the most important. Each sentence has a maximum of 25 words. Each paragraph has one topic and a maximum of six sentences. The text uses the active voice and the approved words from the STE dictionary. The word "must" shows that something is necessary.

STE lets a writer use technical nouns and technical verbs that are not in the dictionary (rules 1.5 and 1.12). The section "Technical nouns and technical verbs" gives the ones that this report uses. Code, file names and function names are in `code font`. STE counts each of these as one word (rule 8.6). STE also counts quoted text as one word.

A computer check of this report with the Issue 9 dictionary and the length rules found no errors. A computer cannot know if the meaning of a sentence is correct. Thus, the check gives a worklist. It does not make sure that the report is correct.

## Technical nouns and technical verbs

These words are technical nouns in this report: `ladder`, `logic`, `rung`, `contact`, `coil`, `branch`, `leg`, `jumper`, `power flow`, `scan`, `latch`, `timer`, `counter`, `tag`, `routine`, `program`, `instruction`, `operand`, `operator`, `mnemonic`, `dialect`, `syntax`, `vocabulary`, `grammar`, `lexer`, `parser`, `compiler`, `interpreter`, `evaluator`, `validator`, `backend`, `front end`, `pipeline`, `stage`, `token`, `line`, `column`, `file`, `module`, `function`, `macro`, `clause`, `argument`, `parameter`, `body`, `block`, `expression`, `call`, `arity`, `atom`, `tuple`, `list`, `map`, `key`, `string`, `integer`, `float`, `boolean`, `struct`, `node`, `tree`, `graph`, `AST`, `IR`, `DSL`, `API`, `Elixir`, `Erlang`, `BEAM`, `Nx`, `EXLA`, `Ecto`, `Absinthe`, `Hex`, `GitHub`, `README`, `defn`, `defladder`, `tensor`, `tensor shape`, `template`, `tracing`, `codegen`, `benchmark`, `nanosecond`, `millisecond`, `formatter`, `hygiene`, `metadata`, `diagnostic`, `warning`, `error`, `oracle`, `fixture`, `mutation`, `mutant`, `suite`, `sandbox`, `receipt`, `milestone`, `backlog`, `plan`, `design`, `precedent`, `survey`, `naming survey`, `stanza`, `standard`, `vendor`, `toolchain`, `maintainer`, `author`, `engineer`, `user`, `consumer`, `contributor`, `producer`, `judge`, `panel`, `phase`, `research`, `study`, `report`, `summary`, `scope`, `background`, `recommendation`, `refutation`, `refuter`, `synthesis`, `scorecard`, `risk`, `mitigation`, `snapshot`, `semantics`, `invariant`, `precedence`, `identifier`, `alias`, `variable`, `literal`, `member`, `access`, `remote`, `scheduler`, `process`, `CPU`, `computer`, `version`, `release`, `repository`, `commit`, `env`, `element`, `head`, `tail`, `nesting`, `depth`, `bit`, `byte`, `word`, `logex`, `IEC 61131-3`, `PLC`, `pyrung`, `Python`, `PLCopen`, `Beremiz`, `Structured Text`, `XML`, `ASCII`, `ASCII art`, `sentence`, `paragraph`, `rule`, `dictionary`, `text`, `section`, `topic`, `writer`, `noun`, `verb`, `language`, `kernel`, `definition`, `registration`, `behavior`, `default`, `statement`, `subject`, `criterion`, `criteria`, `winner`, `path`, `variant`, `parentheses`, `table`, `row`, `message`, `pattern`, `library`, `project`, `edition`, `dependency`, `worklist`, `September`, `August`, `January`, `seal-in`, `short-circuit`, `side effect`, `entry point`, `compile time`, `call time`, `numerical function`, `expression graph`, `tag map`, `operand count`, `scan limit`, `code font`, `twin`, `sentinel`, `regression`, `changelog`, `spike`, `driver`, `registry`, `equivalent`, `method`, `comment`, `letter`, `host`, `defect`, `delimiter`, `convention`, `document`, `fact`, `gate`, `issue`, `motor`, `hook`, `field`, `description`, `declaration`, `contract`, `doctest`, `domain`, `duplicate`, `edit`, `equality`, `equivalence`, `history`, `idiom`, `infix`, `native code`, `precondition`, `prerequisite`, `public`, `raw`, `recursive`, `scratch area`, `seeded`, `segment`, `session`, `spelling`, `upgrade`, `undeclared`, `undefined`, `unparenthesized`, `unreachable`, `differential test`, `archived`, `evaluation`, `just-in-time`, `post-expansion`, `parse-stage`, `compile-to-BEAM`, `OR-of-AND`, `producer-side`, `non-goal`, `DSL-only`, `lexer-derived`, `source-to-map`, `five-rung`, `two-line`, `one-millisecond`, `compile-time`, `special form`, `STE`, `ASD-STE100`, `Simplified Technical English`, `English`, `meaning`, `uppercase`, `open-source`, `bound variable`, `structure`, `location`, `type`, `command`, `score`, `series`.

These words are technical verbs in this report: `compile`, `parse`, `lex`, `tokenize`, `lower`, `evaluate`, `scan`, `trace`, `emit`, `walk`, `match`, `destructure`, `expand`, `format`, `import`, `export`, `pipe`, `flatten`, `nest`, `latch`, `unlatch`, `energize`, `de-energize`, `benchmark`, `commit`, `push`, `merge`, `declare`, `define`, `implement`, `execute`, `run`, `generate`, `validate`, `refute`, `escape`, `quote`, `unquote`, `rewrite`, `revert`, `register`, `interpret`, `short-circuit`, `invoke`, `assert`, `assemble`, `discard`.

## 1. Summary

Four words occur before the sections that give them. M1-1 to M1-6 and B1 to B9 are the items of the plan in `PLAN.md`. A receipt is the recorded output of a command that ran. The spike is the small test version of the DSL that this study made. A gate is the repository's word for a check that must give no error before a commit.

The DSL is correct in one design and not in the others. A `defladder` macro that reads its body as data and emits the logex AST is small, correct and important. The spike made it in 71 lines. Its output was the same as the output of the text front end in all 326 bytes. It gave compile errors with the user's file name and line. The text front end gives no file name and no line.

The parts of Nx that make `defn` different are not applicable. Nx traces at call time because the tensor shapes are unknown before that. A ladder routine has no tensor shapes. Thus, the macro knows the full routine at compile time, and there is no tracing, no kernel replacement, no compiler behavior and no just-in-time step. The name and the head structure come from Nx. The method is that of `Ecto.Query`.

The report gives two recommendations that are different from the recommendations of the design panel. First, put the DSL in the backlog as item B9, after M1-2 and M1-5, not in Milestone 1. A second front end with no consumer must come after the tag table, the `bit/2` correction and the public API. Second, write a parallel group as a call, `branch(leg, leg)`, not as an infix operator.

The infix operators `|||` and `|` each have a lower precedence than `|>`. Thus, an unparenthesized seal-in rung compiles with no warning to OR-of-AND, and the motor in the README example does not start. That is the defect type that `PLAN.md` §1 identifies as the most important, and that B1 must remove.

Two steps must occur before the DSL is in the repository. All receipts in this study come from Elixir 1.14 in the sandbox. Thus, the maintainer must do the runs of this study again on Elixir 1.15 or a subsequent version. And the maintainer must make the decisions that section 15 lists.

## 2. The task

The task was a study of one possible change to logex: add a `defladder` DSL that has the same design as `defn` in Nx. In Nx, the `defn` macro lets an author write a numerical function as Elixir code. Nx then makes a graph from that code and gives the graph to a compiler. The DSL for logex has the same structure. An author writes a ladder routine as Elixir code in a module. The `defladder` macro makes a logex routine from that code, and logex runs it.

The study had four tasks. Is a DSL correct for a ladder language? Which design must it have? Which effect does it have on the plan in `PLAN.md`? Is the DSL necessary in the repository, and if it is, when must a maintainer add it?

## 3. What logex is at this time

logex is a ladder logic compiler and interpreter in Elixir, with no dependencies. It reads a routine as text, for example `bst xic start nxb xic motor bnd xio stop ote motor`. The lexer (leex, `src/ladder_lexer.xrl`) makes tokens. The parser (yecc, `src/ladder_parser.yrl`) makes an AST.

`Logex.Compiler.instructionize/1` lowers the AST to an IR. `Logex.Compiler.evaluate/2` runs the IR with a tag map, one call for one scan. The language has six instructions: `xic`, `xio`, `ote`, `otl`, `otu` and `mov`. It has parallel branches to all depths.

Each operand in the AST is the lexer token, `{:name, line, "start"}` or `{:int_lit, line, 123}`. Milestone 1 item M1-1 (commit `a22bf39`) put the line in that position. Ten locations in `compiler.ex` read that position as `_`.

The suite has 27 tests. All of them give the correct result in the sandbox on Elixir 1.14.

Two facts about logex are important for this study. First, logex is a dialect that is different from all vendor dialects. `README.md` tells you that the vocabulary is a standard mnemonic set, but the syntax is different from all vendor syntaxes. It also tells you that logex will not become an importer of vendor formats.

Second, `PLAN.md` §6 keeps two behaviors. This is a decision, not an accident. Branches do not short-circuit, and thus a subsequent leg's `ote` and `mov` also run. The tag map goes through the legs in sequence, and thus a subsequent leg reads the value that a previous leg wrote.

## 4. What Nx `defn` does

The study read Nx v0.13.1 (the Hex release of 11 August 2026) and the `main` branch of 2 September 2026. Nx could not run on this computer, because Nx is only for Elixir 1.17 and subsequent versions, and the computer has Elixir 1.14. Thus, all facts in this section come from the Nx source and documents, not from a run.

`defn` is a macro. It expands to three parts: a registration call, a usual `def`, and a `Process.delete`. The body of that `def` starts with `use Nx.Defn.Kernel`. Elixir compiles that `def` first, as usual code. `use Nx.Defn.Kernel` removes `Kernel` (`import Kernel, only: []`) and imports the Nx kernel. The Nx kernel gives the operators `+ - * / &&& ||| <<< >>>` as functions, and `|>`, `if`, `while` and `raise` as macros.

At `@before_compile`, Nx gets each `defn` body again with `Module.get_definition/2`. At that time, Elixir has expanded the body fully. Nx compares the body with a list of permitted calls, erases the definition, and defines two new functions. One is the public entry point. The other contains the body and has the name `:"__defn:name__"`.

Nx does not make the graph at compile time. Nx makes the graph when the function runs. The Nx documents have this text: "defn functions are compiled when they are invoked, based on the type and shapes of the tensors given as arguments." At that time, Nx runs the body with parameter tensors, and each Nx operation makes an `Nx.Defn.Expr` node. This step is tracing. The `Nx.Defn.Compiler` behavior then gets the graph.

The default compiler, `Nx.Defn.Evaluator`, walks the graph and runs each node. The EXLA compiler makes native code from the same graph. A user selects the compiler with the `:compiler` key, or with `Nx.Defn.default_options/1`.

Three Nx facts are important for a ladder DSL. Nx traces at call time because the tensor shapes are unknown before that. Nx has no sequence of statements, and `io_call` is the one function with a side effect. In Nx, `and`, `or` and `cond` do not short-circuit, and `0` is `false`. The last fact is the same rule that logex keeps in `PLAN.md` §6.

## 5. Method

The study ran in three phases. In phase one, five research agents worked at the same time. Four agents each read one subject. The subjects were Nx `defn` from source, the limits of Elixir macros, the fit with the logex code and plan, and precedents in other languages. The last agent made the spike. All five agents gave a source or a run for each fact, and identified the facts for which they had no source and no run.

In phase two, three agents each made a design from a different position. The positions were a full Nx equivalent, the minimum macro that helps the author, and codegen first. Three judges then gave scores to the three designs with the same criteria. One more agent made one recommendation from the winner and from the parts of the other designs that it kept.

In phase three, two agents, the refuters, tried to refute that recommendation. One tried to show that logex must not add a second front end at this time. The other tried to find a program that the DSL and the text front end run differently. The author of this report then read all of the documents and made the last decisions in sections 9 and 15.

The panel had executed `|` and the spike had executed `|||`, but no one had executed `branch(...)`. Thus, the author then made the recommended syntax in the sandbox and ran it. Section 9 gives the result.

All runs in this study used the sandbox that `CONTRIBUTING.md` gives. The sandbox is a copy of the repository. Only the copy has a different Elixir version limit. No file in the repository changed. The spike code is in the scratch area, not in the repository.

## 6. What the spike showed

The spike made a `defladder` macro of 71 lines of code. The macro walks the quoted body at compile time and emits the logex AST. It reads `Logex.Compiler.instructions/0` at compile time. Thus, the DSL cannot use a mnemonic that the text dialect does not have. The parameters of the routine head are the declared tags. An operand that the head does not declare is a compile error.

The spike wrote the `README.md` motor example in the DSL:

```elixir
defmodule Logex.Examples.Motor do
  use Logex.Ladder

  defladder motor(start, stop, motor, run_lamp, overtemp, reset, fault, speed_sp) do
    rung (xic(start) ||| xic(motor)) |> xio(stop) |> ote(motor)
    rung xic(motor) |> ote(run_lamp)
    rung xic(overtemp) |> otl(fault)
    rung xic(reset) |> otu(fault)
    rung xic(fault) |> mov(0, speed_sp)
  end
end
```

The four scans of the README example gave the same output through the text front end and through the DSL. The output was the same in all 326 bytes. The AST from the two front ends was equal after the study removed the line numbers. The line numbers of the text front end are 1 to 5 of `motor.ld`. The line numbers of the DSL are 7 to 11 of `motor.ex`.

The DSL errors are clear. An unknown mnemonic gives `lib/logex/examples/bad_mnemonic.ex:5: unknown instruction xxc`. An incorrect operand count gives `ote takes 1 operand(s), got 0`. A tag that the head does not declare gives `undeclared tag strat`. Each error gives the user's file name and the line of the rung.

The text front end errors are not clear. The text front end gives `MatchError: no match of right hand side value: nil` for the first two errors, with no name and no line. The text front end gives no error for the third.

The spike also made a second variant of 79 lines. It emits one Elixir function for each rung, with no interpreter. Design 2, in section 8, is also 79 lines. The two counts are not related.

The study ran 100,000 scans of the five-rung routine, three times for each variant, on Elixir 1.14 with four schedulers. The interpreter used 525 nanoseconds for one scan. The generated code used 240 nanoseconds. The README driver, which lexes and parses the text on each scan, used 7,800 nanoseconds. Each result is less than 0.001 of the one-millisecond scan limit. Thus, speed is not a cause to select the generated code.

The second variant showed one difference in behavior. With `"start" => 1.0` in the tag map, the interpreter closes the contact, because it uses `==`. The generated code does not, because an Erlang pattern match uses `=:=`. The text dialect cannot write a float, but a host can put one in the map.

The design panel measured this with a seeded set of 20,000 tag maps. The two backends gave different results on 5,708 of them. On the maps that contain only integers, the only values that the text dialect can write, the two backends gave the same result. Thus, the suite in the repository cannot find this defect.

The spike found 13 syntax differences that a designer must know. Four of them are important. `|||` has a lower precedence than `|>`, and thus the seal-in rung must have parentheses: `(xic(start) ||| xic(motor)) |> xio(stop)`. An integer literal has no line metadata, and thus the literal gets the line of its instruction. `mix format` rewrites `rung xic(a) |> ote(b)` to `rung(xic(a) |> ote(b))`. Thus, `.formatter.exs` must have `locals_without_parens: [defladder: 2, rung: 1]`, and Nx does the same for `defn`.

The last of the four is nesting. A sequence of `|||` flattens to one group, but the text dialect can nest groups. The result is the same, because OR gives the same result for each nesting. But the two ASTs are different for that one nesting.

## 7. What the code and the plan permit

The Elixir parser cannot read the text dialect. `Code.string_to_quoted("xic start ote motor")` gives `xic(start(ote(motor)))`. Thus, a DSL is a different syntax with the same vocabulary. It cannot be the text syntax in Elixir.

The text vocabulary and the DSL vocabulary must stay the same. The only method for that in the repository is `Logex.Compiler.instructions/0`, the public mnemonic table. The naming survey test, `test/logex/naming_test.exs`, reads only that table. A DSL that gets its mnemonics from that table is in the survey with no more work. A DSL that writes its mnemonics as functions is not.

The same rule is applicable to tags. `Logex.Compiler.tokenize/1` is public. A DSL can give each head parameter to the lexer. The parameter is a tag only if the lexer gives one `name` token. Then a change to the lexer is also a change to the DSL, with no edit. The panel executed this with the lexer rule for `t1.dn` that is necessary for M1-6: `xic(t1.dn)` became permitted syntax, and `ladder.ex` did not change.

Some decisions in `PLAN.md` §5 have a different result in Elixir. Elixir parses `t1.dn` as a remote call, and `word.3` is a syntax error. Thus, the macro must rewrite the member access that is necessary for M1-6. Elixir parses `//` as a range step, and thus the DSL comment is `#`. An identifier with an uppercase first letter is an alias in Elixir, not a tag. A string operand, `xic("Start")`, keeps the uppercase letter.

The branch delimiters `( | )` of item B1 are not applicable to the DSL, because the Elixir parser reads the identifiers, not the logex lexer. The defect that B1 corrects cannot occur in the DSL. But an infix parallel operator makes a defect of the same type. Section 9 gives more information.

Two invariants from `PLAN.md` §6 are applicable to all DSL designs. Branches must not short-circuit, and the tag map must go through the legs in sequence. `PLAN.md` identifies the code pattern that does not obey the first invariant: "any form that puts evaluate on the right of or". That is the pattern that a codegen emits if it is not careful.

The test conventions are also applicable to the DSL. A correction must have a test that shows an error when you revert the correction. A mutation table must show that each test prevents the regression of the correction that it tests.

An oracle that compares the two ASTs is not sufficient. Two front ends that make the same incorrect IR are equal for that oracle. Only a test from source to tag map can find that error. That is the rule of `test/logex/end_to_end_test.exs`.

The public functions that a DSL uses at this time are `instructions/0` and `tokenize/1`. Backlog item B5 will change the recursive clauses of `instructionize/1` and `evaluate/2` to `defp`. Those two functions are not on the list of functions that the DSL uses. Thus, B5 has no effect on the DSL code.

## 8. The three designs

**Design 1, the full Nx equivalent.** The designer made it and ran it: 249 lines in five modules. A `Logex.Ladder.Kernel` replaces `Kernel` in the body. Thus, each tag is an Elixir variable, and `|>` is a function that the DSL defines. A `@before_compile` step gets the definition again, rewrites it and defines it again. A compiler behavior lets the user select `evaluate/2` or the codegen backend. The judges gave it 13, 13 and 12 points of 30.

The judges rejected Design 1 for four facts. Elixir 1.15 gives an error on an undefined variable before a hook runs. Thus, the "undeclared tag" message with the user's line is not possible on the repository's toolchain. A declared tag that the body does not use is a warning, and the gate `--warnings-as-errors` rejects it. `|` is an Elixir special form, and thus the kernel cannot import it. And the body that `Module.get_definition/2` gives is post-expansion, with the pipes gone.

**Design 2, the macro as a second parser.** One macro reads the body as data and emits the parse-stage AST. It defines no vocabulary. Mnemonics come from `instructions/0` and tags from `tokenize/1`, at compile time. It emits a `__define__` call and `def name(), do: <escaped AST>`, and no other code. It is 79 lines, plus 4 lines in `.formatter.exs`. All three judges selected it, with 25, 25 and 27 points.

**Design 3, codegen first.** The designer made the recommendation for generated code as complete as possible and then rejected it. The generated code and the interpreter are two definitions of a closed contact. They gave different results on 5,708 of 20,000 seeded tag maps. Each new instruction becomes a third location. That does not obey the rule in `PLAN.md` §6 that a new instruction does not change the front end. The judges gave it 17, 10 and 17 points.

Two parts of Design 3 stay in the recommendation: the two named mutants for the §6 tests, and the differential test.

## 9. Recommendation

**Accept the structure of Design 2.** That is one macro with no second vocabulary. Its output is the parse-stage AST with the caller's line in each operand. Do not make a codegen backend, a compiler behavior, a kernel replacement, a tracing step, or a just-in-time step. Section 10 gives the facts for each of these non-goals.

**Do not accept the position that the panel gave the DSL.** The panel put the DSL in Milestone 1, between M1-2 and M1-3. The argument of the first refuter is more important. The maintainer is one person, and a second front end with no named consumer must not be a second task at the same time. The DSL must come after the tag table (M1-3), the `bit/2` correction (M1-4) and the public API (M1-5).

The plan has the rule "each item is cheaper now than after the one below it lands". This rule is not applicable to the DSL. The work for the DSL does not increase with time, because its only necessary prerequisite, M1-1, is complete. The two preconditions in the next paragraph are not technical prerequisites. They are the sequence that keeps the DSL small.

Thus, record the DSL as backlog item B9, with the spike as its receipt. Its preconditions are M1-2 and M1-5. After M1-2, the macro has no validator. It gives the AST to the one validator of M1-2 and changes the first diagnostic into a `CompileError`. After M1-5, a `name/1` with a tag map as its argument can run one scan with `Logex.Runtime.scan/2`, and `Logex.compile/1` can also operate on an AST. Before then, the driver is the compiler stages with no other code, as in `README.md` at this time.

**Do not accept an infix parallel operator.** The panel selected `|`, and before it the spike used `|||`. The two have a lower precedence than `|>`. The rung `rung xic(start) | xic(motor) |> xio(stop) |> ote(motor)` compiles with no warning. It makes OR-of-AND, and the motor does not start.

The panel executed this. Its mitigation was a sentence in the documents and one test. That is not sufficient for the defect type that this repository identifies as the most important.

Write a parallel group as a call: `branch(leg, leg, ...)`. Each argument is one leg, and a leg is a series of pipes. `[]` is a jumper leg. The arguments of a call are in its parentheses. Thus, the call has no precedence relation with `|>`, and no other parentheses are necessary.

A call nests, and thus the DSL AST is equal to the text AST for a nested group. `branch` is the word that the text dialect uses for the group.

The seal-in rung then reads `rung branch(xic(start), xic(motor)) |> xio(stop) |> ote(motor)`.

**The syntax**, with the README example:

```elixir
defmodule Plant.Motor do
  import Logex.Ladder

  defladder motor(start, stop, motor, run_lamp, overtemp, reset, fault, speed_sp) do
    rung branch(xic(start), xic(motor)) |> xio(stop) |> ote(motor)
    rung xic(motor) |> ote(run_lamp)
    rung xic(overtemp) |> otl(fault)
    rung xic(reset) |> otu(fault)
    rung xic(fault) |> mov(0, speed_sp)
  end
end
```

The rules are these. The head parameters are the declared tags. `|>` is a series, and the macro flattens it with `Macro.unpipe/1`. The macro does not run the pipe as a function call.

`branch(...)` is a parallel group. `[]` is a jumper leg. An integer is a literal. A tag that is not a correct Elixir variable name is a string, in the head and in the body. After M1-6, the author can write `t1.dn` with no change. The author writes `word.3` as `xic("word.3")`.

The author executed this syntax after the panel. The macro with `branch(...)`, and without the M1-6 clause, is 57 lines of code plus the module documentation. Its README output was the same as the output of the text front end in each byte. Its AST was equal to the text AST after the removal of the line numbers. For a tag with an incorrect letter it gave `bad.ex:5: undeclared tag okk`. All gates gave no error.

More examples. Each has a text twin, the same rung in the text dialect:

```elixir
rung xic(aa) |> branch(xic(bb), xic(cc)) |> ote(res)   # xic aa bst xic bb nxb xic cc bnd ote res
rung branch(xic(aa), []) |> ote(xx)                     # bst xic aa nxb bnd ote xx
rung branch(xic(gg) |> ote(mm), xic(mm) |> ote(zz))    # bst xic gg ote mm nxb xic mm ote zz bnd
rung xic(run) |> ton(t1, 5000)                          # xic run ton t1 5000   (after M1-6)
rung xic(t1.dn) |> ote(heater)                          # xic t1.dn ote heater  (after M1-6)
```

**The method.** The macro emits a `__define__` call and `def name(), do: <escaped AST>`. `Macro.escape` is necessary, because a logex operand has the structure of an Elixir AST node but is not one. For the same cause, `Macro.prewalk` and `Macro.to_string` give a `FunctionClauseError` on the logex AST. Each tool and each test that walks the logex AST must have a walker for that AST. The author found this two times in this study.

The macro reads `instructions/0` and `tokenize/1` at compile time. Thus, a change to `compiler.ex` or to the lexer compiles each `defladder` module again. That is usual for a macro, and the maintainer must record it in `PLAN.md`.

The macro must have two clauses that reject nodes. Without them, `rung []` emits `{:rung, []}`, and `branch()` with no legs emits `{:branches, []}`. The text grammar cannot make these two nodes. The second node is dangerous. It gives power `false`, and thus `branch() |> ote(xx)` writes 0 with no error.

Thus, the macro must reject an empty rung and a `branch` with no legs. `branch([])` stays correct, because it is the jumper of the text `bst bnd`.

The line position contains the caller's integer line and no other data. The file and the module are facts of the routine, not of the operand. They are in M1-5's `%Logex.Program{source:}`. A literal gets the line of its instruction. If a rung continues on more than one line, each operand gets the line number of that operand.

The `branch` call has a line. It is the equivalent of the `bst` token line that the parser discards. That is the only DSL clause that the decision of M1-2 on the branches node changes.

Errors use `raise CompileError, file: __CALLER__.file, line: line, description: text`, with the line of the node, and not the line of the macro. A `when` head is an error with a line. A `__define__` call that runs before the `def` finds a second `defladder` with the same name and gives an error with a line. A declared tag that the body does not use is not a warning, because the `--warnings-as-errors` gate rejects an `IO.warn` from a macro. The panel executed that.

**The meaning of "Nx-style" after this study.** The name `defladder`, the head with declared inputs, the error text and the formatter idiom come from Nx. The compile pipeline does not. It is the `Ecto.Query` pipeline: match the raw AST, give an error with a line, and give data. This report makes this clear. Then a subsequent contributor will not "upgrade" the DSL to the Nx method. Section 8 gives the four facts that make that method incorrect here.

## 10. Nx methods and their `defladder` equivalents

| Nx method | `defladder` equivalent |
|---|---|
| `defn` macro: registration, a `def` with a replaced kernel, `Process.delete` | `defladder` reads the block as data and emits `__define__` plus `def name(), do: <AST>`. The body is not the body of a `def`. |
| Kernel replacement (`import Kernel, only: []`) | None. It is not necessary that a function or variable in the body is defined when the macro reads it as data. On Elixir 1.15, a bound-variable design gives an error on an undefined variable before a hook runs. |
| Tracing at call time | None. Nothing in the IR is unknown at compile time. The walk runs at compile time and does not run user code. |
| `Nx.Defn.Expr` graph | The logex AST and IR. They are rungs in sequence with side effects, not a graph. |
| `Nx.Defn.Compiler` behavior | None. logex has one backend. A behavior for one implementation is an unnecessary abstraction. The second backend gave different results on 5,708 of 20,000 maps. |
| `Nx.Defn.Evaluator` | `Logex.Compiler.evaluate/2`. It is a tree walker with one clause for each operation. After M1-5, `Logex.Runtime.scan/2`. |
| `jit`, `compile`, templates, tensor shape cache | None. There are no tensor shapes, and the macro does not wait for a call. "Compile once" is `name/0`, which gives data. |
| `deftransform` | The DSL uses usual Elixir at build time. User macros that assemble rungs are possible, but this plan does not include them. |
| `io_call`, hooks | A hook for each rung in the scan loop of M1-5, not in the DSL. |
| `print_expr` | `Plant.Motor.motor()` gives the routine as data. `instructionize/1` on it gives the IR. |
| `grad`, `custom_grad`, `stop_grad` | None. These are tensor-only graph rewrites. |
| `while` | None. The scan loop of M1-5, outside the routine, is the only related item. |
| `@before_compile` rewrite | The DSL does not use it. The definition that Nx reads again is post-expansion. The DSL keeps only `__define__`. |
| `compile_error!(meta, state, desc)` | The DSL keeps it with no change: `raise CompileError` with the node's line and the caller's file. |
| `.formatter.exs` with `locals_without_parens` and `export:` | The DSL keeps `[defladder: 2, rung: 1]`. |
| Non-short-circuit `and` and `or`, `0` is `false` | These are the §6 semantics of logex at this time. The DSL keeps them because it does not change `evaluate/2`. |

## 11. Effect on the plan

| Item | Effect |
|---|---|
| M1-1 (done) | The necessary prerequisite: a line in each operand. It is complete in commits `a22bf39` and `1b1b1df`. |
| M1-2 | Precondition of B9. After M1-2, remove the eight-line arity check of the macro and call the one validator. The decision of M1-2 on the branches node changes one DSL clause. |
| M1-3 | Add one sentence: a second declarer of tags will exist, and the DSL head can contain `start :: bool` as data. The head declarations must also be in the output by then, because `name/0` discards them at this time. |
| M1-4 | No effect. The correction is in the evaluator only. If the maintainer accepts a backend subsequently, `bit/2` must be public and `evaluate/2` must call it. |
| M1-5 | Precondition of B9. Add one sentence: `Logex.compile/1` must also operate on an AST, and `source:` must have a module variant. The doctest can contain the seal-in in the two spellings. |
| M1-6 | B9 has no dependency on M1-6. The `t1.dn` clause is six lines, and the maintainer merges it together with the lexer rule for `t1.dn`. When the maintainer merges the rule, change the sentinel test. |
| B1 | The fusion defect cannot occur in the DSL. After B1, `bst`, `nxb` and `bnd` become permitted tags in the two front ends with no DSL edit. The three lexer rules of B1 cause six errors in the DSL twin tests, and the mutation table of B1 must include them. |
| B3 | The yecc conflict check cannot examine Elixir precedence. With `branch(...)`, there is no precedence to examine. |
| B5 | No effect on the DSL code. Add `Logex.Ladder` to the module list, adjacent to `Parser`. |
| New B9 | The DSL, with the spike as its receipt and the preconditions above. |

## 12. Effect on the documents

`README.md`. The README sentence on the dialect stays with no change, because it is about the import of vendor formats. When the DSL is in the repository, the sentence "Source syntax today" becomes "The text front end today". A new section shows the module, the two-line driver and the four output lines from a run. The instruction table gets one sentence: in the DSL each row is `mnemonic(operands)`. Until the DSL is in the repository, `README.md` does not change.

`CLAUDE.md`. When the DSL is in the repository, add `lib/logex/ladder.ex` and the twin test file to the key files. Add three conventions. A new instruction changes two locations, as before, and no edit to the DSL is necessary. A DSL-only spelling is a language change and must have a text twin or a §5 decision. An edit to `compiler.ex` or the lexer compiles each `defladder` module again.

`PLAN.md`. At this time, add B9 to §4 with the preconditions, and add one sentence each to M1-3 and M1-5. Add one item to §6: logex does not compile to BEAM. This is a decision, and the 5,708 of 20,000 count is the cause. Do not change the §5 sentence on the dialect at this time. `CONTRIBUTING.md` tells you that a contributor must not examine §5 decisions again, and the DSL is not in the repository.

`docs/naming.md`. No change. The DSL mnemonics are the keys of `@instructions`, and thus the survey includes the two front ends. `rung`, `branch` and `[]` are syntax, as `bst` is, and no stanza is necessary for them.

`CONTRIBUTING.md`. When the DSL is in the repository, the format gate also examines `.formatter.exs`. When behavior changes, the twin test file is the second file that gets a new test.

## 13. Test plan

One new file, `test/logex/defladder_test.exs`, the twin of `end_to_end_test.exs`. Each routine is a module in the test file. The test runs it to a tag map with the same two calls that `run/2` makes. The panel made this file with 18 tests. The suite then had 45 tests (27 + 18), and all gates gave no error.

The oracle is source to tag map on the two spellings, from the same start map, and not IR equality. The panel showed the cause. Two front ends that make the same error, `xio` for `xic`, are equal in an IR equality check. The two give `motor = 0` for `start = 1`. Only a test from source to map finds that. A seeded differential test on the two spellings and some tag domains is the part that comes from Design 3.

The tests are these. The behavior twins have the §6 names with no change: "a later leg sees what an earlier leg wrote" and "parallel branches OR, and every branch still runs for its side effects". The seal-in runs for three scans. A nested group is an AND of an OR. The two jumper variants have text twins. `mov` runs with a literal and with a tag.

A producer-side line test asserts that the seal-in operands have the line `__ENV__.line + 5` and not `1`.

A vocabulary test makes a module with one rung for each key of `instructions/0` and compiles it. It gives an error if the walker gets a second table.

Error tests use `Code.compile_string` and `assert_raise CompileError` on the description, the file and the rung line. They include the unknown mnemonic, the arity, the undeclared tag and the head tag that is not correct. They also include the empty rung, the `when` head and the duplicate name.

A sentinel test asserts that `xic(t1.dn)` is an error until the lexer lexes it. When the maintainer merges the lexer rule, change the sentinel test to an equivalence test.

One more test asserts that `{:branches, []}` stays unreachable from the DSL. That node evaluates to `false`, and no text can make it. The test writes `branch()` and `rung []` and asserts a `CompileError` for each. The author found, in a run, that a macro without the two reject clauses emits these nodes.

The mutation table must have these rows, each mutation on a new copy of the code. Remove the `when` clause: one error. Remove the `__define__` call: one error. Put the caller's line on each operand in the walker: one error. Revert the lexer tag check: two errors. Remove the jumper clause: the test file does not compile.

Two more rows. Remove `rung: 1` from `.formatter.exs`: the format gate gives an error. Run the two §6 mutants from Design 3: each gives an error in only one of the two named tests.

## 14. Risks

1. **Toolchain difference.** All receipts are from Elixir 1.14 in the sandbox. The `CompileError` fields, `Code.compile_string`, and the AST metadata can be different on Elixir 1.15 and subsequent versions. The maintainer must do the runs of this study again on the repository's toolchain before B9 starts. Until then, each number in this report is a 1.14 number.

2. **A second producer of the AST.** The repository's history shows the problems that two producers cause. M0-1, the first item of Milestone 0, was two fixtures that gave different results, and the two gave no error. The mitigation is the vocabulary test, the lexer-derived tag check, and the source-to-map oracle on the two spellings.

3. **Two validators until M1-2.** Before M1-2, the macro has an arity check that M1-2 puts in `instructionize/1`. The mitigation is the B9 precondition.

4. **No document tests.** The second front end has output from a run and no test for that output. The mitigation is the M1-5 doctest with the two spellings.

5. **Compile-time dependency.** Each `defladder` module compiles again when `compiler.ex` or the lexer changes. For an Elixir program that uses logex, that is a full compile on each logex upgrade. The maintainer accepts this risk and records it.

6. **A grammar change that the lexer does not show.** Only a new walker clause can add a new structural token to the DSL. The result is an error, not an incorrect result with no error: `expected a tag or an integer literal`.

7. **The head declarations are not in the output.** `name/0` gives the AST and no other data. Thus, `defladder r(a, a, x)` compiles, and the tag table of M1-3 cannot read the declared tags. The mitigation is the M1-3 sentence in section 11.

8. **Nested group structure.** With `branch(...)`, the DSL AST nests as the text AST does. With an infix operator, a sequence of three legs flattens to one group. This is one more argument for the call.

9. **Nodes that the text grammar cannot make.** The minimum macro emits `{:rung, []}` for `rung []` and `{:branches, []}` for `branch()`. The second gives power `false` with no error. The mitigation is the two reject clauses in section 9 and the test in section 13. The author found this in a run, after the panel.

## 15. Decisions for the maintainer

1. Accept B9 in the backlog, with M1-2 and M1-5 as preconditions, and not the Milestone 1 position that the panel gave the DSL.

2. Accept `branch(leg, leg)` as the parallel spelling, and not the `|` of the panel. The DSL then has one more word of syntax, `branch`. The result is the removal of an OR-of-AND with no warning.

3. Make the decision: are the head declarations in the output at B9 or at M1-3? The study recommends B9. A `name/0` that discards the tags is a contract that M1-3 and M1-5 must then change.

4. Make the decision on the runs on Elixir 1.15 or a subsequent version. The study cannot do them on this computer. The rule of the repository is applicable. Install a new Elixir, or use a copy. Do not change the version limit in the `mix.exs` of the repository.

5. Make the decision on the name. The study recommends that the repository does not use "Nx-style" in its documents, because no Nx method stays in the design. `defladder` is a good name. It is not necessary to add "Nx-style" to it.

## 16. Precedents

The study found one precedent with changes in 2026: pyrung, a Python library, version 0.14.0 of 4 September 2026. pyrung writes a rung as `with rung(Start, ~Fault): out(Motor)`. It traces the body into an IR and interprets the IR. One rule of pyrung is different from logex. In pyrung, all conditions in a rung read a snapshot of the tags at the start of the rung. In logex, a subsequent leg reads the value that a previous leg wrote. The IEC standard gives the rung sequence and the OR of all legs, but it does not give that rule.

The study found no applicable Elixir precedent. One Elixir project, archived in 2020, parses ASCII art into an expression. Beremiz, the open-source PLC tool, compiles ladder to Structured Text, not to a host language.

PLCopen XML, at this time IEC 61131-10, has ladder as XML with contact and coil elements in the evaluation sequence. There is no standard ladder language in text. IEC 61131-3 Edition 4 (2025) removed Instruction List.

The Elixir document on DSLs gives the alternatives in this sequence: data first, then functions, then macros. It tells you that the macro path "is hard and expensive to test" and adds a compile-time dependency on the module of the macro. Nx, Ecto and Absinthe all use macros, each with a data structure as the result of the macro.

## 17. Sources

Repository files: `README.md`, `CLAUDE.md`, `CONTRIBUTING.md`, `PLAN.md` §1 to §8, `docs/naming.md`, `lib/logex/compiler.ex`, `src/ladder_lexer.xrl`, `src/ladder_parser.yrl`, `test/logex/*.exs`.

Nx:

- https://hexdocs.pm/nx/Nx.Defn.html (v0.13.1)
- https://hexdocs.pm/nx/Nx.Defn.Compiler.html
- https://hexdocs.pm/nx/Nx.Defn.Kernel.html
- https://hexdocs.pm/nx/Nx.Defn.Evaluator.html
- https://github.com/elixir-nx/nx/tree/main/nx/lib/nx/defn (commit `509da1b`, 2 September 2026)
- https://dashbit.co/blog/nx-numerical-elixir-is-now-publicly-available

Elixir:

- https://hexdocs.pm/elixir/operators.html
- https://hexdocs.pm/elixir/Macro.html
- https://hexdocs.pm/elixir/domain-specific-languages.html
- https://hexdocs.pm/elixir/macro-anti-patterns.html

Precedents and standards:

- https://github.com/ssweber/pyrung (v0.14.0)
- https://www.plcopen.org/standards/xml-echange/
- https://github.com/beremiz/matiec
- IEC 61131-3 Edition 2 §4.1.2, §4.1.3, §4.2.2 to §4.2.6 (Edition 3 §8.2.7)
- https://arxiv.org/abs/2606.15461 (ESBMC-PLC)

Simplified Technical English:

- https://www.asd-ste100.org/ (Issue 9, 15 January 2025)

Study documents, in the scratch area of the session and not in the repository:

- the five research reports
- the spike, `defladder/spike/`
- the three designs, the three scorecards, the synthesis and the two refutations
- the twin test file of the panel, `defladder/syn/test/logex/defladder_test.exs`
