# Carry retained values to a new version

This guide is for a reader who runs a ladder [program](../reference/glossary.md#program)
from Elixir and keeps some of its values across a restart. It shows how to start a new
version of the program with the retained values of the old version.

## Before you start

You must have:

- a program with tags that have the [qualifier](../reference/glossary.md#qualifier)
  `retain`, as in [Keep values across a restart](keep-values-across-a-restart.md).
- the file [`shift.ld`](keep-values-across-a-restart.md) in the directory of your Mix
  project. The steps carry its values to a new version.

## Steps

1. Take the [retained image](../reference/glossary.md#retained-image) of the old
   version with `Logex.Runtime.retained(program, state)`.
2. Compile the new version with the name of the old program. `Logex.compile_file/1`
   names a program after its file.
3. Start a new [instance](../reference/glossary.md#instance) with
   `Logex.Runtime.instance(new_program, image)`.
4. Read the list of values that the start did not keep.

Here the new version of `shift.ld` is in the directory
`carry-retained-values-to-a-new-version`, so its name is `shift` also. To compile a text
with a name, give `name: "shift"` to `Logex.compile/2`.

In the new version, `total` is a `lint`, the counter has the
[preset](../reference/glossary.md#preset) 2000, and `lube` has no `retain`. Save it as
`carry-retained-values-to-a-new-version/shift.ld`:

<!-- file: carry-retained-values-to-a-new-version/shift.ld -->
```text
var_input eye bool
var_input weight dint
var_input motor bool
var_output retain total lint
var_output last dint
var retain boxes ctu
var lube rto
var e bool

xic eye ctu boxes 2000
xic eye ons e add total weight total
xic eye move weight last
xic motor rto lube 60000
```

Save this script as `carry-retained-values-to-a-new-version.exs`, and run it. It counts 2
boxes with the old version, and then starts the new version from the image.

```elixir
alias Logex.Runtime

{:ok, shift} = Logex.compile_file("shift.ld")
{:ok, new_shift} = Logex.compile_file("carry-retained-values-to-a-new-version/shift.ld")

scan = fn state, inputs ->
  state = Runtime.put_inputs(shift, state, inputs)
  {_outputs, state} = Runtime.scan(shift, state, 10)
  state
end

# The motor runs, and 2 boxes pass the eye.
state =
  Runtime.instance(shift)
  |> scan.(%{"motor" => 1})
  |> scan.(%{"eye" => 1, "weight" => 12})
  |> scan.(%{"eye" => 0})
  |> scan.(%{"eye" => 1, "weight" => 15})

image = Runtime.retained(shift, state)
IO.inspect(image)

{fresh, dropped} = Runtime.instance(new_shift, image)
IO.inspect(dropped)
env = fresh.env
counter = env["boxes"]
lube = env["lube"]["acc"]
IO.puts("boxes=#{counter["cv"]}  pv=#{counter["pv"]}  total=#{env["total"]}  lube=#{lube}")
```

```console
$ mix run carry-retained-values-to-a-new-version.exs
%{
  values: %{
    "boxes.cu" => {:bool, 1},
    "boxes.cv" => {:dint, 2},
    "boxes.ov" => {:bool, 0},
    "boxes.pv" => {:dint, 1000},
    "boxes.q" => {:bool, 0},
    "boxes.r" => {:bool, 0},
    "lube.acc" => {:dint, 30},
    "lube.dn" => {:bool, 0},
    "lube.en" => {:bool, 1},
    "lube.pre" => {:dint, 60000},
    "lube.r" => {:bool, 0},
    "lube.tt" => {:bool, 1},
    "total" => {:dint, 27}
  },
  program: "shift",
  kinds: %{"boxes" => "ctu", "lube" => "rto"}
}
[
  {"boxes.pv", {:preset, 1000, 2000}},
  {"lube", :unretained},
  {"total", {:retyped, :dint, :lint}}
]
boxes=2  pv=2000  total=0  lube=0
```

## The result

The image holds each retained value by its path, with its
[type](../reference/glossary.md#type). The new instance has these values:

| Tag | Value | Why |
|---|---|---|
| `boxes.cv` | 2, from the image | The counter keeps `retain`, its kind and its type. |
| `boxes.pv` | 2000, from the rung | The rung gives the preset. |
| `total` | 0, its initial value | Its type changed from `dint` to `lint`. |
| `lube` | 0, its initial value | It has no `retain` in the new version. |

The list names each value that the start did not keep, with the reason.
[If it does not work](#if-it-does-not-work) gives each reason and what to do.

For a [resource](../reference/glossary.md#resource), take the image with
`Logex.Runtime.retained/1` and start the new version with `Logex.Runtime.start/2`. It does
the same checks for each instance and each [global](../reference/glossary.md#global). It
also drops an instance that the configuration does not have, or that runs a different
program.

## If it does not work

Each entry of the list is `{path, reason}`. If the kind of an instance changes, 1 entry
names the whole instance, for example `{"boxes", {:retyped, "ctu", "ctd"}}`.

| Reason | Cause | What to do |
|---|---|---|
| `:undeclared` | The new version does not declare the path. | Declare it, if the new version must keep the value. |
| `:unretained` | The path has no `retain` in the new version. | Add `retain`. |
| `{:retyped, old, new}` | The type or the kind changed. | Keep the type, or let the value start at its initial value. |
| `{:resized, old, new}` | The size of the array changed. | Keep the size. |
| `:misfit` | The value in the image does not fit its type. | Correct the value in the image. |
| `{:preset, old, new}` | The preset of the rung is not the stored preset. | No action. The instance takes the preset of the rung. |
| `` ArgumentError: the retained image is of program `` | The image is of a program with a different name. | Give the new version the name of the old program. |

## See also

- [Retained values](../reference/retained-values-and-store.md): each rule
  of the retained image and of its checks.
- [Keep values across a restart](keep-values-across-a-restart.md): mark tags `retain`
  and do a warm restart.
- [Edit a running program](edit-a-running-program.md): change a program that runs, with
  an online edit.
- [Glossary](../reference/glossary.md): the words of this guide.
