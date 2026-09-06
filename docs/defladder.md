# A `defladder` DSL for logex

A study of the idea, with a recommendation. September 2026.

## About this report

This report obeys ASD-STE100 Issue 9 (January 2025), the Simplified Technical English standard. These rules apply most. Each sentence has a maximum of 25 words. Each paragraph has one topic and a maximum of six sentences. The text uses the active voice and the approved words from the STE dictionary. The word "must" shows a requirement.

STE lets a writer use technical nouns and technical verbs that are not in the dictionary (rules 1.5 and 1.12). The section "Technical nouns and technical verbs" gives the ones that this report uses. Code, file names and function names are in `code font`. STE counts each of these as one word (rule 8.6). STE also counts quoted text as one word.

A machine check of this report against the Issue 9 dictionary and the length rules found no errors. A machine cannot tell if a sentence is correct in its sense. Thus, the check is a worklist, not a guarantee.

## Technical nouns and technical verbs

These words are technical nouns in this report: `ladder`, `logic`, `rung`, `contact`, `coil`, `branch`, `leg`, `jumper`, `power flow`, `scan`, `latch`, `timer`, `counter`, `tag`, `routine`, `program`, `instruction`, `operand`, `operator`, `mnemonic`, `dialect`, `syntax`, `vocabulary`, `grammar`, `lexer`, `parser`, `compiler`, `interpreter`, `evaluator`, `validator`, `backend`, `front end`, `pipeline`, `stage`, `token`, `line`, `column`, `file`, `module`, `function`, `macro`, `clause`, `argument`, `parameter`, `body`, `block`, `expression`, `call`, `site`, `arity`, `atom`, `tuple`, `list`, `map`, `key`, `string`, `integer`, `float`, `boolean`, `struct`, `node`, `tree`, `graph`, `AST`, `IR`, `DSL`, `API`, `Elixir`, `Erlang`, `BEAM`, `Nx`, `EXLA`, `Ecto`, `Absinthe`, `Hex`, `GitHub`, `README`, `defn`, `defladder`, `tensor`, `shape`, `template`, `tracing`, `codegen`, `benchmark`, `nanosecond`, `millisecond`, `formatter`, `hygiene`, `metadata`, `diagnostic`, `warning`, `error`, `oracle`, `fixture`, `mutation`, `mutant`, `suite`, `sandbox`, `receipt`, `milestone`, `backlog`, `plan`, `design`, `precedent`, `survey`, `naming survey`, `stanza`, `standard`, `vendor`, `toolchain`, `maintainer`, `author`, `engineer`, `user`, `consumer`, `contributor`, `producer`, `judge`, `panel`, `lens`, `phase`, `research`, `study`, `idea`, `report`, `summary`, `scope`, `purpose`, `background`, `question`, `recommendation`, `refutation`, `refuter`, `synthesis`, `scorecard`, `risk`, `mitigation`, `sequence`, `series`, `snapshot`, `semantics`, `invariant`, `precedence`, `identifier`, `alias`, `variable`, `literal`, `member`, `access`, `remote`, `scheduler`, `process`, `CPU`, `machine`, `version`, `release`, `repository`, `commit`, `state`, `env`, `element`, `head`, `tail`, `nesting`, `depth`, `bit`, `byte`, `word`, `logex`, `IEC 61131-3`, `PLC`, `pyrung`, `Python`, `PLCopen`, `Beremiz`, `Structured Text`, `XML`, `ASCII`, `ASCII art`, `sentence`, `paragraph`, `rule`, `dictionary`, `text`, `section`, `topic`, `requirement`, `writer`, `noun`, `verb`, `language`, `kernel`, `definition`, `registration`, `behavior`, `default`, `statement`, `subject`, `criterion`, `criteria`, `winner`, `graft`, `score`, `path`, `variant`, `budget`, `parentheses`, `table`, `row`, `message`, `pattern`, `library`, `project`, `edition`, `dependency`, `worklist`, `guarantee`, `September`, `August`, `January`, `seal-in`, `short-circuit`, `side effect`, `entry point`, `compile time`, `call time`, `numerical function`, `expression graph`, `tag map`, `operand count`, `scan budget`, `code font`, `twin`, `sentinel`, `regression`, `changelog`, `spike`, `driver`, `registry`, `analogue`, `mechanism`, `comment`, `letter`, `host`, `defect`, `class`, `delimiter`, `convention`, `document`, `answer`, `fact`, `evidence`, `capital`, `cost`, `gate`, `bound`, `issue`, `motor`, `hook`, `field`, `description`, `declaration`, `contract`, `doctest`, `domain`, `duplicate`, `edit`, `equality`, `equivalence`, `history`, `identity`, `idiom`, `infix`, `native code`, `precondition`, `prerequisite`, `public`, `raw`, `recursive`, `scratch area`, `seeded`, `segment`, `session`, `skew`, `spelling`, `stance`, `upgrade`, `undeclared`, `undefined`, `unparenthesized`, `unreachable`, `legal`, `silent`, `explicit`, `differential test`, `style`, `archived`, `evaluation`, `measurement`, `debt`, `just-in-time`, `post-expansion`, `parse-stage`, `compile-to-BEAM`, `OR-of-AND`, `producer-side`, `non-goal`, `DSL-only`, `lexer-derived`, `source-to-map`, `five-rung`, `two-line`, `one-millisecond`, `compile-time`, `special form`, `objection`, `STE`, `ASD-STE100`, `Simplified Technical English`, `English`, `simple`.

