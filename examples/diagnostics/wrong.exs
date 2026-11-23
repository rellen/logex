# Copies the 5 wrong files of the page Diagnostics into the directory `wrong` of a new
# temporary directory. Each file gets its name without `.txt`. Returns the path of the
# new directory.
names = ["conveyor.ld", "seal.ld", "belts.ld", "fan-2.ld", "line.logex"]

dir = Path.join(System.tmp_dir!(), "diagnostics-#{System.pid()}")
File.rm_rf!(dir)
File.mkdir_p!(Path.join(dir, "wrong"))

for name <- names do
  File.cp!(Path.join("diagnostics/wrong", name <> ".txt"), Path.join([dir, "wrong", name]))
end

dir
