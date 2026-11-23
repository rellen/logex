alias Logex.Runtime

{:ok, bits} = Logex.compile_file("keep-values-across-a-restart/start_bits.ld")

scan = fn state, label ->
  {outputs, state} = Runtime.scan(bits, state)
  IO.puts("#{label}  #{inspect(outputs)}")
  state
end

restart = fn state, mode -> Runtime.restart(bits, state, mode) end

Runtime.instance(bits)
|> scan.("first scan  ")
|> scan.("second scan ")
|> restart.(:warm)
|> scan.("warm restart")
|> restart.(:cold)
|> scan.("cold restart")
