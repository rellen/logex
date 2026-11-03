defmodule Logex.Runner.Paths do
  @moduledoc false
  # Decision 356 (RV-4): the files each runner of this VM holds, so that a runner refuses
  # at its start a file another runner of the VM holds, which the two would write over
  # each other. Internal: `Logex.Runner` alone claims and gives up its files, each path
  # expanded once at its start.
  #
  # - A runner's files are its store and its forces file, each with the `.tmp` beside it
  #   it is written through (`Logex.Retain.written/2`), and since decision 360 (RV-5) the
  #   copies a start keeps of its store, written through their own `.tmp`,
  #   `<store>.dropped.tmp`, each `{path, role}`, the role `:retain`, `:forces`, `{:tmp,
  #   :retain}`, `{:tmp, :forces}` or `{:tmp, :dropped}`; claimed all or none in its own
  #   process once its name is registered, before anything is written, and given up as it
  #   terminates, after its last write.
  # - Since decision 418 (RV-13) each copy is a name of its own, `<store>.dropped.<n>`,
  #   n one past the highest that stands (`Logex.Runner.Writer.copy/3`), none replaced,
  #   where decision 360 had one, `<store>.dropped`; a runner holds every copy's name of
  #   its store, which no row of the table can claim, so that a claim is checked against
  #   them once its rows are in: a file of the runner's that is a copy's name of a store
  #   another live runner holds, `x.dropped.3` beside the store `x`, and a store of the
  #   runner's one of whose copies' names another live runner holds as any file of its
  #   own, are each refused, `{:held, path, holder, role}`, as a row another holds is, the
  #   role `:dropped` for a copy's name, so that no runner of this VM writes at a name
  #   another's copies are made under. Every row is put in before the check, so that of two
  #   starts at once whose files cross so, one at least sees the other's and is refused
  #   (crossed/3). An unnumbered `<store>.dropped` an earlier runner left is no copy's name
  #   and no file a runner writes, kept as it stands (provisional); a store or forces file
  #   named so is written through `<store>.dropped.tmp`, the copies' `.tmp`, and refused
  #   as that `.tmp`'s.
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
  #   file reached by two paths through a linked directory, each path expanded lexically,
  #   a store or forces file that is itself a link refused at the start (RV-5).

  @table __MODULE__

  # Every file claimed for `pid`, `:ok`, or the first of them another live runner holds,
  # `{:held, path, holder, role}`, the holder's role for the path, nothing claimed then.
  # `alive?` tells a holder alive, `Process.alive?/1` but in a test of the take-over's
  # race, which stands its own in, the one seam to the window between a claim's look-up
  # of a holder and its replace of that holder's claim.
  def claim(files, pid, alive? \\ &Process.alive?/1),
    do: crossed_claim(claimed(files, {pid, table(), alive?}, []), files, pid)

  defp crossed_claim(:ok, files, pid), do: uncrossed(crossed(files, pid, table()), files, pid)
  defp crossed_claim(held, _files, _pid), do: held

  defp uncrossed(:ok, _files, _pid), do: :ok

  defp uncrossed(held, files, pid) do
    release(files, pid)
    held
  end

  # The first of the files a live runner holds, `{:held, path, holder, role}`, or `:ok`,
  # claiming nothing: the check a start makes in its caller before it reads either file,
  # so that a file another runner holds is told as that, never as what is in it; the claim
  # in the runner's own process is the one that decides.
  def held(files), do: crossed_held(first_held(files, table()), files)

  defp crossed_held(:ok, files), do: crossed(files, nil, table())
  defp crossed_held(held, _files), do: held

  # Decision 418: a store's copy named, `<store>.dropped.<n>`, n in decimal.
  def copy(store, n), do: store <> ".dropped." <> Integer.to_string(n)

  # The store and number a path names as a copy, `{store, n}`, or nil: a path whose end
  # after its last `.dropped.` is a whole number in decimal digits, `x.dropped.3` and
  # `x.dropped.007` among them, the number by its value; `x.dropped`, `x.dropped.tmp` and
  # `x.dropped.3.tmp` none.
  def copy_of(path), do: numbered(:binary.matches(path, ".dropped."), path)

  defp numbered([], _path), do: nil

  defp numbered(matches, path) do
    {at, length} = List.last(matches)
    count = byte_size(path) - at - length
    digits(digits?(binary_part(path, at + length, count)), path, at, count)
  end

  defp digits(true, path, at, count),
    do: {binary_part(path, 0, at), String.to_integer(binary_part(path, byte_size(path), -count))}

  defp digits(false, _path, _at, _count), do: nil

  defp digits?(""), do: false
  defp digits?(text), do: all_digits?(text)

  defp all_digits?(<<c, rest::binary>>) when c in ?0..?9, do: all_digits?(rest)
  defp all_digits?(<<>>), do: true
  defp all_digits?(_other), do: false

  # Decision 418: the runner's files against every copy's name of a store another live
  # runner holds, and its store's copies' names against every file another live runner
  # holds, after its rows are in where it claims (`pid` its own, nil for the caller's
  # check): the first that crosses, `{:held, path, holder, role}`, its own file a copy's
  # name with the role `:dropped`, or another's file at one of its store's copies' names
  # with that file's role, or `:ok`.
  defp crossed(files, pid, table) do
    others = for {_path, holder, _role} = row <- :ets.tab2list(table), holder != pid, do: row
    first_crossed(files, Enum.filter(others, &alive?/1))
  end

  defp alive?({_path, holder, _role}), do: Process.alive?(holder)

  defp first_crossed([], _others), do: :ok

  defp first_crossed([{path, role} | rest], others),
    do: crossing(copy_held(copy_of(path), others, path), role, path, rest, others)

  defp crossing(nil, :retain, path, rest, others),
    do: copies_held(Enum.find(others, &copy_named?(&1, path)), rest, others)

  defp crossing(nil, _role, _path, rest, others), do: first_crossed(rest, others)
  defp crossing(held, _role, _path, _rest, _others), do: held

  defp copy_held(nil, _others, _path), do: nil

  defp copy_held({store, _n}, others, path),
    do: copy_holder(Enum.find(others, &match?({^store, _holder, :retain}, &1)), path)

  defp copy_holder(nil, _path), do: nil
  defp copy_holder({_store, holder, :retain}, path), do: {:held, path, holder, :dropped}

  defp copy_named?({other, _holder, _role}, store), do: match?({^store, _n}, copy_of(other))

  defp copies_held(nil, rest, others), do: first_crossed(rest, others)
  defp copies_held({other, holder, role}, _rest, _others), do: {:held, other, holder, role}

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
