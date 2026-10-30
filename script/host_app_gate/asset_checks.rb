require "json"
require "uri"

# Packaged import map, the assets it points at, and engine translations.
class HostAppGateAssetChecks
  include HostAppGateAssertions

  IMPORT_LINE = /\A\s*(?:import|export)\b/
  FROM_SPECIFIER = /\bfrom\s+["']([^"']+)["']/
  SIDE_EFFECT_IMPORT = /\A\s*import\s+["']([^"']+)["']/

  def initialize(report)
    @report = report
  end

  def run
    HostAppGateBrowser.with_forgery(enabled: false) do
      @admin = HostAppGateBrowser.sign_in("admin@example.com")
      importmap
      translations
    end
  end

  private

  def importmap
    @report.check("packaged_importmap") do
      page = @admin.get(HostAppGate::PRODUCTS_PATH)
      assert_ok(page)
      imports = import_map(page)
      names = required_pins
      names.each { |name| fetch_pin(@admin, imports, name) }
      names.join(" ")
    end
  end

  def translations
    @report.check("engine_translations") do
      index = @admin.get(HostAppGate::PRODUCTS_PATH)
      assert_ok(index)
      assert_text(index, "New Product")
      show = @admin.get("#{HostAppGate::PRODUCTS_PATH}/#{Product.find_by!(name: "Blue Mug").id}")
      assert_ok(show)
      assert_text(show, "Edit")
      "New Product, Edit"
    end
  end

  def controller_pins
    path = IronAdmin::Engine.root.join("config/importmap.rb")
    raise HostAppGateFailure, "package has no config/importmap.rb" unless path.file?

    pins = path.readlines.filter_map { |line| line[/^\s*pin\s+"([^"]+)"/, 1] }
    required = pins.select { |name| name == "iron_admin" || name.start_with?("iron_admin/") }
    raise HostAppGateFailure, "package import map has no iron_admin pin" unless required.include?("iron_admin")

    required
  end

  def required_pins
    controller_pins | javascript_specifiers
  end

  def javascript_specifiers
    root = IronAdmin::Engine.root.join("app/javascript")
    raise HostAppGateFailure, "package has no app/javascript" unless root.directory?

    Dir.glob(root.join("**/*.js").to_s).flat_map { |file| bare_specifiers(File.read(file)) }.uniq
  end

  def bare_specifiers(source)
    source.each_line.filter_map do |line|
      next unless line.match?(IMPORT_LINE)

      specifier = line[FROM_SPECIFIER, 1] || line[SIDE_EFFECT_IMPORT, 1]
      specifier if specifier && bare_module?(specifier)
    end
  end

  def bare_module?(specifier)
    !specifier.start_with?(".") && !specifier.start_with?("/")
  end

  def import_map(page)
    scripts = document(page).css("script[type='importmap']")
    raise HostAppGateFailure, "products index has no import map" if scripts.empty?

    imports = {}
    scripts.each { |script| imports.merge!(JSON.parse(script.text).fetch("imports")) }
    raise HostAppGateFailure, "products index has no iron_admin import map" unless imports.key?("iron_admin")

    imports
  end

  def fetch_pin(browser, imports, name)
    url = imports[name]
    raise HostAppGateFailure, "import map has no pin #{name}" if url.blank?
    raise HostAppGateFailure, "pin #{name} is not a URL" unless url.is_a?(String)

    path = URI.parse(url).path.to_s
    raise HostAppGateFailure, "pin #{name} has no path" if path.empty?

    response = browser.get(path, nil, accept: "*/*")
    return if response.status == 200

    raise HostAppGateFailure, "pin #{name} #{path} status #{response.status}"
  end
end
