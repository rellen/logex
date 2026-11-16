{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")
{:ok, edges} = Logex.compile_file("instructions-contacts-and-coils/edges.ld")

shared_text = """
var_input    eye    bool
var_output   lamp   bool
var_external memory bool
xic eye ons memory ote lamp
"""

{:ok, shared} = Logex.compile(shared_text, name: "shared")

configurations = [
  "task pick single eye_1 priority 0\nvar_global eye_1 bool\n" <>
    "program e1 edges with pick\n  e1.eye eye_1",
  "task fast interval 10 priority 1\nvar_global memory bool\n" <>
    "program a1 shared with fast\n  a1.eye 0\nprogram a2 shared with fast\n  a2.eye 0"
]

types = %{"edges" => edges, "shared" => shared}
report.(8, configurations, &Logex.Configuration.compile("line", &1, types))
