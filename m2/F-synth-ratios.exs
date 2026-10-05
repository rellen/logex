# Prints the growth ratios the tests assert, over several runs.
alias Logex.{Runtime, Edit}
defmodule R do
  def block!(src) do
    [_, name] = Regex.run(~r/\Afunction_block (\w+)/, src)
    {:ok, t} = Logex.compile(src, name: name); t
  end
  def block!(src, types) do
    [_, name] = Regex.run(~r/\Afunction_block (\w+)/, src)
    {:ok, t} = Logex.compile(src, name: name, types: types); t
  end
  def program!(src, types), do: (with {:ok, p} <- Logex.compile(src, name: "m", types: types), do: p)
  def reds(f), do: Enum.min(for _ <- 1..3 do
    {:reductions, a} = Process.info(self(), :reductions); f.(); {:reductions, b} = Process.info(self(), :reductions); b - a end)
  def blocked_scan(n) do
    pulse = fn c -> block!("function_block pulse\nvar_input go bool\nvar_output q bool\nvar edge bool\n#{c} ons edge ote q") end
    source = fn pulse -> program!("var_input a bool\nvar_output y bool\n" <> Enum.map_join(1..n, "\n", &"var p#{&1} pulse") <> "\n" <> Enum.map_join(1..n, "\n", &"cal p#{&1} a y"), [pulse]) end
    v1 = source.(pulse.("xic go")); v2 = source.(pulse.("xic go xic go"))
    {_, st} = Runtime.scan(v1, Runtime.put_inputs(v1, Runtime.instance(v1), %{"a" => 0}))
    {:ok, e, _} = Edit.accept(v1, v2, st); {_e, st, _} = Edit.test(e, st)
    st = Runtime.put_inputs(v2, st, %{"a" => 1})
    reds(fn -> Runtime.scan(v2, st, 10) end)
  end
  def chain(n) do
    deepest = "function_block b#{n}\nvar_input go bool\nvar_output q bool\nvar edge bool\nvar t1 ton\nxic go ons edge ote q\nxic go ton t1 100"
    Enum.reduce((n - 1)..1//-1, block!(deepest), fn k, inner ->
      block!("function_block b#{k}\nvar_input go bool\nvar_output q bool\nvar inner b#{k + 1}\ncal inner go q", [inner]) end)
  end
  @top "var_input a bool\nvar_output y bool\nvar_output z bool\nvar p b1\ncal p a y\n"
  def depth(n) do
    top = chain(n)
    v1 = program!(@top <> "xic a ote z", [top]); v2 = program!(@top <> "xio a ote z", [top])
    {_, st} = Runtime.scan(v1, Runtime.put_inputs(v1, Runtime.instance(v1), %{"a" => 1}))
    %{scan: reds(fn -> Runtime.scan(v1, st, 10) end),
      compile: reds(fn -> Logex.compile(@top <> "xic a ote z", name: "m", types: [top]) end),
      edit: reds(fn -> {:ok, e, _} = Edit.accept(v1, v2, st); {e, s, _} = Edit.test(e, st); {e, s, _} = Edit.untest(e, s); {e, s, _} = Edit.test(e, s); Edit.assemble(e, s) end)}
  end
end
runs = String.to_integer(System.get_env("RUNS", "5"))
for i <- 1..runs do
  s = R.depth(50); d = R.depth(800)
  b = R.blocked_scan(4000) / R.blocked_scan(250)
  IO.puts("run #{i}: depth scan #{Float.round(d.scan / s.scan, 2)} compile #{Float.round(d.compile / s.compile, 2)} edit #{Float.round(d.edit / s.edit, 2)}; blocked #{Float.round(b, 2)}")
end
