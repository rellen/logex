defmodule Logex.Runner.Paths do
  @moduledoc false
  # Decision 356 (RV-4): the files each runner of this VM holds, so that a runner refuses
  # at its start a file another runner of the VM holds, which the two would write over
  # each other. Internal: `Logex.Runner` alone claims and gives up its files, each path
  # expanded once at its start.
  #
  # - A runner's files are its store and its forces file, each with the `.tmp` beside it
  #   it is written through (`Logex.Retain.written/2`), and since decision 360 (RV-5) the
  #   copy a fresh start keeps of a store it dropped from, `<store>.dropped`, with its own
  #   `.tmp`, each `{path, role}`, the role `:retain`, `:forces`, `:dropped`, `{:tmp,
  #   :retain}`, `{:tmp, :forces}` or `{:tmp, :dropped}`; claimed all or none in its own
  #   process once its name is registered, before anything is written, and given up as it
  #   terminates, after its last write.
  # - A file is held by a runner whose process is alive: one that crashed or was killed,
  #   whose terminate/2 never ran, holds nothing, its claims taken over by the next runner
  #   that claims the file. So a path is free again once its holder stops, crashes or is
  #   killed.
  # - The claims live in a public table of the VM's own, `{path, pid, role}`, made by a
  #   process of its own that the first claim starts, unlinked, which holds the table as
  #   long as the VM runs and does nothing else. Since RV-4's review its group leader is
  #   the VM's `init`, not that of the process that started it: an application stopped
  #   kills every process whose group leader is its own, and the keeper, started by
  #   whichever runner of an application first claimed a file, would otherwise go with it
  #   and every other runner's claims with the table. Each claim is one `:ets.insert_new/2`,
  #   and a dead holder's is taken over by one `:ets.select_replace/2` of exactly its
  #   object, so that two runners that start at once on one file never both hold it.
  # - Two VMs on one file are the host's to avoid: nothing here sees another VM, nor a
  #   file reached by two paths through a link, each path expanded lexically.

  @table __MODULE__

  # Every file claimed for `pid`, `:ok`, or the first of them another live runner holds,
  # `{:held, path, holder, role}`, the holder's role for the path, nothing claimed then.
  # `alive?` tells a holder alive, `Process.alive?/1` but in a test of the take-over's
  # race, which stands its own in, the one seam to the window between a claim's look-up
  # of a holder and its replace of that holder's claim.
  def claim(files, pid, alive? \\ &Process.alive?/1),
    do: claimed(files, {pid, table(), alive?}, [])

  # The first of the files a live runner holds, `{:held, path, holder, role}`, or `:ok`,
  # claiming nothing: the check a start makes in its caller before it reads either file,
  # so that a file another runner holds is told as that, never as what is in it; the claim
  # in the runner's own process is the one that decides.
  def held(files), do: first_held(files, table())

  defp first_held([], _table), do: :ok

  defp first_held([{path, _role} | rest], table),
    do: live_holder(:ets.lookup(table, path), rest, table)

  defp live_holder([{path, holder, role}], rest, table),
    do: live(Process.alive?(holder), {:held, path, holder, role}, rest, table)

  defp live_holder([], rest, table), do: first_held(rest, table)

  defp live(true, held, _rest, _table), do: held
  defp live(false, _held, rest, table), do: first_held(rest, table)

  # Every file of `pid`'s given up, where it is still `pid`'s.
  def release(files, pid) do
    table = table()
    for {path, role} <- files, do: :ets.match_delete(table, {path, pid, role})
    :ok
  end

  defp claimed([], _claim, _done), do: :ok

  defp claimed([{path, role} = file | rest], {pid, table, _alive?} = claim, done),
    do: claiming(:ets.insert_new(table, {path, pid, role}), file, rest, claim, done)

  defp claiming(true, file, rest, claim, done), do: claimed(rest, claim, [file | done])

  defp claiming(false, {path, _role} = file, rest, {_pid, table, _alive?} = claim, done),
    do: holder(:ets.lookup(table, path), file, rest, claim, done)

  # The file's holder: alive, the claim refused and every file claimed before it given up;
  # down, its claim taken over where it is still that holder's, and otherwise tried again.
  defp holder([{_path, holder, _role} = held], file, rest, {_pid, _table, alive?} = claim, done),
    do: holder_alive(alive?.(holder), held, file, rest, claim, done)

  defp holder([], file, rest, claim, done), do: claimed([file | rest], claim, done)

  defp holder_alive(true, {path, holder, role}, _file, _rest, {pid, _table, _alive?}, done) do
    release(done, pid)
    {:held, path, holder, role}
  end

  defp holder_alive(false, held, {path, role} = file, rest, {pid, table, _alive?} = claim, done) do
    taken = :ets.select_replace(table, [{held, [], [{:const, {path, pid, role}}]}])
    taken_over(taken, file, rest, claim, done)
  end

  defp taken_over(1, file, rest, claim, done), do: claimed(rest, claim, [file | done])
  defp taken_over(0, file, rest, claim, done), do: claimed([file | rest], claim, done)

  # The VM's table, made the first time a runner claims a file.
  defp table, do: made(:ets.whereis(@table))

  defp made(:undefined) do
    starter = self()
    {keeper, ref} = spawn_monitor(fn -> kept(own_table(away()), starter) end)

    receive do
      {@table, ^keeper, :made} -> Process.demonitor(ref, [:flush])
      {:DOWN, ^ref, :process, ^keeper, _another_made_it} -> :ok
    end

    made(:ets.whereis(@table))
  end

  defp made(table), do: table

  # The keeper's group leader the VM's own, before it makes the table, so that no
  # application's stop takes the table down.
  defp away, do: Process.group_leader(self(), Process.whereis(:init))

  # The keeper: the table made, or another keeper's made first, which this one leaves to it.
  defp own_table(true) do
    :ets.new(@table, [:named_table, :public, :set])
  rescue
    ArgumentError -> nil
  end

  defp kept(nil, _starter), do: :ok

  defp kept(_table, starter) do
    send(starter, {@table, self(), :made})
    Process.sleep(:infinity)
  end
end
