# Anonymous visitors, tampered cookies, revoked sessions, and members.
class HostAppGateAccessChecks
  include HostAppGateAssertions

  def initialize(report)
    @report = report
  end

  def run
    HostAppGateBrowser.with_forgery(enabled: false) do
      anonymous_redirects
      anonymous_writes
      tampered_session
      revoked_session
      # Tampered and revoked sessions sign in on their own: those checks
      # destroy the cookie or the session row. The reads below share one.
      member = HostAppGateBrowser.sign_in("member@example.com")
      member_reads(member)
      member_controls(member)
      member_writes(member)
    end
  end

  private

  def anonymous_redirects
    @report.check("anonymous_redirects") do
      browser = HostAppGateBrowser.new
      assert_sign_in_redirect(browser.get(HostAppGate::ROOT_PATH))
      assert_sign_in_redirect(browser.get(HostAppGate::PRODUCTS_PATH))
    end
  end

  def anonymous_writes
    @report.check("anonymous_writes") do
      assert_denied_writes(HostAppGateBrowser.new) { |response| assert_sign_in_redirect(response) }
    end
  end

  def tampered_session
    @report.check("tampered_session") do
      browser = HostAppGateBrowser.sign_in("member@example.com")
      browser.tamper_session_cookie
      assert_sign_in_redirect(browser.get(HostAppGate::ROOT_PATH))
      assert_sign_in_redirect(browser.get(HostAppGate::PRODUCTS_PATH))
      assert_denied_writes(browser) { |response| assert_sign_in_redirect(response) }
    end
  end

  def revoked_session
    @report.check("revoked_session") do
      browser = HostAppGateBrowser.sign_in("member@example.com")
      browser.revoke_session("member@example.com")
      assert_sign_in_redirect(browser.get(HostAppGate::ROOT_PATH))
      assert_sign_in_redirect(browser.get(HostAppGate::PRODUCTS_PATH))
      assert_denied_writes(browser) { |response| assert_sign_in_redirect(response) }
    end
  end

  def member_reads(member)
    @report.check("member_index") { assert_lists_products(member.get(HostAppGate::PRODUCTS_PATH)) }
    @report.check("member_show") { assert_shows_product(member) }
    @report.check("member_dashboard") { assert_dashboard(member.get(HostAppGate::ROOT_PATH)) }
  end

  def member_controls(member)
    @report.check("member_index_controls") { refute_write_controls(member.get(HostAppGate::PRODUCTS_PATH)) }
    @report.check("member_show_controls") { refute_edit_link(member_show(member)) }
  end

  def member_writes(member)
    @report.check("member_new") { assert_forbidden(member.get("#{HostAppGate::PRODUCTS_PATH}/new")) }
    @report.check("member_create") { assert_member_denied(member, :post, HostAppGate::PRODUCTS_PATH, create_params) }
    @report.check("member_update") { assert_member_denied(member, :patch, product_path("Paper Filters"), rename_params) }
    @report.check("member_delete") { assert_member_denied(member, :delete, product_path("Paper Filters"), nil) }
    @report.check("member_bulk_archive") { assert_member_denied(member, :post, archive_path, ids_param("Paper Filters")) }
  end

  def assert_denied_writes(browser)
    product = Product.find_by!(name: "Paper Filters")
    each_denied_write(product) do |verb, path, params|
      before = HostAppGateData.snapshot
      response = browser.request(verb, path, params)
      yield response
      HostAppGateData.assert_unchanged(before)
    end
  end

  def each_denied_write(product)
    product_path = "#{HostAppGate::PRODUCTS_PATH}/#{product.id}"
    yield :post, HostAppGate::PRODUCTS_PATH, create_params("Anon Product")
    yield :patch, product_path, rename_params("Hacked Filters")
    yield :post, archive_path, { ids: [product.id] }
    yield :delete, product_path, nil
  end

  def assert_member_denied(browser, verb, path, params)
    before = HostAppGateData.snapshot
    assert_forbidden(browser.request(verb, path, params))
    HostAppGateData.assert_unchanged(before)
  end

  def assert_lists_products(response)
    assert_ok(response)
    assert_text(response, "Blue Mug")
    assert_text(response, "Steel Kettle")
  end

  def assert_shows_product(browser)
    response = member_show(browser)
    assert_ok(response)
    assert_text(response, "Green Teapot")
  end

  def assert_dashboard(response)
    assert_ok(response)
    assert_text(response, "Shop Admin")
  end

  def refute_write_controls(response)
    assert_ok(response)
    doc = document(response)
    # admin_index_controls is the pair: an admin does see New and bulk archive.
    # Edit is not on the index; member_show_controls covers it.
    raise HostAppGateFailure, "member index links to New" if new_product_link(doc)
    raise HostAppGateFailure, "member index offers bulk archive" if archive_control(doc)
  end

  def refute_edit_link(response)
    assert_ok(response)
    # admin_show_controls is the pair: an admin does see Edit.
    raise HostAppGateFailure, "member show links to Edit" if edit_link(document(response))
  end

  def member_show(browser)
    browser.get(product_path("Green Teapot"))
  end

  def product_path(name)
    "#{HostAppGate::PRODUCTS_PATH}/#{Product.find_by!(name: name).id}"
  end

  def archive_path
    "#{HostAppGate::PRODUCTS_PATH}/bulk_actions/archive"
  end

  def create_params(name = "Member Product")
    { record: { name: name, status: "active", category: "office", price: "1" } }
  end

  def rename_params(name = "Hacked Filters")
    { record: { name: name } }
  end

  def ids_param(name)
    { ids: [Product.find_by!(name: name).id] }
  end
end
