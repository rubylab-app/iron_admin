require "uri"
require_relative "recipe"

# The documented Rails 8 recipe: false denies, and the minimal layout has no
# way back into the admin. Installed from the guide at run time.
class HostAppGateRecipeChecks
  include HostAppGateAssertions

  def initialize(report)
    @report = report
  end

  def run
    saved = configuration_snapshot
    @install_error = install
    HostAppGateBrowser.with_forgery(enabled: false) do
      anonymous
      tampered
      revoked
      member
      admin
    end
  ensure
    restore_configuration(saved)
  end

  private

  def install
    HostAppGateRecipe.install!
    nil
  rescue StandardError => e
    e
  end

  def anonymous
    @report.check("recipe_anonymous") do
      guard!
      browser = HostAppGateBrowser.new
      assert_minimal_denial(browser.get(HostAppGate::ROOT_PATH))
      assert_minimal_denial(browser.get(HostAppGate::PRODUCTS_PATH))
    end
  end

  def tampered
    @report.check("recipe_tampered_session") do
      guard!
      browser = live_admin_session
      browser.tamper_session_cookie
      assert_minimal_denial(browser.get(HostAppGate::ROOT_PATH))
      assert_minimal_denial(browser.get(HostAppGate::PRODUCTS_PATH))
    end
  end

  def revoked
    @report.check("recipe_revoked_session") do
      guard!
      browser = live_admin_session
      browser.revoke_session("admin@example.com")
      assert_minimal_denial(browser.get(HostAppGate::ROOT_PATH))
      assert_minimal_denial(browser.get(HostAppGate::PRODUCTS_PATH))
    end
  end

  def member
    @report.check("recipe_member") do
      guard!
      browser = HostAppGateBrowser.sign_in("member@example.com")
      assert_minimal_denial(browser.get(HostAppGate::ROOT_PATH))
      assert_minimal_denial(browser.get(HostAppGate::PRODUCTS_PATH))
    end
  end

  def admin
    @report.check("recipe_admin") do
      guard!
      browser = HostAppGateBrowser.sign_in("admin@example.com")
      assert_admin_shell(browser.get(HostAppGate::ROOT_PATH))
      assert_admin_policy(browser)
    end
  end

  def guard!
    raise @install_error if @install_error
  end

  def live_admin_session
    browser = HostAppGateBrowser.sign_in("admin@example.com")
    assert_admin_shell(browser.get(HostAppGate::ROOT_PATH))
    browser
  end

  def assert_admin_policy(browser)
    index = browser.get(HostAppGate::PRODUCTS_PATH)
    assert_admin_shell(index)
    doc = document(index)
    raise HostAppGateFailure, "admin index has no New link" unless new_product_link(doc)
    raise HostAppGateFailure, "admin index has no archive control" unless archive_control(doc)

    assert_ok(browser.get("#{HostAppGate::PRODUCTS_PATH}/new"))
  end

  def configuration_snapshot
    config = IronAdmin.configuration
    { authenticate: config.authenticate_block, current_user: config.current_user_block, title: config.title }
  end

  def restore_configuration(saved)
    return if saved.nil?

    config = IronAdmin.configuration
    config.authenticate(&saved.fetch(:authenticate))
    config.current_user(&saved.fetch(:current_user))
    config.title = saved.fetch(:title)
  end

  def assert_minimal_denial(response)
    assert_forbidden(response)
    doc = document(response)
    raise HostAppGateFailure, "authentication denial rendered the sidebar" if sidebar(doc)
    raise HostAppGateFailure, "authentication denial links into the admin" if admin_link(doc)

    assert_text(response, "Not authorized")
  end

  def assert_admin_shell(response)
    assert_ok(response)
    raise HostAppGateFailure, "admin page has no sidebar" unless sidebar(document(response))
  end

  def sidebar(doc)
    doc.at_css("[data-controller~='cp-sidebar']")
  end

  def admin_link(doc)
    doc.css("a[href]").any? { |link| admin_path?(link["href"]) }
  end

  def admin_path?(href)
    return false if href.blank?

    path = URI.parse(href).path.to_s
    path == HostAppGate::ROOT_PATH || path.start_with?("#{HostAppGate::ROOT_PATH}/")
  rescue URI::InvalidURIError
    false
  end
end
