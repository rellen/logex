{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")

# The tags of a conveyor with a box counter. Each wrong text comes after them.
tags = """
var_input  start    bool
var_input  stop     bool
var_input  eye      bool
var_output motor    bool
var_output lamp     bool
var        boxes    ctu
var        t1       ton
var        lane_t   ton[4]
var        slot     int
var        count    dint
var        speed    real
var        status   word
var        pattern  dword
var        low      byte
var        weights  int[8]
var        copy     int[8]
"""

texts = [
  # The language
  "IF start THEN motor := 1; END_IF;",
  "LD start",
  "xic start jsr belt",
  # The declarations
  "var delay time",
  "var label string",
  "var colour (red, green)",
  "var level int(0..10)",
  "var p ref_to int",
  "var constant limit int 5",
  "var_in_out belt bool",
  "var_temp scratch int",
  "var_input gate bool at %IX0.0",
  "var_input gate bool at panel.i.0",
  # The literals
  "xic start ton t1 T#5s",
  "xic start move int#5 slot",
  "xic start move 8#17 slot",
  "xic start move 'a' slot",
  "xic start move true motor",
  # The arrays
  "var grid int[2,2,2,2]",
  "var bins array[1..8] of int",
  "var bins int[1..8]",
  "xic start move 1 weights[slot+1]",
  "xic start move weights copy",
  "xic start move 0 weights",
  "xic start ton lane_t[slot] 1000",
  # Bits
  "xic start move status.%B1 low",
  "xic speed.3 ote lamp",
  # Arithmetic and conversions
  "xic start round speed count",
  "xic start ceil speed speed",
  "xic start floor speed speed",
  "xic start bool_to_int eye count",
  "xic start int_to_bool slot lamp",
  "xic start bcd_to_int status slot",
  "xic start int_to_bcd slot status",
  "xic start real_to_dword speed pattern",
  # Instructions
  "xic start res t1",
  "xic start mcr",
  "lbl top\nxic start ote motor\nxic stop jmp top",
  "xic start ton t1 count",
  # The first scan and retained values
  "xic s:fs ote lamp",
  "xic first_scan ote lamp",
  "var persistent total dint",
  "var retain persistent total dint"
]

report.(1, texts, &Logex.compile(tags <> &1, name: "wrong"))

# A lamp that a long timer switches on. The preset is in ns.
lamp =
  "var_input start bool\nvar_output lamp bool\nvar long_t ton_ltime\n" <>
    "xic start ton long_t 500\nxic long_t.dn ote lamp"

report.(44, [lamp], &Logex.compile(&1, name: "lamp"))
