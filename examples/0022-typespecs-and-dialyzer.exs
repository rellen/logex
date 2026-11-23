# The modules of the host contract: the way in (decision 514), then the tools of the host
# and the parts of a configuration (decision 523).
contract = [
  Logex,
  Logex.Runtime,
  Logex.Edit,
  Logex.Configuration,
  Logex.Configuration.Edit,
  Logex.Runner,
  Logex.IO,
  Logex.Tag,
  Logex.Configuration.Task,
  Logex.Configuration.Global,
  Logex.Configuration.Instance,
  Logex.Configuration.Connection,
  Logex.IO.Point,
  Logex.IO.Sim,
  Logex.Runner.Clock,
  Logex.Runner.Clock.Manual,
  Logex.Runner.Clock.Monotonic
]

# Reads the specs and the opaque types of a module from its compiled file.
specs = fn module ->
  {:ok, specs} = Code.Typespec.fetch_specs(module)
  length(specs)
end

opaque = fn module ->
  {:ok, types} = Code.Typespec.fetch_types(module)
  for {:opaque, {name, _type, _parameters}} <- types, do: "#{name}()"
end

# Gives "" for no opaque type, and the list after a comma for each other list.
shown = fn
  [] -> ""
  names -> ", opaque " <> Enum.join(names, " and ")
end

IO.puts("1. The host contract")

for module <- contract do
  IO.puts("   #{inspect(module)}: #{specs.(module)} specs" <> shown.(opaque.(module)))
end

IO.puts("   #{length(contract)} modules, #{Enum.sum(Enum.map(contract, specs))} specs")

# Gives the moduledoc of a module on 1 line, or "" for a hidden module.
moduledoc = fn
  {:docs_v1, _, :elixir, _, %{"en" => text}, _, _} -> String.replace(text, ~r/\s+/, " ")
  _hidden -> ""
end

# A module outside the contract ends its moduledoc with 1 sentence that says so. The
# script loads the application of logex to read its list of modules.
_ = Application.load(:logex)
sentence = "Outside the host contract, this module takes logex's own data unguarded"
outside? = &String.contains?(moduledoc.(Code.fetch_docs(&1)), sentence)
outside = Enum.filter(Application.spec(:logex, :modules), outside?)
IO.puts("2. Outside the contract")
IO.puts("   #{length(outside)} modules, #{Enum.sum(Enum.map(outside, specs))} specs")

# Runs a call and prints the exception that it raises.
raised = fn call ->
  try do
    IO.puts("   returned " <> inspect(call.()))
  rescue
    error -> IO.puts("   #{inspect(error.__struct__)}: " <> Exception.message(error))
  end
end

IO.puts(~s(3. The name "motor" in place of the program motor))
raised.(fn -> Logex.Runtime.instance("motor") end)
raised.(fn -> Logex.Program.initial_env("motor") end)