These words are technical verbs in this report: `compile`, `parse`, `lex`, `tokenize`, `lower`, `evaluate`, `scan`, `trace`, `emit`, `walk`, `match`, `destructure`, `expand`, `format`, `import`, `export`, `pipe`, `flatten`, `nest`, `thread`, `latch`, `unlatch`, `energize`, `de-energize`, `benchmark`, `commit`, `push`, `merge`, `map`, `key`, `declare`, `define`, `implement`, `execute`, `run`, `generate`, `validate`, `refute`, `escape`, `quote`, `unquote`, `rewrite`, `revert`, `cite`, `register`, `interpret`, `short-circuit`, `invoke`, `score`, `gate`, `pin`, `land`, `own`, `say`, `assert`, `relax`, `attack`, `argue`.

## 1. Summary

The idea is correct in one shape and not in the others. A `defladder` macro that reads its body as data and emits logex's own AST is small, correct and of value. The spike made it in 71 lines. It gave output equal to the text path to the byte. It gave compile errors with the user's file and line, where the text path gives no name and no line.

The parts of Nx that give `defn` its identity do not apply. Nx traces at call time because the tensor shapes are unknown before that. A ladder routine has no shapes, so the macro knows the full routine at compile time. Thus, there is no tracing, no kernel replacement, no compiler behavior and no just-in-time step. The name and the head shape come from Nx. The mechanism is that of `Ecto.Query`.

The report gives two recommendations that are different from the design panel. First, put the DSL in the backlog as item B9, after M1-2 and M1-5, not in Milestone 1. A second surface with no consumer must not go before the tag table, the `bit/2` correction and the public API. Second, write a parallel group as an explicit call, `branch(leg, leg)`, not as an infix operator.

The infix operators `|||` and `|` both have a lower precedence than `|>`. Thus, an unparenthesized seal-in rung compiles with no warning to OR-of-AND, and the motor does not start. That is the defect class that `PLAN.md` §1 puts first and that B1 must remove.

Two steps must occur before any line of the DSL goes into the repository. All receipts in this study come from Elixir 1.14 in the sandbox. Thus, the study must run again on Elixir 1.15 or a subsequent version. The repository's own toolchain rule, "never relax `mix.exs`", applies to that run.

## 2. The question

The task was a study of one idea: add a `defladder` DSL to logex, in the style of Nx. In Nx, the `defn` macro lets an author write a numerical function as Elixir code. Nx then makes a graph from that code and gives the graph to a compiler. The idea for logex has the same shape. An author writes a ladder routine as Elixir code in a module. The `defladder` macro makes a logex routine from that code, and logex runs it.

The study had to give four answers. Is the idea correct for a ladder language? Which shape must it have? Which effect does it have on the plan in `PLAN.md`? When must it go into the repository, if at all?

## 3. What logex is at this time

logex is a ladder logic compiler and interpreter in Elixir, with no dependencies. It reads a routine as text, for example `bst xic start nxb xic motor bnd xio stop ote motor`. The lexer (leex, `src/ladder_lexer.xrl`) makes tokens. The parser (yecc, `src/ladder_parser.yrl`) makes an AST.

`Logex.Compiler.instructionize/1` lowers the AST to an IR. `Logex.Compiler.evaluate/2` runs the IR against a tag map, one call for one scan. The language has six instructions: `xic`, `xio`, `ote`, `otl`, `otu` and `mov`. It has parallel branches to all depths.

