# Each case is 1 program: its declarations, its rung and the inputs of the scan.
cases = [
  {"var_input boxes dint\nvar_output total dint\nvar_output ok bool", "add boxes 1 total ote ok",
   %{"boxes" => 2_147_483_647}},
  {"var_input flow real\nvar_output sq real\nvar_output ok bool", "mul flow flow sq ote ok",
   %{"flow" => 3.0e38}},
  {"var_input flow real\nvar_output sq real\nvar_output ok bool", "mul flow flow sq ote ok",
   %{"flow" => 1.0e-30}},
  {"var_input boxes dint\nvar_output small sint\nvar_output ok bool",
   "dint_to_sint boxes small ote ok", %{"boxes" => 129}},
  {"var_input lamps word\nvar_input n int\nvar_output moved word\nvar_output ok bool",
   "shl lamps n moved ote ok", %{"lamps" => 9, "n" => -1}}
]

# Runs 1 scan of each case, then prints the rung, the inputs, the outputs and the faults.
for {declarations, rung, inputs} <- cases do
  {:ok, program} = Logex.compile(declarations <> "\n" <> rung, name: "none")
  state = Logex.Runtime.put_inputs(program, Logex.Runtime.instance(program), inputs)
  {outputs, state} = Logex.Runtime.scan(program, state)
  IO.puts("#{rung}  #{inspect(inputs)}")
  IO.puts("  #{inspect(outputs)}  faults=#{inspect(state.faults)}")
end

# A value from the host that the input cannot hold: an error of the host.
source = "var_input zone int\nvar_output speed int\nmove zone speed"
{:ok, program} = Logex.compile(source, name: "host")
state = Logex.Runtime.instance(program)
scan = %Logex.Scan{now: 0, first: true}

calls = [
  fn -> Logex.Runtime.put_inputs(program, state, %{"zone" => 40_000}) end,
  fn -> Logex.Runtime.call(program, state, %{"zone" => 40_000}, scan) end
]

for call <- calls do
  try do
    call.()
  rescue
    error in ArgumentError -> IO.puts("ArgumentError: #{Exception.message(error)}")
  end
end
