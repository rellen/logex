defmodule Logex.Compiler do
  def tokenize(source) do
    source |> String.to_charlist() |> :ladder_lexer.string()
  end

  def parse(tokens) do
    :ladder_parser.parse(tokens)
  end

  @instructions %{
    "xic" => {:xic, 1},
    "xio" => {:xio, 1},
    "ote" => {:ote, 1},
    "otl" => {:otl, 1},
    "otu" => {:otu, 1},
    "mov" => {:mov, 2}
  }

  def instructionize({:routine, {:rungs, rungs}}),
    do: {:routine, {:rungs, Enum.map(rungs, &instructionize(&1))}}

  def instructionize({:rung, branch}), do: {:rung, instructionize(branch)}

  def instructionize({:branches, branches}),
    do: {:branches, Enum.map(branches, &instructionize(&1))}

  def instructionize([{:branches, _branches} = head | tail]) do
    [instructionize(head) | instructionize(tail)]
  end

  def instructionize([{:name, name} | tail]) do
    {symbol, args} = Map.get(@instructions, name)

    [
      {symbol, Enum.take(tail, args)}
      | instructionize(Enum.drop(tail, args))
    ]
  end

  def instructionize([]), do: []

  def evaluate({:routine, {:rungs, rungs}}, {_, env}) do
    new_env =
      Enum.reduce(rungs, env, fn rung, env ->
        {_, new_env} = evaluate(rung, {true, env})
        new_env
      end)

    {true, new_env}
  end

  def evaluate({:rung, branch}, env), do: evaluate(branch, env)

  def evaluate({:branches, branches}, {input, env}) do
    {outputs, new_env} =
      Enum.reduce(branches, {[], env}, fn branch, {outputs, env} ->
        {output, new_env} = evaluate(branch, {input, env})
        {[output | outputs], new_env}
      end)

    output = Enum.any?(outputs, fn output -> output == true end)
    {output, new_env}
  end

  def evaluate(branch, {input, env}) when is_list(branch) do
    Enum.reduce(branch, {input, env}, fn elem, {input, env} ->
      evaluate(elem, {input, env})
    end)
  end

  def evaluate({:xic, [name: arg]}, {true, env}) do
    {Map.get(env, arg) == 1, env}
  end

  def evaluate({:xic, _}, {false, env}) do
    {false, env}
  end

  def evaluate({:xio, [name: arg]}, {true, env}) do
    {Map.get(env, arg) == 0, env}
  end

  def evaluate({:xio, _}, {false, env}) do
    {false, env}
  end

  def evaluate({:ote, [name: arg]}, {true, env}) do
    {true, Map.put(env, arg, 1)}
  end

  def evaluate({:ote, [name: arg]}, {false, env}) do
    {false, Map.put(env, arg, 0)}
  end

  def evaluate({:otl, [name: arg]}, {true, env}) do
    {true, Map.put(env, arg, 1)}
  end

  def evaluate({:otl, _}, {false, env}) do
    {false, env}
  end

  def evaluate({:otu, [name: arg]}, {true, env}) do
    {true, Map.put(env, arg, 0)}
  end

  def evaluate({:otu, _}, {false, env}) do
    {false, env}
  end

  def evaluate({:mov, [arg1, {:name, arg2}]}, {true, env}) do
    {true, Map.put(env, arg2, get_arg(env, arg1))}
  end

  def evaluate({:mov, _}, {false, env}) do
    {false, env}
  end

  defp get_arg(_env, {:lit_int, val}), do: val
  defp get_arg(env, {:name, name}), do: Map.get(env, name)
end