Each operand in the AST is the lexer token, `{:name, line, "start"}` or `{:int_lit, line, 123}`. Milestone 1 item M1-1 (commit `a22bf39`) put the line in that slot. Ten sites in `compiler.ex` read the slot as `_`.

The suite has 27 tests. All of them give the correct result in the sandbox on Elixir 1.14.

Two facts about logex are important for this study. First, logex is its own dialect. `README.md` says that the vocabulary is a standard mnemonic set, but the syntax is logex's own. It also says that logex will not become an importer of vendor formats.

Second, `PLAN.md` §6 keeps two behaviors on purpose. Branches do not short-circuit, so a subsequent leg's `ote` and `mov` also run. The tag map threads through the legs in sequence, so a subsequent leg sees the value that a previous leg wrote.

## 4. What Nx `defn` does

The study read Nx v0.13.1 (Hex release of 11 August 2026) and the `main` branch of 2 September 2026. Nx could not run on this machine, because Nx is only for Elixir 1.17 and subsequent versions, and the machine has Elixir 1.14. Thus, all facts in this section come from the Nx source and documents, not from a run.

`defn` is a macro. It expands to three parts: a registration call, a usual `def`, and a `Process.delete`. The body of that `def` starts with `use Nx.Defn.Kernel`. Elixir compiles that `def` first, as usual code. `use Nx.Defn.Kernel` removes `Kernel` (`import Kernel, only: []`) and imports Nx's own kernel. Nx's kernel gives the operators `+ - * / &&& ||| <<< >>>` as functions, and `|>`, `if`, `while` and `raise` as macros.

At `@before_compile`, Nx gets each `defn` body again with `Module.get_definition/2`. At this point, Elixir has expanded the body fully. Nx examines the body against a list of permitted calls, erases the definition, and defines two new functions. One is the public entry point. The other holds the body and has the name `:"__defn:name__"`.

Nx does not make the graph at compile time. Nx makes the graph when the function runs. The Nx documents say: "defn functions are compiled when they are invoked, based on the type and shapes of the tensors given as arguments." At that time, Nx applies the body to parameter tensors, and each Nx operation makes an `Nx.Defn.Expr` node. This step is tracing. The `Nx.Defn.Compiler` behavior then gets the graph.

The default compiler, `Nx.Defn.Evaluator`, walks the graph and runs each node. The EXLA compiler makes native code from the same graph. A user selects the compiler with the `:compiler` alternative, or with `Nx.Defn.default_options/1`.

Three Nx facts are important for a ladder DSL. Nx traces at call time because the tensor shapes are not known before that. Nx has no sequence of statements and no side effects, and only `io_call` is different. In Nx, `and`, `or` and `cond` do not short-circuit, and `0` is `false`. The last fact is the same rule that logex keeps in `PLAN.md` §6.

## 5. Method

The study ran in three phases. In phase one, five research agents worked at the same time. Four agents each read one subject. The subjects were Nx `defn` from source, the limits of Elixir macros, the fit with the logex code and plan, and precedents in other languages. The last agent made a spike. All five had to give cited or executed evidence and to mark the facts that they did not make sure of.

In phase two, three agents each made a design from a different position. The positions were a full Nx analogue, the minimum macro of value, and codegen first. Three judges then gave scores to the three designs against the same criteria. One more agent made one recommendation from the winner and the grafts.

In phase three, two agents attacked that recommendation. One argued that logex must not add a second front end at this time. The other looked for a program that the DSL and the text path run differently. The author of this report then read all of the material and made the last decisions in sections 9 and 15.

All runs in this study used the sandbox that `CONTRIBUTING.md` gives. The sandbox is a copy of the repository with the Elixir bound relaxed in the copy only. No file in the repository changed. The spike code is in the scratch area, not in the repository.

## 6. What the spike showed

The spike made a `defladder` macro of 71 lines of code. The macro walks the quoted body at compile time and emits logex's own AST. It reads `Logex.Compiler.instructions/0` at compile time. Thus, the DSL cannot use a mnemonic that the text dialect does not have. The parameters of the routine head are the declared tags. An operand that is not a declared tag is a compile error.

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

The four scans of the README example gave the same output through the text path and through the DSL. The output was the same to the byte, 326 bytes each. The AST from the two paths was equal after the study removed the line numbers. The text path cites lines 1 to 5 of `motor.ld`. The DSL cites lines 7 to 11 of `motor.ex`.

