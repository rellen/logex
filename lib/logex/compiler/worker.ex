defmodule Logex.Compiler.Worker do
  @moduledoc false

  # Decision 520 (b, RV-20): `Logex.compile/2`, `Logex.compile_file/1` and
  # `Logex.compile_files/1` each run `Logex.Compiler`'s own in a process of its own, its
  # allowance of binaries off its heap sized to its text, and hand its result back to the
  # caller, which sees the same result it would have seen had it compiled itself.
  #
  # Why: a program keeps its source text (decision 54), so a compile holds it over its
  # work, and with its refusals' messages the binaries it held passed what a process may
  # hold off its heap before its collections turn full ones, 46,422 words by default:
  # each young collection that moved them to the old heap was followed by a full one,
  # copying the whole heap, 7,096 of some 54,000 for a box counter's 280 KB program with
  # 2,000 names gone (RV-8's review, 52 s). A process's `min_bin_vheap_size` is that
  # allowance; a fresh process given one past what its text holds makes none of them.
  # OTP 28 takes a spawn's `min_bin_vheap_size` only beside another of its heap's options,
  # measured: alone it is dropped and the process keeps 46,422, so it is always given with
  # the caller's `min_heap_size`. A file's text is not known before it is read, so the
  # loader's process raises its own allowance as it reads each file (`allowed/1`).
  #
  # The process takes the caller's priority and heap settings, its `min_heap_size`,
  # `max_heap_size` and `fullsweep_after`, so a compile runs as it ran in the caller, a
  # cost test's heap no collection visits among them, and a host's limit of its heap holds
  # it still; its group leader is the caller's, as a spawn's always is, and it reads and
  # writes no process dictionary, the caller's or its own. It is linked to the caller and
  # monitored, so a caller that exits, killed by a host's own time limit among them,
  # takes it with it, its work never left running; and it unlinks itself before it
  # answers, so a caller that traps exits is sent nothing of it. A compile killed from
  # outside takes its caller with it, with its reason, trapping exits or not, as a
  # compile killed in the caller would have. A mistake it raises, a host's
  # `ArgumentError` among them, is raised again in the caller, its message and stack as
  # they were. And the caller is charged the reductions the compile's process spent, so
  # that what the caller counts of its own work, `Process.info(self(), :reductions)` as
  # every cost test of logex reads it, holds the whole compile wherever it ran.
  #
  # The process runs this module's `serve/1`, spawned by module, function and arguments,
  # never a closure, and it calls `Logex.Compiler`'s three, which take a source text and
  # paths (decision 432: no closure of `Logex.Compiler`'s, nor any export of it but
  # `compile_file/1` and `compile_files/1`, reaches the loader's own compile).

  # The most a call to `:erlang.bump_reductions/1` charges, a time slice's reductions.
  @slice 4000

  @doc false
  def compile(source, options), do: apart({:compile, source, options}, words(source))

  @doc false
  def compile_file(path), do: apart({:file, path}, 0)

  @doc false
  def compile_files(paths), do: apart({:files, paths}, 0)

  @doc false
  # Run in the compile's own process: the caller's tag first, then the work, its result or
  # what it raised, and the reductions it spent, sent back.
  def serve(work) do
    receive do
      {caller, ref} ->
        outcome = outcome(work)
        {:reductions, spent} = Process.info(self(), :reductions)
        Process.unlink(caller)
        send(caller, {ref, outcome, spent})
    end
  end

  @doc false
  # Decision 520: the loader's process raises its own allowance as it reads each text it
  # holds, since none is known before it is read: to twice the binaries it then holds off
  # its heap, the text among them, beside the VM's own allowance, never lowering it. Read
  # from what the process holds, not added to what it allowed, since the VM rounds an
  # allowance up to a heap's size, a step of up to half again, so that adding to it at
  # each of a chain's files would compound those steps past any size the VM has.
  def allowed(_text) do
    [garbage_collection: settings, garbage_collection_info: held] =
      Process.info(self(), [:garbage_collection, :garbage_collection_info])

    {:min_bin_vheap_size, vm} = :erlang.system_info(:min_bin_vheap_size)
    allowance = vm + 2 * (held[:bin_vheap_size] + held[:bin_old_vheap_size])

    Process.flag(:min_bin_vheap_size, max(settings[:min_bin_vheap_size], allowance))
  end

  defp apart(work, words) do
    {pid, ref} =
      :erlang.spawn_opt(__MODULE__, :serve, [work], [:link, :monitor | settings(words)])

    send(pid, {self(), ref})

    receive do
      {^ref, outcome, spent} ->
        Process.demonitor(ref, [:flush])
        charged(spent)
        given(outcome)

      {:DOWN, ^ref, :process, ^pid, reason} ->
        exit(reason)
    end
  end

  # The work's result, or what it raised, thrown or exited with, and where.
  defp outcome(work) do
    {:ok, worked(work)}
  catch
    kind, reason -> {kind, reason, __STACKTRACE__}
  end

  defp worked({:compile, source, options}), do: Logex.Compiler.compile(source, options)
  defp worked({:file, path}), do: Logex.Compiler.compile_file(path)
  defp worked({:files, paths}), do: Logex.Compiler.compile_files(paths)

  defp given({:ok, result}), do: result
  defp given({kind, reason, stack}), do: :erlang.raise(kind, reason, stack)

  # The caller's priority and heap settings, its allowance of binaries off its heap raised
  # by twice its text's words and the VM's own allowance beside them.
  defp settings(words) do
    [priority: priority, garbage_collection: gc] =
      Process.info(self(), [:priority, :garbage_collection])

    [
      priority: priority,
      min_heap_size: gc[:min_heap_size],
      max_heap_size: gc[:max_heap_size],
      fullsweep_after: gc[:fullsweep_after],
      min_bin_vheap_size: gc[:min_bin_vheap_size] + 2 * words
    ]
  end

  defp words(text) when is_binary(text), do: div(byte_size(text), :erlang.system_info(:wordsize))
  defp words(_not_text), do: 0

  # The reductions the compile's process spent, charged to the caller a time slice at a
  # time until its own count has grown by them, so the caller's count holds them exactly.
  defp charged(spent) do
    {:reductions, now} = Process.info(self(), :reductions)
    charge(now + spent)
  end

  defp charge(target) do
    {:reductions, now} = Process.info(self(), :reductions)
    charging(target - now, target)
  end

  defp charging(left, target) when left > 0 do
    :erlang.bump_reductions(min(left, @slice))
    charge(target)
  end

  defp charging(_left, _target), do: :ok
end
