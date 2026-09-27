defmodule Logex.LexerBinariesTest do
  @moduledoc """
  Pins how a lexeme is represented, which no comparison of tokens can see. Grown byte by
  byte with `<<acc::binary, ch>>`, every name and number got its own off-heap, 256-byte
  writable binary, and token-dense sources lexed up to 2.2x slower than leex did — with
  every token right, so every other test stayed green.
  """
  use ExUnit.Case, async: true

  test "names and numbers are cut into heap binaries, not built into off-heap ones" do
    source = String.duplicate("xic a1 mov 123 hh\n", 50)
    :erlang.garbage_collect()
    before = off_heap_binaries()

    assert {:ok, tokens, _} = Logex.Lexer.tokenize(source)
    assert length(tokens) == 300
    assert off_heap_binaries() <= before
  end

  defp off_heap_binaries do
    {:binary, binaries} = Process.info(self(), :binary)
    length(binaries)
  end
end