The DSL gives clearer errors than the text path. A bad mnemonic gives `lib/logex/examples/bad_mnemonic.ex:5: unknown instruction xxc`. An incorrect operand count gives `ote takes 1 operand(s), got 0`. A tag that is not declared gives `undeclared tag strat`. Each error names the user's file and the line of the rung.

The text path gives `MatchError: no match of right hand side value: nil` for the first two errors, with no name and no line. The text path gives no error at all for the third.

The spike also made a second variant of 79 lines. It emits one Elixir function for each rung, with no interpreter. The study ran 100,000 scans of the five-rung routine, three times for each variant, on Elixir 1.14 with four schedulers. The interpreter used 525 nanoseconds for one scan. The generated code used 240 nanoseconds. The README shape, which lexes and parses on each scan, used 7,800 nanoseconds.

Each result is more than 1,000 times below a one-millisecond scan budget. Thus, speed is not a cause to select the generated code.

The second variant showed one difference in behavior. With `"start" => 1.0` in the tag map, the interpreter closes the contact, because it uses `==`. The generated code does not, because an Erlang pattern match uses `=:=`. The text dialect cannot write a float, but a host can put one in the map.

The design panel measured this with a seeded set of 20,000 tag maps. The two backends gave different results on 5,708 of them, and on 0 of the maps that the text dialect can make. Thus, the suite in the repository cannot see this defect at any time.

The spike found 13 syntax differences that a designer must know. Four of them are important. `|||` has a lower precedence than `|>`, so the seal-in rung must have parentheses: `(xic(start) ||| xic(motor)) |> xio(stop)`. An integer literal has no line metadata, so the literal gets the line of its instruction. `mix format` rewrites `rung xic(a) |> ote(b)` to `rung(xic(a) |> ote(b))`. Thus, `.formatter.exs` must have `locals_without_parens: [defladder: 2, rung: 1]`, and Nx does the same for `defn`.

The last of the four is nesting. A sequence of `|||` flattens to one group, but the text dialect can nest groups. The sense is the same, because OR gives the same result for all groups. But the two ASTs are different for that one shape.

## 7. What the code and the plan permit

The Elixir parser cannot read the text dialect. `Code.string_to_quoted("xic start ote motor")` gives `xic(start(ote(motor)))`. Thus, a DSL is a different syntax over the same vocabulary. It cannot be the text syntax in Elixir.

The text vocabulary and the DSL vocabulary must stay the same. The only mechanism for that in the repository is `Logex.Compiler.instructions/0`, the public mnemonic table. The naming survey test, `test/logex/naming_test.exs`, reads only that table. A DSL that gets its mnemonics from that table is under the survey at no cost. A DSL that writes its mnemonics as functions is not.

The same rule applies to tags. `Logex.Compiler.tokenize/1` is public. A DSL can give each head parameter to the lexer. The parameter is a tag only if the lexer gives one `name` token. Then a change to the lexer applies to the DSL with no edit. The panel executed this with the `QUALIFIED` rule that is necessary for M1-6: `xic(t1.dn)` became legal, and `ladder.ex` did not change.

Some decisions in `PLAN.md` §5 have a different result in Elixir. Elixir parses `t1.dn` as a remote call, and `word.3` is a syntax error. Thus, the macro must rewrite the member access that is necessary for M1-6. Elixir parses `//` as a range step, so the DSL comment is `#`. An identifier with a capital first letter is an alias in Elixir, not a tag. A string operand, `xic("Start")`, keeps the capital letter.

The branch delimiters `( | )` of item B1 do not apply to the DSL, because Elixir owns the identifiers. The defect that B1 corrects cannot occur in the DSL. But an infix parallel operator makes a defect of the same class. Section 9 says more.

Two invariants from `PLAN.md` §6 apply to all DSL designs. Branches must not short-circuit, and the tag map must thread through the legs in sequence. `PLAN.md` names the code shape that breaks the first one: "any form that puts evaluate on the right of or". That is the shape that a simple codegen emits.

The test conventions apply to the DSL too. A correction must have a test that shows an error when you revert the correction. A mutation table must show that each test prevents its own regression.

An oracle that compares the two ASTs is not sufficient. Two front ends that make the same incorrect IR are equal under that oracle. Only a test from source to tag map can see that error. That is the rule of `test/logex/end_to_end_test.exs`.

