# Boot, the unpacked package, the admin routes, and the compiled engine CSS.
class HostAppGateBootChecks
  def initialize(report)
    @report = report
  end

  def run
    eager_load
    package_path
    admin_routes
    engine_stylesheet
  end

  private

  def eager_load
    @report.check("eager_load") { Rails.application.eager_load! }
  end

  def package_path
    @report.check("package_path") do
      expected = File.realpath(ENV.fetch(HostAppGate::PACKAGE_ENV))
      loaded = File.realpath(Gem.loaded_specs.fetch("iron_admin").full_gem_path)
      raise HostAppGateFailure, "loaded #{loaded}, expected #{expected}" unless loaded == expected

      engine_root = File.realpath(IronAdmin::Engine.root)
      raise HostAppGateFailure, "engine root #{engine_root}, expected #{expected}" unless engine_root == expected

      # run already rejects a package that contains spec/ or lacks engine.rb.
      assert_loaded_features(expected)
      expected
    end
  end

  def admin_routes
    @report.check("admin_routes") do
      expect_route(HostAppGate::ROOT_PATH, :get, "iron_admin/dashboard", "index")
      expect_route(HostAppGate::PRODUCTS_PATH, :get, "iron_admin/resources", "index")
      expect_route("#{HostAppGate::PRODUCTS_PATH}/new", :get, "iron_admin/resources", "new")
      expect_route("#{HostAppGate::PRODUCTS_PATH}/bulk_actions/archive", :post, "iron_admin/resources", "execute_bulk_action")
    end
  end

  def engine_stylesheet
    @report.check("engine_stylesheet") do
      css_path = Rails.root.join("app/assets/builds/tailwind.css")
      raise HostAppGateFailure, "missing #{css_path}" unless css_path.file?

      css = css_path.read
      HostAppGate::SOURCE_CLASSES.each do |glob, token|
        raise HostAppGateFailure, "compiled CSS has no #{token} from #{glob}" unless css_includes_class?(css, token)
        raise HostAppGateFailure, "#{token} also appears in the host app" if host_defines?(token)
      end

      HostAppGate::SOURCE_CLASSES.values.join(" ")
    end
  end

  def expect_route(path, method, controller, action)
    route = Rails.application.routes.recognize_path(path, method: method)
    return if route[:controller] == controller && route[:action] == action

    raise HostAppGateFailure, "#{method} #{path} routed to #{route[:controller]}##{route[:action]}"
  end

  def assert_loaded_features(package)
    $LOADED_FEATURES.each do |feature|
      resolved = resolve_feature(feature)
      next unless resolved
      next unless iron_admin_lib?(resolved)
      next if resolved == package || resolved.start_with?("#{package}/")

      raise HostAppGateFailure, "loaded #{resolved} outside the package"
    end
  end

  def resolve_feature(feature)
    return File.realpath(feature) if File.absolute_path(feature) == feature && File.exist?(feature)

    $LOAD_PATH.each do |dir|
      candidate = File.join(dir, feature)
      return File.realpath(candidate) if File.exist?(candidate)
    end
    nil
  end

  def iron_admin_lib?(path)
    return true if path.include?("/lib/iron_admin/")

    parts = path.split("/")
    lib_at = parts.rindex("lib")
    return false unless lib_at&.positive?

    parent = parts[lib_at - 1]
    parent == "iron_admin" || parent.start_with?("iron_admin-")
  end

  def css_includes_class?(css, token)
    escaped = token.gsub(/([^A-Za-z0-9_-])/) { |char| Regexp.escape("\\#{char}") }
    css.match?(/\.#{escaped}(?=[{:,\s])/)
  end

  def host_defines?(token)
    pattern = /(?<![A-Za-z0-9_:-])#{Regexp.escape(token)}(?![A-Za-z0-9_:-])/
    Dir.glob(Rails.root.join("app/**/*.{erb,haml,rb,js,css}").to_s).any? do |file|
      next false if file.include?("/builds/")

      File.read(file).match?(pattern)
    end
  end
end
