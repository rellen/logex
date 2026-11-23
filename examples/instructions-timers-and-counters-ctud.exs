{scans, _} = Code.eval_file("instructions-timers-and-counters/scans.exs")

inputs = %{
  "infeed" => [0, 1, 0, 1, 0, 0, 1, 0, 1, 0, 1, 0, 0],
  "outfeed" => [0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0],
  "clear_pb" => [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0]
}

names = ["infeed", "outfeed", "clear_pb", "stock.cv", "stock.qu", "stock.qd", "buffer_full"]
scans.("instructions-timers-and-counters/buffer.ld", 10, inputs, names)