The public functions that a DSL uses at this time are `instructions/0` and `tokenize/1`. Backlog item B5 will close the recursive clauses of `instructionize/1` and `evaluate/2`. Those two functions are not on that list, so B5 has no cost for the DSL.

## 8. The three designs

**Design 1, the full Nx analogue.** The designer made it and ran it: 249 lines in five modules. A `Logex.Ladder.Kernel` replaces `Kernel` in the body, so each tag is an Elixir variable and `|>` is the DSL's own function. A `@before_compile` step gets the definition again, rewrites it and defines it again. A compiler behavior lets `evaluate/2` and the codegen backend replace each other. The judges gave it 13, 13 and 12 points of 30.

The judges rejected Design 1 for four facts. Elixir 1.15 gives an error on an undefined variable before any hook runs. Thus, the "undeclared tag" message with the user's line is not possible on the repository's toolchain. A declared tag that the body does not use is a warning, and the gate `--warnings-as-errors` rejects it. `|` is an Elixir special form, so the kernel cannot import it. And the body that `Module.get_definition/2` gives back is post-expansion, with the pipes gone.

**Design 2, the macro as a second parser.** One macro reads the body as data and emits the parse-stage AST. It owns no vocabulary. Mnemonics come from `instructions/0` and tags from `tokenize/1`, both at compile time. It emits `def name(), do: <escaped AST>` and no other code. It is 79 lines, plus 4 lines in `.formatter.exs`. All three judges selected it, with 25, 25 and 27 points.

**Design 3, codegen first.** The designer made the recommendation for generated code as complete as possible and then rejected it. The generated code and the interpreter are two definitions of "closed". They gave different results on 5,708 of 20,000 seeded tag maps. Each new instruction becomes a third site, against the rule in `PLAN.md` §6 that a new instruction does not touch the front end. The judges gave it 17, 10 and 17 points. Its grafts stay: the two named mutants for the §6 tests, and the differential test.

## 9. Recommendation

**Accept the shape of Design 2.** One macro, no vocabulary of its own, the parse-stage AST as output, and the caller's line in each operand. Do not make a codegen backend, a compiler behavior, a kernel replacement, a tracing step, or a just-in-time step. Section 10 gives the evidence for each of these non-goals.

**Do not accept the panel's slot.** The panel put the DSL in Milestone 1, between M1-2 and M1-3. The first refuter's argument has more weight. A second surface with no named consumer must not become the second task of one maintainer. It must not go before the tag table (M1-3), the `bit/2` correction (M1-4) and the public API (M1-5).

The plan's own rule is "each item is cheaper now than after the one below it lands". The DSL does not become more costly with time, because its only hard prerequisite, M1-1, is complete.

Thus, record the DSL as backlog item B9, with the spike as its receipt. Its preconditions are M1-2 and M1-5. After M1-2, the macro has no validator of its own. It gives the AST to the one validator and changes the first diagnostic into a `CompileError`. After M1-5, `name/1` can run one scan through `Logex.Runtime.scan/2`, and `Logex.compile/1` can accept an AST. Before then, the driver is the bare compiler stages, as in `README.md` at this time.

**Do not accept an infix parallel operator.** The panel selected `|`, and before it the spike used `|||`. Both have a lower precedence than `|>`. The rung `rung xic(start) | xic(motor) |> xio(stop) |> ote(motor)` compiles with no warning. It makes OR-of-AND, and the motor does not start.

The panel executed this. Its mitigation was documents and one test. That is not sufficient for the defect class that this repository puts first.

Write a parallel group as a call: `branch(leg, leg, ...)`. Each argument is one leg, and a leg is a series of pipes. `[]` is a jumper leg. A call has no precedence, so no parentheses are necessary for a correct result. A call nests, so the DSL AST is equal to the text AST for a nested group. The name `branch` is the text dialect's own word for the group.

The seal-in rung then reads `rung branch(xic(start), xic(motor)) |> xio(stop) |> ote(motor)`.

**The last surface syntax**, with the README example:

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

The rules are these. The head parameters are the declared tags. `|>` is a series, and the macro flattens it with `Macro.unpipe/1`. The macro does not apply the pipe as a function call.

`branch(...)` is a parallel group. `[]` is a jumper leg. An integer is a literal.

A tag that is not a legal Elixir variable is a string, in the head and in the body. After M1-6, `t1.dn` is legal as it is. The author writes `word.3` as `xic("word.3")`.

More examples, each with its text twin:

