# Negative control: the host raises while booting, so the runner never
# reaches the checks. The wrapper must treat that as a failed run.
raise "broken runner"
