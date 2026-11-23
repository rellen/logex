{scans, _} = Code.eval_file("instructions-jump-and-call/scans.exs")
{:ok, program} = Logex.compile_file("instructions-jump-and-call/sorter.ld")

inputs = %{
  "auto" => [0, 1, 1, 1, 1, 1, 1, 0],
  "lane" => [0, 0, 0, 0, 1, 5, 1, 1],
  "eyes" => [[1, 0], [1, 0], [1, 0], [0, 0], [0, 1], [0, 1], [0, 1], [0, 0]]
}

names = ["auto", "lane", "ran", "k.box", "k.seen", "kick"]
scans.(program, 10, inputs, names)