```elixir
rung xic(aa) |> branch(xic(bb), xic(cc)) |> ote(res)   # xic aa bst xic bb nxb xic cc bnd ote res
rung branch(xic(aa), []) |> ote(xx)                     # bst xic aa nxb bnd ote xx
rung branch(xic(gg) |> ote(mm), xic(mm) |> ote(zz))    # bst xic gg ote mm nxb xic mm ote zz bnd
rung xic(run) |> ton(t1, 5000)                          # xic run ton t1 5000   (after M1-6)
rung xic(t1.dn) |> ote(heater)                          # xic t1.dn ote heater  (after M1-6)
```

**The mechanism.** The macro emits `def name(), do: <escaped AST>`. `Macro.escape` is necessary, because a logex operand has the shape of an Elixir AST node but is not one. The macro reads `instructions/0` and `tokenize/1` at compile time. Thus, a change to `compiler.ex` or to the lexer compiles each `defladder` module again. That is the usual cost of a macro, and the repository must record it.

The line slot holds the caller's integer line and no other data. File and module are facts of the routine, not of the operand. They go on M1-5's `%Logex.Program{source:}`. A literal gets the line of its instruction. A rung on more than one line gets a line for each segment.

The `branch` call has a line. It is the analogue of the `bst` token line that the parser drops. That is the one point where M1-2's open decision on the branches node touches the DSL.

Errors use `raise CompileError, file: __CALLER__.file, line: line, description: text`, with the line of the node, and not the line of the macro. A `when` head is an error with a line. A second `defladder` with the same name is an error with a line, through a `__define__` call that runs before the `def`. A declared tag that the body does not use is not a warning, because the `--warnings-as-errors` gate rejects an `IO.warn` from a macro. The panel executed that.

**The sense of "Nx-style" after this study.** The name `defladder`, the head with declared inputs, the error style and the formatter idiom come from Nx. The compile pipeline does not. It is the `Ecto.Query` pipeline: match the raw AST, give an error with a line, and give back data. The report says this clearly so that a subsequent contributor does not "upgrade" the DSL to the Nx mechanism. Section 8 gives the four facts that make that mechanism incorrect here.

## 10. Nx mechanisms and their `defladder` analogues

| Nx mechanism | `defladder` analogue |
|---|---|
| `defn` macro: registration, a real `def` under a replaced kernel, `Process.delete` | `defladder` reads the block as data and emits `__define__` plus `def name(), do: <AST>`. There is no real `def` of the body. |
| Kernel replacement (`import Kernel, only: []`) | None. No part of the body has to exist when the macro reads it as data. On Elixir 1.15, a bound-variable design gives an error on an undefined variable before any hook. |
| Tracing at call time | None. The IR depends on nothing that is unknown at compile time. The walk runs at compile time and does not run user code. |
| `Nx.Defn.Expr` graph | logex's AST and IR. They are rungs in sequence with side effects, not a graph. |
| `Nx.Defn.Compiler` behavior | None. logex has one backend. A behavior for one implementation is an unnecessary abstraction. The second backend gave different results on 5,708 of 20,000 maps. |
| `Nx.Defn.Evaluator` | `Logex.Compiler.evaluate/2`. It is already a tree walker with one clause for each operation. After M1-5, `Logex.Runtime.scan/2`. |
| `jit`, `compile`, templates, shape cache | None. There are no shapes and nothing to wait for. "Compile once" is `name/0`, which gives back data. |
| `deftransform` | Usual Elixir at build time. User macros that compose rungs are possible but deferred. |
| `io_call`, hooks | An observation point for each rung in the scan loop of M1-5, not in the DSL. |
| `print_expr` | `Plant.Motor.motor()` gives the routine as data. `instructionize/1` on it gives the IR. |
| `grad`, `custom_grad`, `stop_grad` | None. These are tensor-only graph rewrites. |
| `while` | None. The nearest shape is the scan loop of M1-6, outside the routine. |
| `@before_compile` rewrite | Not used. The definition that Nx reads back is post-expansion. Only `__define__` is kept. |
| `compile_error!(meta, state, desc)` | Kept as it is: `raise CompileError` with the node's line and the caller's file. |
| `.formatter.exs` with `locals_without_parens` and `export:` | Kept: `[defladder: 2, rung: 1]`. |
| Non-short-circuit `and` and `or`, `0` is `false` | These are already the §6 semantics of logex. The DSL keeps them because it does not touch `evaluate/2`. |

## 11. Effect on the plan

