%{
  title: "use-counters/buffer.ld: buffer counts up and down, order counts down from its load",
  program: "use-counters/buffer.ld",
  step: 10,
  scans: 11,
  inputs: %{
    "new_order" => [{2, 1}, {3, 0}],
    "infeed" => [{3, 1}, {4, 0}, {5, 1}, {7, 0}, {8, 1}, {9, 0}],
    "outfeed" => [{9, 1}, {10, 0}, {11, 1}]
  },
  show: ["infeed", "outfeed", "buffer.cv", "buffer_full", "new_order", "order.cv", "order_done"]
}
