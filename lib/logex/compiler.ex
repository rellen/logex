defmodule Logex.Compiler do
  def tokenize(source) do
    source |> String.to_charlist() |> :ladder_lexer.string()
  end

  def parse(tokens) do
    :ladder_parser.parse(tokens)
  end

  @instructions %{"xic" => {:xic, 1}, "xio" => {:xio, 1}, "ote" => {:ote, 1}, "mov" => {:mov, 2}}

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

  def evaluate(_, {false, env}), do: {false, env}

  def evaluate({:rung, branch}, env), do: evaluate(branch, env)

  def evaluate({:branches, branches}, {true, env}) do
    {outputs, new_env} =
      Enum.reduce(branches, {[], env}, fn branch, {outputs, env} ->
        {output, new_env} = evaluate(branch, {true, env})
        {[output | outputs], new_env}
      end)

    output = Enum.any?(outputs, fn output -> output == true end)
    {output, new_env}
  end

  def evaluate(branch, {true, env}) when is_list(branch) do
    Enum.reduce_while(branch, {true, env}, fn elem, {_, env} ->
      {output, new_env} = evaluate(elem, {true, env})

      if output do
        {:cont, {true, new_env}}
      else
        {:halt, {false, new_env}}
      end
    end)
  end

  def evaluate({:xic, [name: arg]}, {true, env}) do
    {Map.get(env, arg) == 1, env}
  end

  def evaluate({:xio, [name: arg]}, {true, env}) do
    {Map.get(env, arg) == 0, env}
  end

  def evaluate({:ote, [name: arg]}, {true, env}) do
    {true, Map.put(env, arg, 1)}
  end

  def evaluate({:mov, [arg1, {:name, arg2}]}, {true, env}) do
    {true, Map.put(env, arg2, get_arg(env, arg1))}
  end

  defp get_arg(_env, {:lit_int, val}), do: val
  defp get_arg(env, {:name, name}), do: Map.get(env, name)
end