| Item | Effect |
|---|---|
| M1-1 (done) | The hard prerequisite: a line in each operand. Complete in `a22bf39` and `1b1b1df`. |
| M1-2 | Precondition of B9. After M1-2, the macro removes its eight-line arity check and calls the one validator. M1-2's open decision on the branches node touches one DSL clause. |
| M1-3 | Add one sentence: a second declarer of tags will exist, and the DSL head can hold `start :: bool` as data. The head declarations must also go into the output by then, because `name/0` discards them at this time. |
| M1-4 | No cost. The correction is in the evaluator only. If a backend is admitted at some time, `bit/2` must be public and `evaluate/2` must call it. |
| M1-5 | Precondition of B9. Add one sentence: `Logex.compile/1` must accept an AST, and `source:` must have a module variant. The doctest can hold the seal-in in both spellings. |
| M1-6 | No dependency. The `t1.dn` clause is six lines and lands with the `QUALIFIED` lexer rule. A sentinel test changes when the rule lands. |
| B1 | The fusion defect cannot occur in the DSL. After B1, `bst`, `nxb` and `bnd` become legal tags in both front ends with no DSL edit. B1's three lexer rules cause six errors in the DSL twin tests, and B1 must count them. |
| B3 | The yecc conflict gate cannot see Elixir precedence. With `branch(...)`, there is no precedence to see. |
| B5 | No cost. Add `Logex.Ladder` to the module list as a peer of `Parser`. |
| New B9 | The DSL, with the spike as receipt and the preconditions above. |

## 12. Effect on the documents

`README.md`. The dialect stance stays as it is, because it is about the import of vendor formats. When the DSL lands, the sentence "Source syntax today" becomes "The text surface today". A new section shows the module, the two-line driver and the four output lines from a run. The instruction table gets one sentence: in the DSL each row is `mnemonic(operands)`. Until the DSL lands, `README.md` does not change.

`CLAUDE.md`. When the DSL lands, add `lib/logex/ladder.ex` and the twin test file to the key files. Add three conventions. A new instruction touches two sites, as before, and no edit to the DSL is necessary. A DSL-only spelling is a language change and must have a text twin or a §5 decision. An edit to `compiler.ex` or the lexer compiles each `defladder` module again.

`PLAN.md`. At this time, add B9 to §4 with the preconditions, and add one sentence each to M1-3 and M1-5. Add one item to §6: compile-to-BEAM is not done, on purpose, with the 5,708 of 20,000 count. Do not change the §5 identity sentence at this time. `CONTRIBUTING.md` says that a contributor must not open §5 decisions again, and the DSL has not landed.

`docs/naming.md`. No change. The DSL mnemonics are the keys of `@instructions`, so the survey applies to both surfaces. `rung`, `branch` and `[]` are syntax, as `bst` is, and no stanza is necessary for them.

`CONTRIBUTING.md`. When the DSL lands, the format gate also examines `.formatter.exs`. The twin test file is the second file to add to when behavior changes.

## 13. Test plan

One new file, `test/logex/defladder_test.exs`, the twin of `end_to_end_test.exs`. Each routine is a module in the test file. The test runs it to a tag map through the same two calls that `run/2` makes. The panel made this file with 18 tests, and all gates gave no error with 45 tests.

The oracle is source to tag map on both spellings, from the same start map, and not IR equality. The panel showed the cause. Two front ends that both emit `xio` for `xic` are equal under an IR equality check, and both give `motor = 0` for `start = 1`. Only a test from source to map sees that. A seeded differential test over both spellings and some tag domains is the graft from Design 3.

The tests are these. The behavior twins have the §6 names as they are: "a later leg sees what an earlier leg wrote" and "parallel branches OR, and every branch still runs for its side effects". The seal-in runs over three scans. A nested group is an AND of an OR. Both jumper shapes have text twins. `mov` runs with a literal and with a tag.

A producer-side line test asserts that the seal-in operands have the line `__ENV__.line + 5` and not `1`. A vocabulary test makes a module with one rung for each key of `instructions/0` and compiles it. It gives an error if the walker gets a table of its own at any time.

Error tests use `Code.compile_string` and `assert_raise CompileError` on the description, the file and the rung line. They include the unknown mnemonic, the arity, the undeclared tag and the head tag that is not legal. They also include the empty rung, the `when` head and the duplicate name.

A sentinel test asserts that `xic(t1.dn)` is an error until the lexer lexes it. It changes when the `QUALIFIED` rule lands, and then it becomes an equivalence test. One more test asserts that `{:branches, []}` stays unreachable from the DSL. That shape evaluates to `false`, and no text can make it.

