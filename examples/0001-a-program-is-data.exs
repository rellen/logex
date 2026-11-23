# The modules of the Elixir compiler and of the Erlang compiler.
compilers = [:elixir, :elixir_compiler, :elixir_module, :elixir_expand, :elixir_erl, :compile]
Enum.each(compilers, &Code.ensure_loaded!/1)
Enum.each(compilers, &:erlang.trace_pattern({&1, :_, :_}, true, [:global]))

# An online edit of motor.ld: compile, scan, accept, test, assemble.
edit = fn ->
  text = File.read!("motor.ld")
  {:ok, motor} = Logex.compile(text, name: "motor")
  changed = String.replace(text, "move 0 speed_sp", "move 600 speed_sp")
  {:ok, candidate} = Logex.compile(changed, name: "motor")
  state = Logex.Runtime.instance(motor)
  {_outputs, state} = Logex.Runtime.scan(motor, state, 10)
  {:ok, change, _report} = Logex.Edit.accept(motor, candidate, state)
  {change, state, _report} = Logex.Edit.test(change, state)
  {_program, _state, _report} = Logex.Edit.assemble(change, state)
end

# Count the calls into a compiler that a function makes, in each process it starts.
calls = fn function ->
  counter =
    spawn(fn ->
      count = fn count, n ->
        receive do
          {:trace, _pid, :call, _mfa} -> count.(count, n + 1)
          {:total, from} -> send(from, {:total, n})
        end
      end

      count.(count, 0)
    end)

  :erlang.trace(:new_processes, true, [:call, {:tracer, counter}])
  :erlang.trace(self(), true, [:call, {:tracer, counter}])
  function.()
  :erlang.trace(:all, false, [:call])
  ref = :erlang.trace_delivered(:all)

  receive do
    {:trace_delivered, :all, ^ref} -> send(counter, {:total, self()})
  end

  receive do
    {:total, n} -> n
  end
end

# The first edit loads the modules of logex.
edit.()

modules = length(:code.all_loaded())
atoms = :erlang.system_info(:atom_count)
edit_calls = calls.(edit)
new_modules = length(:code.all_loaded()) - modules
new_atoms = :erlang.system_info(:atom_count) - atoms

IO.puts("calls into a compiler: #{edit_calls}")
IO.puts("new modules: #{new_modules}")
IO.puts("new atoms: #{new_atoms}")

# The same count for 1 small Elixir module.
module = fn -> Code.compile_string("defmodule Lamp do def on, do: 1 end") end
IO.puts("1 Elixir module calls a compiler: #{calls.(module) > 0}")
