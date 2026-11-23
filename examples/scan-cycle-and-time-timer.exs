{:ok, delay} = Logex.compile_file("delay.ld")

# One scan, `ms` milliseconds after the last scan.
scan = fn ms, {_outputs, state} -> Logex.Runtime.scan(delay, state, ms) end

pad = fn value, width -> String.pad_leading("#{value}", width) end

# Hold `go` at 1. Run 1 scan at 0 ms, then `count` scans that are `ms` apart.
run = fn count, ms ->
  state = Logex.Runtime.put_inputs(delay, Logex.Runtime.instance(delay), %{"go" => 1})
  {outputs, state} = Enum.reduce([0 | List.duplicate(ms, count)], {%{}, state}, scan)

  IO.puts(
    "#{pad.(count, 4)} x #{pad.(ms, 4)} ms  now=#{pad.(state.now, 4)}" <>
      "  waited=#{pad.(outputs["waited"], 4)}  lamp=#{outputs["lamp"]}"
  )
end

run.(3, 1000)
run.(300, 10)
run.(1, 2500)
run.(2, 2500)
run.(1000, 0)
