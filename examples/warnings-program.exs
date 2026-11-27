{report, _} = Code.eval_file("warnings/report.exs")

{:ok, seal} =
  Logex.compile(
    "function_block seal\nvar_input start bool\nvar_input stop bool\nvar_output run bool\n" <>
      "( xic start | xic run ) xio stop ote run",
    name: "seal"
  )

cases = [
  {"a tag that no rung uses",
   "var_input start bool\nvar_output motor bool\nvar spare dint\nxic start ote motor"},
  {"var_output tags that a rung reads and no rung writes",
   "var_input start bool\nvar_output motor bool\nvar_output alarm bool\nvar_output speed_sp dint 1200\n" <>
     "var_output belt_lamp bool\nvar_output rate real\nvar_output mask word 16#ff\n" <>
     "var_output gain real 16777217.0\nvar_output steps dint[2]\nvar_output trims real[2] 1.5 2.5\n" <>
     "var limit dint 5\n" <>
     "xic start xic belt_lamp gt speed_sp 1000 gt rate 1.0 gt limit 3 ote motor\n" <>
     "xic start ne mask 0 gt gain 1.0 gt steps[0] 1 gt trims[0] 1.0 ote alarm"},
  {"instances that no instruction runs",
   "var_input eye bool\nvar_output full_lamp bool\nvar delay ton\nvar boxes ctud\n" <>
     "var belt seal\nxic eye xic delay.dn xic boxes.qu xic belt.run ote full_lamp"},
  {"arrays of instances, with some elements that no instruction runs",
   "var_input eye bool\nvar_output full_lamp bool\nvar lane_t ton[4]\nvar lane_c ctu[13]\n" <>
     "var belts seal[3]\nvar pulses tp[2]\nxic eye ton lane_t[0] 500\nxic eye ton lane_t[2] 500\n" <>
     "xic eye ctu lane_c[0] 5\ncal belts[1] eye 0 full_lamp\n" <>
     "xic lane_t[0].dn xic lane_c[0].q xic pulses[1].dn ote full_lamp"},
  {"a label that no jmp names",
   "var_input start bool\nvar_output motor bool\nlbl manual xic start ote motor"},
  {"instructions that read only literals",
   "var_input start bool\nvar_output lamp bool\nvar_output count int\nvar_output mask word\n" <>
     "var_output trim sint\nxic start eq 1 2 ote lamp\nxic start add 2 3 count\n" <>
     "xic start and 16#0f 3 mask\nxic start dint_to_sint 129 trim\nxic start neg 5 count\n" <>
     "xic start move 5 count"},
  {"comparisons with a literal at the limit of the type",
   "var_input boxes usint\nvar_input level int\nvar_output lamp bool\n" <>
     "( ge boxes 0 | gt boxes 255 | le 0 boxes | lt level -32768 ) ote lamp"},
  {"a long timer with a time that is not a whole number of ms",
   "var_input start bool\nvar_output lamp bool\nvar_output left lint\nvar cure ton_ltime\n" <>
     "xic start ton cure 1500000\nxic start ge cure.acc 3000 ote lamp\n" <>
     "xic start move 2500 cure.pre\nxic start sub 1500 cure.acc left\n" <>
     "xic start lreal_to_lint 1.5e6 cure.pre"},
  {"real literals with more digits than the type keeps",
   "var_input hz real\nvar_output speed real\nvar_output precise lreal\n" <>
     "mul hz 16777217.0 speed\nmul hz 0.12345678901234567890 precise\n" <>
     "mul hz 0.1 speed\nmul hz 37.1 speed"},
  {"real initial values with more digits than a real keeps",
   "var_input hz real\nvar_output speed real\nvar limit real 16777217.0\n" <>
     "var steps real[12] " <>
     Enum.map_join(1..12, " ", &"#{16_777_215 + 2 * &1}.0") <>
     "\n" <>
     "mul hz limit speed\nmul hz steps[0] speed"}
]

report.(1, cases, &Logex.compile(&1, name: "panel", types: [seal]), [])
