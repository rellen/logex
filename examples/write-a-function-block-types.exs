block = File.read!("write-a-function-block/starter.ld")
{:ok, starter} = Logex.compile(block, name: "starter")
source = File.read!("write-a-function-block/conveyors.ld")
{:ok, conveyors} = Logex.compile(source, name: "conveyors", types: [starter])

state = Logex.Runtime.instance(conveyors)
state = Logex.Runtime.put_inputs(conveyors, state, %{"start_1" => 1})
{outputs, _state} = Logex.Runtime.scan(conveyors, state, 1000)
IO.puts("#{conveyors.name}: belt_1 = #{outputs["belt_1"]}")
