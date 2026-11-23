# Each case calls a function with wrong data. calls.exs prints the number of the case,
# the call and the message of the ArgumentError.
alias Logex.Configuration
alias Logex.Configuration.{Connection, Global, Instance, Task}
{calls, _} = Code.eval_file("configuration-file/calls.exs")
{types, _} = Code.eval_file("configuration-file/types.exs")

lamp = [
  name: "line_1",
  programs: [types["lamp"]],
  instances: [%Instance{name: "l1", type: "lamp"}],
  connections: [%Connection{instance: "l1", member: "on", to: 0}]
]

cases = [
  {"Configuration.new!(%{name: \"line_1\"})", fn -> Configuration.new!(%{name: "line_1"}) end},
  {"no name:", fn -> Configuration.new!(Keyword.delete(lamp, :name)) end},
  {"name: \"line-1\"", fn -> Configuration.new!(Keyword.put(lamp, :name, "line-1")) end},
  {"devices: []", fn -> Configuration.new!(lamp ++ [devices: []]) end},
  {"programs: [:lamp]", fn -> Configuration.new!(Keyword.put(lamp, :programs, [:lamp])) end},
  {"a task with priority: 1.5 and a task that is not there",
   fn ->
     Configuration.new!(
       Keyword.merge(lamp,
         tasks: [%Task{name: "fast", interval: 10, priority: 1.5}],
         instances: [%Instance{name: "l1", type: "lamp", task: "fsat"}]
       )
     )
   end},
  {"an instance with line: 3",
   fn ->
     Configuration.new!(
       Keyword.put(lamp, :instances, [%Instance{name: "l1", type: "lamp", line: 3}])
     )
   end},
  {"a global from Global.new!(\"t\", :time)",
   fn -> Configuration.new!(Keyword.put(lamp, :globals, [Global.new!("t", :time)])) end},
  {"a global named \"at\"",
   fn -> Configuration.new!(Keyword.put(lamp, :globals, [%Global{name: "at", type: :bool}])) end},
  {"a global from Global.new!(\"total\", :dint, initial: 1.5)",
   fn ->
     Configuration.new!(Keyword.put(lamp, :globals, [Global.new!("total", :dint, initial: 1.5)]))
   end},
  {"Global.new!(\"total\", :dint, retain: true, non_retain: true)",
   fn -> Global.new!("total", :dint, retain: true, non_retain: true) end},
  {"Global.new!(\"total\", :dint, retained: true)",
   fn -> Global.new!("total", :dint, retained: true) end},
  {"Global.new!(\"total\", :dint, retain: :yes)",
   fn -> Global.new!("total", :dint, retain: :yes) end},
  {"Global.new!(\"total\", :dint, at: \"panel.i.0\", at: \"panel.i.1\")",
   fn -> Global.new!("total", :dint, at: "panel.i.0", at: "panel.i.1") end},
  {"Global.new!(\"total\", :dint, %{retain: true})",
   fn -> Global.new!("total", :dint, %{retain: true}) end},
  {"Configuration.compile(\"line_1\", :text, %{})",
   fn -> Configuration.compile("line_1", :text, %{}) end},
  {"Configuration.compile(\"line_1\", \"\", %{\"lamb\" => lamp})",
   fn -> Configuration.compile("line_1", "", %{"lamb" => types["lamp"]}) end},
  {"Configuration.compile_file(:line_1)", fn -> Configuration.compile_file(:line_1) end},
  {"Configuration.watchdog(%Task{name: \"fast\", watchdog: 0})",
   fn -> Configuration.watchdog(%Task{name: "fast", watchdog: 0}) end}
]

calls.(135, cases)