The mutation table must have these rows, each on a new copy. The `when` clause removed: one error. The `__define__` call removed: one error. The walker puts the caller's line on each operand: one error. The lexer tag check reverted: two errors. The jumper clause removed: the test file does not compile.

Two more rows. `rung: 1` removed from `.formatter.exs`: the format gate gives an error. The two §6 mutants from Design 3: each gives an error in only one of the two named tests.

## 14. Risks

1. **Toolchain skew.** All receipts are from Elixir 1.14 in the sandbox. The `CompileError` fields, `Code.compile_string`, and the AST metadata can be different on Elixir 1.15 and subsequent versions. The study must run again on the repository's toolchain before B9 starts. Until then, each number in this report is a 1.14 number.

2. **A second producer of the AST.** The repository's history shows the cost of two producers that become different. M0-1 was two fixtures that gave different results, and both gave no error. The mitigation is the vocabulary test, the lexer-derived tag check, and the source-to-map oracle on both spellings.

3. **Two validators until M1-2.** Before M1-2, the macro has an arity check that M1-2 puts in `instructionize/1`. The mitigation is the B9 precondition.

4. **Document debt.** A second surface with output from a run and no test for it. The mitigation is the M1-5 doctest with both spellings.

5. **Compile-time dependency.** Each `defladder` module compiles again when `compiler.ex` or the lexer changes. For an Elixir program downstream of logex, that is a full compile on each logex upgrade. Accepted and recorded.

6. **A grammar change that the lexer does not show.** A new structural token gets to the DSL only through a new walker clause. The result is an error, not a silent incorrect result: `expected a tag or an integer literal`.

7. **The head declarations are not in the output.** `name/0` gives back the AST and no other data. Thus, `defladder r(a, a, x)` compiles, and M1-3 cannot read the declared tags. The mitigation is the M1-3 sentence in section 11.

8. **Nested group identity.** With `branch(...)`, the DSL AST nests as the text AST does. With an infix operator, a sequence of three legs flattens to one group. This is one more argument for the call form.

## 15. Decisions for the maintainer

1. Accept B9 in the backlog, with M1-2 and M1-5 as preconditions, and not the panel's Milestone 1 slot.

2. Accept `branch(leg, leg)` as the parallel spelling, and not the panel's `|`. The cost is one word of syntax. The result is the removal of a silent OR-of-AND.

3. Make the decision: do the head declarations go into the output at B9 or at M1-3? The study recommends B9. A `name/0` that discards the tags is a contract that M1-3 and M1-5 then have to change.

4. Make the decision on the run on Elixir 1.15 or a subsequent version. The study cannot do it on this machine. The repository's rule applies: install a new Elixir, or use a copy, and do not relax the `mix.exs` in the repository.

5. Make the decision on the name. The study recommends that the repository does not say "Nx-style" in its documents, because no Nx mechanism stays. `defladder` is a good name on its own.

## 16. Precedents

The study found one active precedent: pyrung, a Python library, version 0.14.0 of 4 September 2026. pyrung writes a rung as `with rung(Start, ~Fault): out(Motor)`. It traces the body into an IR and interprets the IR. Its rules are different from logex's rules in one point. In pyrung, all conditions in a rung read a snapshot of the tags at rung entry. In logex, a subsequent leg sees the value that a previous leg wrote. The IEC standard gives the rung sequence and the OR of all legs, but it does not give that point.

The study found no Elixir precedent of value. One Elixir project, archived in 2020, parses ASCII art into an expression. Beremiz, the open PLC tool, compiles ladder to Structured Text, not to a host language. PLCopen XML, at this time IEC 61131-10, has ladder as XML with contact and coil elements in evaluation sequence. There is no standard ladder language in text. IEC 61131-3 Edition 4 (2025) removed Instruction List.

Elixir's own document on DSLs gives the alternatives in this sequence: data first, then functions, then macros. It says that the macro path "is hard and expensive to test" and adds a compile-time dependency on the macro's module. Nx, Ecto and Absinthe all use macros, each with a data structure as the result of the macro.

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

Study material, in the scratch area of the session and not in the repository:

- the five research reports
- the spike, `defladder/spike/`
- the three designs, the three scorecards, the synthesis and the two refutations
- the panel's twin test file, `defladder/syn/test/logex/defladder_test.exs`
