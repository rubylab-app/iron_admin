require_relative "failure"
require_relative "catalog"

# A check that raises is a failure. The result file lists the failed names,
# one per line, for the shell wrapper.
class HostAppGateReport
  def initialize
    @passed = []
    @failures = []
  end

  def check(name)
    detail = yield
    @passed << name
    line = "HOST_APP_GATE ok #{name}"
    line = "#{line} #{detail}" if detail.is_a?(String) && !detail.empty?
    $stdout.puts line
  rescue StandardError => e
    @failures << name
    $stdout.puts "HOST_APP_GATE FAILED #{name}: #{e.class}: #{e.message.to_s.lines.first.to_s.strip}"
  end

  def finish
    missing, unexpected = coverage
    write_result
    report_coverage(missing, unexpected)
    names = @failures.empty? ? "" : ": #{@failures.join(" ")}"
    $stdout.puts "HOST_APP_GATE summary #{@passed.size} passed, #{@failures.size} failed#{names}"
    $stdout.flush
    exit! 1 if @failures.any? || missing.any? || unexpected.any?
  end

  private

  def write_result
    path = ENV.fetch(HostAppGate::RESULT_ENV, nil)
    return if path.blank?

    File.write(path, @failures.join("\n"))
  end

  def coverage
    reported = @passed + @failures
    [HostAppGateCatalog::CHECKS - reported, reported - HostAppGateCatalog::CHECKS]
  end

  def report_coverage(missing, unexpected)
    if missing.empty? && unexpected.empty?
      $stdout.puts "HOST_APP_GATE coverage ok"
      return
    end

    $stdout.puts "HOST_APP_GATE coverage missing: #{missing.join(" ")}" if missing.any?
    $stdout.puts "HOST_APP_GATE coverage unexpected: #{unexpected.join(" ")}" if unexpected.any?
  end
end
