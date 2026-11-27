defmodule Logex.TypespecTest.Held do
  @moduledoc """
  Decision 515 (c) (RV-24's review, F1): a value held to a type as `Code.Typespec` reads it
  from a compiled module, the Erlang abstract format: `held?/3` is true where the value is
  one of the type's, a module's own types and another's read where they are named, a
  type's parameters put in where it takes them. A form it does not know raises, so that a
  spec it cannot read is never passed.
  """

  @doc "The spec's clauses of `module.fun/arity`, each `{argument types, return type}`."
  def clauses(module, fun, arity),
    do: Enum.map(Map.fetch!(specs(module), {fun, arity}), &clause/1)

  defp clause({:type, _, :fun, [{:type, _, :product, arguments}, return]}),
    do: {arguments, return}

  @doc "The spec'd functions of `module`, `{fun, arity}`."
  def specced(module), do: Map.keys(specs(module))

  defp specs(module),
    do: memo({:specs, module}, fn -> fetched(Code.Typespec.fetch_specs(module)) end)

  defp types(module) do
    memo({:types, module}, fn ->
      {:ok, types} = Code.Typespec.fetch_types(module)

      Map.new(types, fn {_kind, {name, type, parameters}} ->
        {{name, length(parameters)}, {type, parameters}}
      end)
    end)
  end

  defp fetched({:ok, specs}), do: Map.new(specs)

  defp memo(key, build), do: memoed(key, Process.get({__MODULE__, key}), build)

  defp memoed(key, nil, build) do
    built = build.()
    Process.put({__MODULE__, key}, built)
    built
  end

  defp memoed(_key, found, _build), do: found

  @doc "Whether `value` is one of `type`'s, `type` read in `module`."
  def held?(_value, {:var, _, :_}, _module), do: true
  def held?(value, {:ann_type, _, [_name, type]}, module), do: held?(value, type, module)
  def held?(value, {:paren_type, _, [type]}, module), do: held?(value, type, module)
  def held?(value, {:atom, _, atom}, _module), do: value === atom
  def held?(value, {:integer, _, integer}, _module), do: value === integer
  def held?(value, {:op, _, :-, {:integer, _, integer}}, _module), do: value === -integer

  def held?(value, {:type, _, :range, [low, high]}, _module),
    do: is_integer(value) and value >= bound(low) and value <= bound(high)

  def held?(value, {:type, _, :union, types}, module),
    do: Enum.any?(types, &held?(value, &1, module))

  def held?(_value, {:type, _, kind, []}, _module) when kind in [:any, :term], do: true
  def held?(_value, {:type, _, kind, []}, _module) when kind in [:none, :no_return], do: false
  def held?(value, {:type, _, :integer, []}, _module), do: is_integer(value)

  def held?(value, {:type, _, :non_neg_integer, []}, _module),
    do: is_integer(value) and value >= 0

  def held?(value, {:type, _, :pos_integer, []}, _module), do: is_integer(value) and value > 0
  def held?(value, {:type, _, :neg_integer, []}, _module), do: is_integer(value) and value < 0
  def held?(value, {:type, _, :float, []}, _module), do: is_float(value)
  def held?(value, {:type, _, :number, []}, _module), do: is_number(value)

  def held?(value, {:type, _, kind, []}, _module) when kind in [:atom, :module, :node],
    do: is_atom(value)

  def held?(value, {:type, _, :boolean, []}, _module), do: is_boolean(value)
  def held?(value, {:type, _, :binary, []}, _module), do: is_binary(value)
  def held?(value, {:type, _, :bitstring, []}, _module), do: is_bitstring(value)
  def held?(value, {:type, _, :pid, []}, _module), do: is_pid(value)
  def held?(value, {:type, _, :port, []}, _module), do: is_port(value)
  def held?(value, {:type, _, :reference, []}, _module), do: is_reference(value)

  def held?(value, {:type, _, :timeout, []}, _module),
    do: value === :infinity or (is_integer(value) and value >= 0)

  def held?(value, {:type, _, :fun, _}, _module), do: is_function(value)
  def held?(value, {:type, _, :tuple, :any}, _module), do: is_tuple(value)

  def held?(value, {:type, _, :tuple, types}, module) when is_tuple(value),
    do:
      tuple_size(value) == length(types) and
        Enum.all?(Enum.zip(Tuple.to_list(value), types), fn {v, t} -> held?(v, t, module) end)

  def held?(_value, {:type, _, :tuple, _types}, _module), do: false
  def held?(value, {:type, _, nil, []}, _module), do: value === []
  def held?(value, {:type, _, :list, []}, _module), do: proper?(value)

  def held?(value, {:type, _, :list, [type]}, module),
    do: proper?(value) and Enum.all?(value, &held?(&1, type, module))

  def held?(value, {:type, _, :nonempty_list, [type]}, module),
    do: proper?(value) and value != [] and Enum.all?(value, &held?(&1, type, module))

  def held?(value, {:type, _, :map, :any}, _module), do: is_map(value)

  def held?(value, {:type, _, :map, fields}, module) when is_map(value) do
    pairs = Map.to_list(value)

    Enum.all?(pairs, fn {key, v} -> Enum.any?(fields, &field?(&1, key, v, module)) end) and
      Enum.all?(for({:type, _, :map_field_exact, _} = field <- fields, do: field), fn field ->
        Enum.any?(pairs, fn {key, v} -> field?(field, key, v, module) end)
      end)
  end

  def held?(_value, {:type, _, :map, _fields}, _module), do: false

  def held?(value, {:user_type, _, name, arguments}, module),
    do: named?(value, module, name, qualified(arguments, module))

  def held?(value, {:remote_type, _, [{:atom, _, other}, {:atom, _, name}, arguments]}, module),
    do: named?(value, other, name, qualified(arguments, module))

  defp field?({:type, _, _assoc, [key_type, value_type]}, key, value, module),
    do: held?(key, key_type, module) and held?(value, value_type, module)

  # A type named in a module, its parameters given in the module that names it: those are
  # made remote first, so that they read the same in the module whose type takes them.
  defp named?(value, module, name, arguments) do
    {type, parameters} = Map.fetch!(types(module), {name, length(arguments)})

    given =
      Map.new(Enum.zip(parameters, arguments), fn {{:var, _, parameter}, type} ->
        {parameter, type}
      end)

    held?(value, put(type, given), module)
  end

  defp qualified({:user_type, line, name, arguments}, module),
    do:
      {:remote_type, line,
       [{:atom, line, module}, {:atom, line, name}, qualified(arguments, module)]}

  defp qualified(tuple, module) when is_tuple(tuple),
    do: List.to_tuple(qualified(Tuple.to_list(tuple), module))

  defp qualified(list, module) when is_list(list), do: Enum.map(list, &qualified(&1, module))
  defp qualified(other, _module), do: other

  defp put({:var, _, name} = var, given), do: Map.get(given, name, var)
  defp put(tuple, given) when is_tuple(tuple), do: List.to_tuple(put(Tuple.to_list(tuple), given))
  defp put(list, given) when is_list(list), do: Enum.map(list, &put(&1, given))
  defp put(other, _given), do: other

  defp bound({:integer, _, integer}), do: integer
  defp bound({:op, _, :-, {:integer, _, integer}}), do: -integer

  defp proper?([]), do: true
  defp proper?([_ | tail]), do: proper?(tail)
  defp proper?(_other), do: false
