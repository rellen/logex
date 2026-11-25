# Compile a program and its function blocks from text

This guide is for an Elixir developer whose [program](../reference/glossary.md#program)
text does not come from a file, for example from a database. It shows how to
[compile](../reference/glossary.md#compile) the text of a
[function block](../reference/glossary.md#function-block) and the text of a program that
runs it, with `Logex.compile/2`.

Use this way if the text of your program does not come from a file, for example from a
database. `Logex.compile/2` does not read files. Give it the
[function block type](../reference/glossary.md#function-block-type) in its option `types:`.

## Before you start

- You must have a Mix project that has logex.
  [Install logex and run a program](install-and-run.md) gives the steps.
- You must know how to write a function block and run it with `cal`.
  [Write a function block](write-a-function-block.md) gives the steps.
- Get [`write-a-function-block/starter.ld`](write-a-function-block.md) and
  [`write-a-function-block/conveyors.ld`](write-a-function-block.md), and put them in the
  directory `write-a-function-block` of your project. The script reads their text.

## Steps

1. In the root directory of your project, make the file
   `write-a-function-block-types.exs` with this text.

```elixir
block = File.read!("write-a-function-block/starter.ld")
{:ok, starter} = Logex.compile(block, name: "starter")
source = File.read!("write-a-function-block/conveyors.ld")
{:ok, conveyors} = Logex.compile(source, name: "conveyors", types: [starter])

state = Logex.Runtime.instance(conveyors)
state = Logex.Runtime.put_inputs(conveyors, state, %{"start_1" => 1})
{outputs, _state} = Logex.Runtime.scan(conveyors, state, 1000)
IO.puts("#{conveyors.name}: belt_1 = #{outputs["belt_1"]}")
```

For the text of a function block, `Logex.compile/2` returns `{:ok, type}`. The option
`name:` must be the name on the line `function_block`.

2. Run the script.

```console
$ mix run write-a-function-block-types.exs
conveyors: belt_1 = 1
```

## The result

`Logex.compile/2` returns only the [warnings](../reference/glossary.md#warning) of the
program. To see the warnings of a function block, compile the program with
`Logex.compile_file/1`. It returns the warnings of the program, then the warnings of each
function block. A warning of a function block names its file.

## If it does not work

| What you see | Cause | What to do |
|---|---|---|
| `` unknown type `starter`: logex has `` and a list of types | `types:` does not give the type of the block. | Give the type in `types:`. |
| `` this function block is `start_block`, but it is compiled as `starter` `` | The name on the line `function_block` is not the name in `name:`. | Make the 2 names the same, in the same case. |
| `` types must be function block types from Logex.compile/2 `` | A value in `types:` is not a type that `Logex.compile/2` returned. | Give the `type` of `{:ok, type}`. |

## See also

- [Function blocks](../reference/function-blocks.md#logexcompile2-and-the-option-types):
  each rule of `Logex.compile/2` and the option `types:`.
- [Write a function block](write-a-function-block.md): the file of a function block, and
  `cal`.
- [Glossary](../reference/glossary.md): the words of this guide.
