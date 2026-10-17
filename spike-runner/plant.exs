# Throwaway spike support (never landed): §4.4's plant, cut from docs/organisation.md with
# §4.3's motor and seal block, as config_edit_test.exs cuts it.
defmodule Spike.Plant do
  @doc_path Path.expand("../docs/organisation.md", __DIR__)

  defp document, do: File.read!(@doc_path)

  defp cut(after_text) do
    [_before, rest] = String.split(document(), after_text, parts: 2)
    [_before, block] = String.split(rest, "```\n", parts: 2)
    [text, _after] = String.split(block, "```", parts: 2)
    text
  end

  def plant_text do
    [_before, rest] = String.split(document(), "```\n// plant.", parts: 2)
    [plant, _after] = String.split("// plant." <> rest, "```", parts: 2)
    plant
  end

  def motor_ld, do: cut("**The motor, rewritten to use it**")
  def seal_ld, do: cut("**A function block type** is")

  @snapshot_ld """
  var_input a bool
  var_input b bool
  var_output a_was bool
  var_output b_was bool

  xic a ote a_was
  xic b ote b_was
  """

  def programs(motor \\ motor_ld()) do
    {:ok, seal} = Logex.compile(seal_ld(), name: "seal")
    {:ok, motor} = Logex.compile(motor, name: "motor", types: [seal])
    {:ok, snapshot} = Logex.compile(@snapshot_ld, name: "snapshot")
    %{"motor" => motor, "snapshot" => snapshot}
  end

  def config(text \\ plant_text(), programs \\ programs()) do
    {:ok, config} = Logex.Configuration.compile("plant", text, programs)
    config
  end
end