end

defmodule Logex.TypespecTest do
  @moduledoc """
  Decision 515 (c) (RV-24's review, F1): every function of the host contract with a spec,
  decision 514's modules and 523's, called on what its docs take, its arguments held to
  the spec's and what it gives back held to the spec's return, by
  `Logex.TypespecTest.Held`, which reads each spec and type from the compiled module.
  Dialyzer holds a spec where it can type what the function gives (`scripts/dialyzer.sh`),
  and types nothing a call to a process gives back nor a field of a struct; this file
  holds the value, a result through `GenServer.call/3` or the compile's own process among
  them, and each test names the functions it reaches and reaches exactly those, and
  together every spec of those modules. A host's mistake, its pinned `ArgumentError`, is
  outside every spec and not called here, but `Global.new!/3`'s of an initial value no
  global's type holds, refused so that the struct it gives for a global's name, type and
  location is a `Global.t()` (decision 555). A spec wider than every value its function gives
  passes here, a value never showing it (decision 554).
  """
  use ExUnit.Case, async: true

  alias Logex.{Configuration, Edit, Runner, Runtime, Tag}
  alias Logex.Configuration.Global
  alias Logex.IO.Sim
  alias Logex.Runner.Clock
  alias Logex.Runner.Clock.Manual
  alias Logex.TypespecTest.Held

  @moduletag :tmp_dir

  # The modules decision 514 puts inside the host contract and 523's beside it, as
  # `runtime_test.exs`'s "the public surface" names them.
  @contract [
    Logex,
    Logex.Runtime,
    Logex.Edit,
    Logex.Configuration,
    Logex.Configuration.Edit,
    Logex.Runner,
    Logex.IO,
    Logex.Tag,
    Logex.Configuration.Task,
    Logex.Configuration.Global,
    Logex.Configuration.Instance,
    Logex.Configuration.Connection,
    Logex.IO.Point,
    Logex.IO.Sim,
    Logex.Runner.Clock,
    Logex.Runner.Clock.Manual,
    Logex.Runner.Clock.Monotonic
  ]

  # Each test's `@reach`, the functions it reaches, gathered for the last test.
  Module.register_attribute(__MODULE__, :reaches, accumulate: true)

  # The call, its arguments held to the spec, its value to the return of a clause whose
  # arguments hold them; each function reached noted for the test's reach.
  defp held(module, fun, arguments) do
    value = apply(module, fun, arguments)
    clauses = Held.clauses(module, fun, length(arguments))
    taking = for {types, return} <- clauses, taken?(arguments, types, module), do: return
    Process.put({__MODULE__, :reached}, [{module, fun, length(arguments)} | reached()])

    assert taking != [],
           "#{inspect(module)}.#{fun}/#{length(arguments)}'s spec takes none of " <>
             inspect(arguments, limit: 8)

    assert Enum.any?(taking, &Held.held?(value, &1, module)),
           "#{inspect(module)}.#{fun}/#{length(arguments)} gave what its spec does not: " <>
             inspect(value, limit: 12, printable_limit: 120)

    value
  end

  defp taken?(arguments, types, module),
    do:
      Enum.all?(Enum.zip(arguments, types), fn {argument, type} ->
        Held.held?(argument, type, module)
      end)

  defp reached, do: Process.get({__MODULE__, :reached}, [])

  defp reaches!(functions), do: assert(Enum.sort(Enum.uniq(reached())) == Enum.sort(functions))

  @leaf """
  function_block leaf
  var_input go bool
  var_input k dint
  var_output q bool
  var e bool[2]
  var w word
  xic go ons e[1] ote q
  """

  @mid """
  function_block mid
  var_input go bool
  var_input k dint
  var_output q bool
  var gs leaf[2]
  cal gs[1] go k q
  """

  @top """
  var_input go bool
  var_input k dint
  var_output q bool
  var_output total dint
  var_output temps real[3]
  var retain boxes ctu
  var t1 ton[2]
  var ts mid[2]
  cal ts[0] go k q
  xic go ctu boxes 3
  xic go ton t1[1] 500
  move boxes.cv total
  """

  @motor """
  var_input start bool
  var_input stop bool
  var_output motor bool
  var_output speed_sp dint 1200
  var t1 ton
  ( xic start | xic motor ) xio stop ote motor
  xic motor ton t1 2000
  """

  @reach [
    {Logex, :compile, 2},
    {Logex, :compile_file, 1},
    {Logex, :compile_files, 1}
  ]
  @reaches @reach
  test "a compile gives a program, a block's type, or diagnostics, at every depth", %{
    tmp_dir: dir
  } do
    assert {:ok, %Logex.FbType{} = leaf} = held(Logex, :compile, [@leaf, [name: "leaf"]])
    assert {:ok, mid} = held(Logex, :compile, [@mid, [name: "mid", types: [leaf]]])
    assert {:ok, %Logex.Program{}} = held(Logex, :compile, [@top, [types: [mid], name: "top"]])
    assert {:ok, %Logex.Program{}} = held(Logex, :compile, [@motor, [name: "motor"]])
    assert {:ok, %Logex.Program{tags: tags}} = held(Logex, :compile, ["", [name: "empty"]])
    assert tags == %{}

    # Decision 607 (RV-34): `declared:` held to the option type, its tags to Logex.Tag.t().
    start = Logex.Tag.new!("start", :bool, :var_input)

    assert {:ok, %Logex.Program{}} =
             held(Logex, :compile, [
               "var_output q bool\nxic start ote q",
               [declared: [start], name: "belt", types: []]
             ])

    assert {:error, [_ | _]} = held(Logex, :compile, ["xic nowhere ote q\n", [name: "bad"]])

    File.write!(Path.join(dir, "leaf.ld"), @leaf)
    File.write!(Path.join(dir, "mid.ld"), @mid)
    File.write!(Path.join(dir, "top.ld"), @top)
    File.write!(Path.join(dir, "bad.ld"), "var q bool\nxic q ote\n")
    assert {:ok, %Logex.Program{}} = held(Logex, :compile_file, [Path.join(dir, "top.ld")])
    assert {:ok, %Logex.FbType{}} = held(Logex, :compile_file, [Path.join(dir, "mid.ld")])
    assert {:error, [_ | _]} = held(Logex, :compile_file, [Path.join(dir, "bad.ld")])
    assert {:error, [_ | _]} = held(Logex, :compile_file, [Path.join(dir, "none.ld")])

    assert [{:ok, _}, {:error, _}] =
             held(Logex, :compile_files, [[Path.join(dir, "top.ld"), Path.join(dir, "bad.ld")]])

    reaches!(@reach)
  end

  @reach [
    {Runtime, :instance, 1},
    {Runtime, :instance, 2},
    {Runtime, :put_inputs, 3},
    {Runtime, :scan, 2},
    {Runtime, :scan, 3},
    {Runtime, :call, 4},
    {Runtime, :restart, 3},
    {Runtime, :retained, 2},
    {Runtime, :fresh, 1},
    {Tag, :new!, 2},
    {Tag, :new!, 3},
    {Tag, :new!, 4},
    {Tag, :new!, 5}
  ]
  @reaches @reach
  test "a lone instance: its state, scans, restarts and retained image" do
    {:ok, mid} =
      Logex.compile(@mid, name: "mid", types: [elem(Logex.compile(@leaf, name: "leaf"), 1)])

    {:ok, top} = Logex.compile(@top, name: "top", types: [mid])
    state = held(Runtime, :instance, [top])
    state = held(Runtime, :put_inputs, [top, state, %{"go" => 1, "k" => 7}])
    {%{"q" => _, "temps" => [_, _, _]}, state} = held(Runtime, :scan, [top, state])
    {_outputs, state} = held(Runtime, :scan, [top, state, 600])

    {_outputs, state} =
      held(Runtime, :call, [top, state, %{"go" => 0}, %Logex.Scan{now: 700, first: false}])

    image = held(Runtime, :retained, [top, state])
    assert {_state, []} = held(Runtime, :instance, [top, image])

    {:ok, renamed} =
      Logex.compile(
        String.replace(@top, "var retain boxes ctu", "var retain cases ctu")
        |> String.replace("boxes", "cases"),
        name: "top",
        types: [mid]
      )

    assert {_state, [{_path, :undeclared} | _]} = held(Runtime, :instance, [renamed, image])
    _state = held(Runtime, :restart, [top, state, :warm])
    _state = held(Runtime, :restart, [top, state, :cold])
    _state = held(Runtime, :fresh, [top])

    {:ok, empty} = Logex.compile("", name: "empty")
    %Logex.Instance{env: env} = held(Runtime, :instance, [empty])
    assert env == %{}

    held(Tag, :new!, ["a", :dint])
    held(Tag, :new!, ["b", :real, :var_output])
    held(Tag, :new!, ["c", {:array, :int, [2, 3]}, :var, [1, 2, 3, 4, 5, 6]])
    held(Tag, :new!, ["d", :lreal, :var, 2.5, [retain: true]])
    held(Tag, :new!, ["e", Logex.FbType.ton(), :var, nil, [non_retain: true]])
    reaches!(@reach)
  end

  @reach [
    {Logex.Edit, :accept, 3},
    {Logex.Edit, :test, 2},
    {Logex.Edit, :untest, 2},
    {Logex.Edit, :assemble, 2},
    {Logex.Edit, :cancel, 2},
    {Logex.Edit, :running, 1},
    {Logex.Edit, :stage, 1}
  ]
  @reaches @reach
  test "a lone instance's online edit, accepted, refused, tested, untested, assembled and " <>
         "cancelled" do
    {:ok, motor} = Logex.compile(@motor, name: "motor")
    {:ok, v2} = Logex.compile(String.replace(@motor, "2000", "500"), name: "motor")

    {:ok, retyped} =
      Logex.compile(String.replace(@motor, "speed_sp dint", "speed_sp int"), name: "motor")

    {_outputs, state} =
      Runtime.scan(motor, Runtime.put_inputs(motor, Runtime.instance(motor), %{"start" => 1}), 10)

    assert {:error, [_ | _]} = held(Edit, :accept, [motor, retyped, state])
    {:ok, edit, _forecast} = held(Edit, :accept, [motor, v2, state])
    :accepted = held(Edit, :stage, [edit])
    {edit, state, _report} = held(Edit, :test, [edit, state])
    :testing = held(Edit, :stage, [edit])
    {_outputs, state} = Runtime.scan(held(Edit, :running, [edit]), state, 600)
    {edit, state, _report} = held(Edit, :untest, [edit, state])
    :untested = held(Edit, :stage, [edit])
    {edit, state, _report} = held(Edit, :test, [edit, state])
    {%Logex.Program{}, _state, _report} = held(Edit, :assemble, [edit, state])

    {:ok, edit, _forecast} = Edit.accept(motor, v2, state)
    {%Logex.Program{}, _state, _report} = held(Edit, :cancel, [edit, state])
    reaches!(@reach)
  end

  @conveyor """
  var_input start bool
  var_input stop bool
  var_input reset bool
  var_output motor bool
  var_external estop bool
  var fault bool

  xic estop otl fault
  xic reset otu fault
  ( xic start | xic motor ) xio stop xio fault ote motor
  """

  @tally """
  var_input eye bool
  var_output retain full bool
  var_output count dint
  var_output temp real
  var_external total_boxes dint
  var retain boxes ctu
  var e bool
  var levels dint[2]

  xic eye ctu boxes 3
  xic eye ons e add total_boxes 1 total_boxes
  xic boxes.q otl full
  move boxes.cv count
  move boxes.cv levels[1]
  """

  @plant """
  task fast interval 10 priority 1 watchdog 50
  task main continuous watchdog 200

  var_global estop bool at panel.i.7
  var_global pb_start bool at panel.i.0
  var_global pb_reset bool at panel.i.2
  var_global eye bool at panel.i.8
  var_global k1 bool at panel.q.0
  var_global case_full bool at panel.q.4
  var_global retain total_boxes dint 0
  var_global ws int[3] 1 2 3
  var_global lamps bool[2] at panel.q.6
  var_global temp real

  program c1 conveyor with fast
    c1.start pb_start
    c1.stop 0
    c1.reset pb_reset
    c1.motor k1

  program t1 tally
    t1.eye eye
    t1.full case_full
    t1.temp temp
  """

  defp programs do
    {:ok, conveyor} = Logex.compile(@conveyor, name: "conveyor")
    {:ok, tally} = Logex.compile(@tally, name: "tally")
    %{"conveyor" => conveyor, "tally" => tally}
  end

  defp plant(text \\ @plant) do
    {:ok, plant} = Configuration.compile("plant", text, programs())
    plant
  end

  @reach [
    {Configuration, :compile, 3},
    {Configuration, :compile_file, 1},
    {Configuration, :check, 1},
    {Configuration, :new!, 1},
    {Configuration, :initial, 1},
    {Configuration, :location, 1},
    {Configuration, :watchdog, 1},
    {Global, :new!, 2},
    {Global, :new!, 3},
    {Logex.IO, :points, 1},
    {Logex.IO, :bind!, 2}
  ]
  @reaches @reach
  test "a configuration: compiled, built, checked, and its globals, tasks and points read",
       %{tmp_dir: dir} do
    assert {:ok, plant} = held(Configuration, :compile, ["plant", @plant, programs()])

    assert {:error, [_ | _]} =
             held(Configuration, :compile, ["plant", @plant <> "program x1 nothing\n", programs()])

    File.write!(Path.join(dir, "conveyor.ld"), @conveyor)
    File.write!(Path.join(dir, "tally.ld"), @tally)
    File.write!(Path.join(dir, "plant.logex"), @plant)
    File.write!(Path.join(dir, "wrong.logex"), "task fast\n")
    assert {:ok, _plant} = held(Configuration, :compile_file, [Path.join(dir, "plant.logex")])
    assert {:error, [_ | _]} = held(Configuration, :compile_file, [Path.join(dir, "wrong.logex")])
    assert [] = held(Configuration, :check, [plant])

    global = held(Global, :new!, ["sp", :dint])
    ws = held(Global, :new!, ["ws", {:array, :real, [2]}, [initial: [1.5, 2], retain: true]])
    at = held(Global, :new!, ["x", :bool, [at: "panel.i.0", non_retain: true]])

    built =
      held(Configuration, :new!, [
        [
          name: "built",
          programs: [programs()["conveyor"]],
          globals: [global, ws, at, Global.new!("estop", :bool), Global.new!("k", :bool)],
          tasks: [%Configuration.Task{name: "fast", interval: 10, priority: 1}],
          instances: [%Configuration.Instance{name: "c1", type: "conveyor", task: "fast"}],
          connections: [
            %Configuration.Connection{instance: "c1", member: "start", to: "x"},
            %Configuration.Connection{instance: "c1", member: "stop", to: 0},
            %Configuration.Connection{instance: "c1", member: "reset", to: 0},
            %Configuration.Connection{instance: "c1", member: "motor", to: "k"}
          ]
        ]
      ])

    unknown = %Configuration.Instance{name: "x1", type: "nothing"}

    assert [_ | _] =
             held(Configuration, :check, [%{built | instances: [unknown | built.instances]}])

    0 = held(Configuration, :initial, [global])
    {1.5, 2.0} = held(Configuration, :initial, [ws])
    {:ok, {"panel", "q", [0]}} = held(Configuration, :location, ["panel.q.0"])
    :error = held(Configuration, :location, ["panel.x.0"])
    500 = held(Configuration, :watchdog, [hd(built.tasks)])
    50 = held(Configuration, :watchdog, [Enum.find(plant.tasks, &(&1.name == "fast"))])

    assert %{"panel" => [_ | _]} = held(Logex.IO, :points, [plant])
    {:ok, sim} = Sim.start_link()
    bound = held(Logex.IO, :bind!, [plant, %{"panel" => {Sim, sim: sim}}])
    assert [{"panel", Sim, [sim: ^sim], [_ | _]}] = bound

    assert [{"panel", Sim, [sim: ^sim], [_]}] =
             held(Logex.IO, :bind!, [built, %{"panel" => {Sim, sim: sim}}])

    reaches!(@reach)
  end

  # Decision 555 (RV-30; RV-24's question 7): `Global.t()` is true of the struct
  # `Global.new!/2,3` gives. Since decision 577 (RV-31) of every struct it gives: a name,
  # a type or a location that is none, which it kept until then as given, the struct
  # outside `t()` (RV-30's review, F7), is refused at once too, shown at the end.
  # Every elementary type at the ends of its range, a real's
  # integer and float, an array's list and a located global, each held to the spec; and
  # the values no global's type holds, which `new!/3` kept until then, its struct outside
  # `t()`: each such struct, built by hand, is outside it, and `new!/3` gives none.
  @reach [{Global, :new!, 2}, {Global, :new!, 3}]
  @reaches @reach
  test "the struct Global.new!/2,3 gives for a global's name, type and location is a " <>
         "Global.t(), every type at its ends" do
    for {type, values} <- [
          {:bool, [0, 1]},
          {:sint, [-128, 127]},
          {:int, [-32_768, 32_767]},
          {:dint, [-2_147_483_648, 2_147_483_647]},
          {:lint, [-9_223_372_036_854_775_808, 9_223_372_036_854_775_807]},
          {:usint, [0, 255]},
          {:uint, [0, 65_535]},
          {:udint, [0, 4_294_967_295]},
          {:ulint, [0, 18_446_744_073_709_551_615]},
          {:byte, [0, 255]},
          {:word, [0, 65_535]},
          {:dword, [0, 4_294_967_295]},
          {:lword, [0, 18_446_744_073_709_551_615]},
          {:real, [0, 16_777_216, 1.5, -3.4028234663852886e38]},
          {:lreal, [0, 9_007_199_254_740_992, 1.0e300]},
          {{:array, :int, [3]}, [[1, 2, 3], [-32_768, 0, 32_767]]},
          {{:array, :lreal, [2, 2]}, [[1, 2.5, 3, 4.5]]},
          {{:array, :bool, [1]}, [[1]]}
        ] do
      assert %Global{type: ^type, initial: nil} = held(Global, :new!, ["g", type])
      assert %Global{initial: nil} = held(Global, :new!, ["g", type, [initial: nil]])

      for initial <- values do
        assert %Global{type: ^type, initial: ^initial} =
                 held(Global, :new!, ["g", type, [initial: initial, retain: true]])
      end

      # Decision 576: located, with no initial value.
      assert %Global{type: ^type, at: "panel.q.0", initial: nil} =
               held(Global, :new!, ["g", type, [at: "panel.q.0", non_retain: true]])
    end

    assert %Global{at: "panel.q.0"} = held(Global, :new!, ["y", :bool, [at: "panel.q.0"]])

    [{_arguments, t}] = Held.clauses(Global, :new!, 2)
    assert Held.held?(%Global{name: "g", type: :bool, initial: 1}, t, Global)

    for {type, initial} <- [
          {:bool, true},
          {:dint, "5"},
          {:real, :half},
          {{:array, :int, [2]}, [[1], [2]]},
          {{:array, :int, [2]}, [1, :x]}
        ] do
      refute Held.held?(%Global{name: "g", type: type, initial: initial}, t, Global)
      assert_raise ArgumentError, fn -> Global.new!("g", type, initial: initial) end
    end

    # RV-30's review (F7): what `new!/2,3` kept as given, check/1's to refuse, is outside
    # `t()`: a type that is none, a name that is no text and a location that is none.
    # Since decision 577 (RV-31) `new!/3` refuses each at once, so none is given.
    for {name, type, options, message} <- [
          {"g", :float, [], "global `g` has type :float: "},
          {:g, :bool, [], ":g cannot name a global: "},
          {"g", :bool, [at: 5], "global `g` is at 5, which is not a location: "},
          {"g", {:array, :ton, [2]}, [initial: [1, 2]],
           "global `g` has type {:array, :ton, [2]}: "}
        ] do
      kept = %Global{name: name, type: type, initial: options[:initial], at: options[:at]}
      refute Held.held?(kept, t, Global), inspect(kept)

      assert %ArgumentError{message: ^message <> _} =
               catch_error(Global.new!(name, type, options))
    end

    reaches!(@reach)
  end

  @reach [
    {Runtime, :start, 1},
    {Runtime, :start, 2},
    {Runtime, :cycle, 3},
    {Runtime, :get, 2},
    {Runtime, :get!, 2},
    {Runtime, :next_due_in, 1},
    {Runtime, :overlaps, 1},
    {Runtime, :restart, 2},
    {Runtime, :retained, 1},
    {Runtime, :cycle_steps, 3},
    {Runtime, :cycle_step, 2},
    {Runtime, :cycle_outputs, 1},
    {Runtime, :edited, 2},
    {Runtime, :fields, 1},
    {Runtime, :retained_values, 1},
    {Runtime, :retained_image, 1},
    {Configuration.Edit, :accept, 2},
    {Configuration.Edit, :accept, 3},
    {Configuration.Edit, :test, 2},
    {Configuration.Edit, :test, 3},
    {Configuration.Edit, :untest, 2},
    {Configuration.Edit, :untest, 3},
    {Configuration.Edit, :assemble, 2},
    {Configuration.Edit, :cancel, 2},
    {Configuration.Edit, :running, 1},
    {Configuration.Edit, :stage, 1}
  ]
  @reaches @reach
  test "a resource: started, cycled, read, restarted, its image, and its online edit" do
    plant = plant()
    runtime = held(Runtime, :start, [plant])
    0 = held(Runtime, :next_due_in, [runtime])

    {runtime, %{"k1" => _, "lamps[0]" => _}, _events} =
      held(Runtime, :cycle, [runtime, 0, %{"pb_start" => 1, "eye" => 1}])

    {runtime, _outputs, events} =
      held(Runtime, :cycle, [runtime, 25, %{"pb_start" => 0, "eye" => 0}])

    assert [_ | _] = events
    {:ok, _} = held(Runtime, :get, [runtime, "total_boxes"])
    {:ok, [1, 2, 3]} = held(Runtime, :get, [runtime, "ws"])
    {:error, _} = held(Runtime, :get, [runtime, "nowhere"])
    +0.0 = held(Runtime, :get!, [runtime, "t1.temp"])
    5 = held(Runtime, :next_due_in, [runtime])

    continuous =
      @plant
      |> String.replace("task fast interval 10 priority 1 watchdog 50\n", "")
      |> String.replace("program c1 conveyor with fast", "program c1 conveyor")

    :infinity = held(Runtime, :next_due_in, [Runtime.start(plant(continuous))])
    %{} = held(Runtime, :overlaps, [runtime])
    image = held(Runtime, :retained, [runtime])
    {_runtime, []} = held(Runtime, :start, [plant, image])
    _runtime = held(Runtime, :restart, [runtime, :warm])
    _runtime = held(Runtime, :restart, [runtime, :cold])

    {stepped, steps} = held(Runtime, :cycle_steps, [runtime, 10, %{"eye" => 1}])

    stepped =
      Enum.reduce(steps, stepped, fn step, at ->
        elem(held(Runtime, :cycle_step, [at, step]), 0)
      end)

    %{"k1" => _} = held(Runtime, :cycle_outputs, [stepped])
    %{now: _, generation: _} = held(Runtime, :fields, [runtime])
    _runtime = held(Runtime, :edited, [runtime, %{}])
    values = held(Runtime, :retained_values, [runtime])
    %{configuration: "plant"} = held(Runtime, :retained_image, [values])

    faster = plant(String.replace(@plant, "interval 10", "interval 5"))

    moved =
      plant(
        String.replace(@plant, "program c1 conveyor with fast", "program c1 conveyor with main")
      )

    assert {:error, [_ | _]} = held(Configuration.Edit, :accept, [runtime, moved])
    {:ok, edit, _forecast} = held(Configuration.Edit, :accept, [runtime, faster])
    :accepted = held(Configuration.Edit, :stage, [edit])
    %Configuration{} = held(Configuration.Edit, :running, [edit])
    {edit, runtime, _report} = held(Configuration.Edit, :test, [edit, runtime])
    {edit, runtime, _report} = held(Configuration.Edit, :untest, [edit, runtime])
    {edit, runtime, _report} = held(Configuration.Edit, :test, [edit, runtime, 3])
    {%Configuration{}, runtime, _report} = held(Configuration.Edit, :assemble, [edit, runtime])

    {:ok, edit, _forecast} = held(Configuration.Edit, :accept, [runtime, plant, 2])
    {edit, runtime, _report} = Configuration.Edit.test(edit, runtime)
    {edit, runtime, _report} = held(Configuration.Edit, :untest, [edit, runtime, 1])
    {%Configuration{}, _runtime, _report} = held(Configuration.Edit, :cancel, [edit, runtime])
    reaches!(@reach)
  end

  @reach [
    {Runner, :start_link, 1},
    {Runner, :child_spec, 1},
    {Runner, :status, 1},
    {Runner, :get, 2},
    {Runner, :get!, 2},
    {Runner, :subscribe, 1},
    {Runner, :subscribe, 2},
    {Runner, :unsubscribe, 1},
    {Runner, :force, 3},
    {Runner, :unforce, 2},
    {Runner, :unforce_all, 1},
    {Runner, :accept, 2},
    {Runner, :test, 1},
    {Runner, :untest, 1},
    {Runner, :assemble, 1},
    {Runner, :cancel, 1},
    {Runner, :restart, 2},
    {Runner, :stop, 1},
    {Runner, :stop, 2},
    {Sim, :start_link, 0},
    {Sim, :start_link, 1},
    {Sim, :child_spec, 1},
    {Sim, :set, 2},
    {Sim, :set, 3},
    {Sim, :outputs, 1},
    {Sim, :writes, 1},
    {Sim, :reads, 1},
    {Sim, :closed?, 1},
    {Sim, :fail, 3},
    {Sim, :hold, 1},
    {Sim, :let_go, 1},
    {Sim, :holding?, 1},
    {Clock, :receiver!, 1},
    {Clock, :time!, 1},
    {Clock, :timer!, 1},
    {Manual, :start_link, 0},
    {Manual, :start_link, 1},
    {Manual, :child_spec, 1},
    {Manual, :advance, 2},
    {Manual, :pass, 2},
    {Manual, :pending, 1}
  ]
  @reaches @reach
  test "the runner on the manual clock, its simulated device, and every call's answer",
       %{tmp_dir: dir} do
    plant = plant()
    {:ok, clock} = held(Manual, :start_link, [[now: 1_700_000_000_000]])
    {:ok, _clock} = held(Manual, :start_link, [])
    {:ok, panel} = held(Sim, :start_link, [[reports: true, clock: clock]])
    {:ok, spare} = held(Sim, :start_link, [])
    %{start: _} = held(Sim, :child_spec, [[]])
    %{start: _} = held(Manual, :child_spec, [[]])
    :ok = held(Sim, :set, [panel, [0], 1])
    :ok = held(Sim, :set, [panel, %{[2] => 0, [8] => 0}])
    store = Path.join(dir, "plant.retain")
    forces = Path.join(dir, "plant.forces")

    opts = [
      configuration: plant,
      io: %{"panel" => {Sim, sim: panel}},
      clock: {Manual, clock},
      retain: store,
      forces: forces
    ]

    %{start: _} = held(Runner, :child_spec, [opts])
    {:ok, runner} = held(Runner, :start_link, [opts])

    :ok = held(Runner, :subscribe, [runner])
    :ok = held(Runner, :unsubscribe, [runner])
    :ok = held(Runner, :subscribe, [runner, [:ran, :round, :edit, :trip, :restart]])
    :ok = held(Manual, :advance, [clock, 10])
    :ok = held(Sim, :set, [panel, "panel.i.8", 1])
    :ok = held(Manual, :advance, [clock, 2])
    :ok = held(Manual, :pass, [clock, 0])
    [_ | _] = held(Manual, :pending, [clock])
    %{status: :running} = held(Runner, :status, [runner])
    {:ok, _} = held(Runner, :get, [runner, "t1.count"])
    {:error, _} = held(Runner, :get, [runner, "nowhere"])
    1 = held(Runner, :get!, [runner, "k1"])
    %{"panel.q.0" => 1} = held(Sim, :outputs, [panel])
    [_ | _] = held(Sim, :writes, [panel])
    _reads = held(Sim, :reads, [panel])
    false = held(Sim, :closed?, [panel])

    :ok = held(Runner, :force, [runner, "eye", 0])
    :ok = held(Runner, :unforce, [runner, "eye"])
    :ok = Runner.force(runner, "eye", 1)
    :ok = held(Runner, :unforce_all, [runner])

    moved =
      plant(
        String.replace(@plant, "program c1 conveyor with fast", "program c1 conveyor with main")
      )

    {:error, [_ | _]} = held(Runner, :accept, [runner, moved])

    {:ok, _forecast} =
      held(Runner, :accept, [runner, plant(String.replace(@plant, "interval 10", "interval 5"))])

    {:ok, _report} = held(Runner, :test, [runner])
    %{edit: :testing} = Runner.status(runner)
    {:ok, _report} = held(Runner, :untest, [runner])
    {:ok, _report} = Runner.test(runner)
    {:ok, _report} = held(Runner, :assemble, [runner])
    {:ok, _forecast} = Runner.accept(runner, plant)
    {:ok, _report} = held(Runner, :cancel, [runner])

    # A trip, a restart held at its reread and let go, and one a device refuses.
    :ok = held(Sim, :fail, [panel, :read, {:error, :eio}])
    :ok = Manual.advance(clock, 10)
    %{status: :tripped} = held(Runner, :status, [runner])
    false = held(Sim, :holding?, [panel])
    :ok = held(Sim, :hold, [panel])
    restart = Task.async(fn -> Runner.restart(runner, :warm) end)
    holding(panel)
    :ok = held(Sim, :let_go, [panel])
    :ok = Task.await(restart)
    :ok = Sim.fail(panel, :read, {:error, :eio})
    :ok = Manual.advance(clock, 10)
    :ok = Sim.fail(panel, :read, {:error, :eio})
    {:error, {:io_init, "panel", _}} = held(Runner, :restart, [runner, :cold])
    :ok = held(Runner, :restart, [runner, :cold])

    File.mkdir_p!(store <> ".tmp")
    {:error, {:retain, :eisdir}} = held(Runner, :stop, [runner])
    File.rmdir!(store <> ".tmp")
    true = held(Sim, :closed?, [panel])

    # A start a device refuses, and a force whose file cannot be written.
    :ok = Sim.fail(spare, :init, {:error, :unplugged})

    spared =
      Keyword.merge(opts,
        io: %{"panel" => {Sim, sim: spare}},
        retain: Path.join(dir, "spare.retain"),
        forces: Path.join([dir, "gone", "forces"])
      )

    {:error, {:io_init, "panel", :unplugged}} = held(Runner, :start_link, [spared])
    {:ok, runner} = Runner.start_link(spared)
    {:error, {:forces, :enoent}} = held(Runner, :force, [runner, "eye", 1])
    {:error, {:forces, :enoent}} = held(Runner, :unforce, [runner, "eye"])
    {:error, {:forces, :enoent}} = held(Runner, :unforce_all, [runner])
    :ok = held(Runner, :stop, [runner, :normal])

    pid = held(Clock, :receiver!, [self()])
    5 = held(Clock, :time!, [5])
    ref = make_ref()
    ^ref = held(Clock, :timer!, [ref])
    _ = pid
    reaches!(@reach)
  end

  defp holding(sim), do: holding(sim, Sim.holding?(sim), 5_000)
  defp holding(_sim, true, _left), do: :ok

  defp holding(sim, false, left) when left > 0 do
    Process.sleep(1)
    holding(sim, Sim.holding?(sim), left - 1)
  end

  @reached Enum.uniq(List.flatten(Module.get_attribute(__MODULE__, :reaches)))

  test "every spec of the host contract is reached by a test above, and no other function" do
    specced =
      for module <- @contract, {fun, arity} <- Held.specced(module), do: {module, fun, arity}

    assert Enum.sort(@reached) == Enum.sort(specced)
  end
end
