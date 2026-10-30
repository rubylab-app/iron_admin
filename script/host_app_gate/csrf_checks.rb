require_relative "html_form"

# Real CSRF, separate from the fast checks. Forgery protection and
# per-form tokens stay on. The bulk POST sends the token rendered in the
# page and no X-CSRF-Token header.
class HostAppGateCsrfChecks
  include HostAppGateAssertions

  def initialize(report)
    @report = report
  end

  def run
    HostAppGateBrowser.with_forgery(enabled: true) do
      HostAppGateBrowser.with_per_form_tokens do
        sign_in
        bulk_archive
        rejected_bulk_archive
        rejected_create
      end
    end
  end

  private

  def sign_in
    @report.check("csrf_sign_in") do
      browser = HostAppGateBrowser.new
      page = browser.get(HostAppGate::SIGN_IN_PATH)
      assert_ok(page)
      token = authenticity_token(page, "form")
      # Same limit as HostAppGateBrowser.sign_in: 10 creates per 3 minutes.
      HostAppGateBrowser.clear_sign_in_rate_limit
      response = browser.post("/session", sign_in_params(token))
      browser.assert_signed_in(response, "admin@example.com")
      @browser = browser
    end
  end

  def bulk_archive
    @report.check("csrf_bulk_archive") do
      raise HostAppGateFailure, "sign-in did not leave a session" unless @browser

      page = @browser.get(HostAppGate::PRODUCTS_PATH)
      assert_ok(page)
      target = Product.find_by!(name: "White Cup")
      bystander = Product.find_by!(name: "Blue Mug")
      before = bystander.attributes
      path, payload = HostAppGateHtmlForm.bulk_archive(document(page), [target.id])
      response = @browser.post(path, payload)
      assert_redirect(response)
      assert_archived(target, bystander, before)
    end
  end

  def rejected_bulk_archive
    params = { ids: [stable_id] }
    reject_post("csrf_bulk_archive_without_token", archive_path, params)
    reject_post("csrf_bulk_archive_tampered_token", archive_path, params) do
      "#{page_token(HostAppGate::PRODUCTS_PATH, "#bulk-actions-form")}x"
    end
  end

  def rejected_create
    fields = { record: { name: "Rejected Lamp", status: "active", category: "office", price: "1" } }
    reject_post("csrf_create_without_token", HostAppGate::PRODUCTS_PATH, fields)
    reject_post("csrf_create_tampered_token", HostAppGate::PRODUCTS_PATH, fields) do
      "#{page_token("#{HostAppGate::PRODUCTS_PATH}/new", "form")}x"
    end
  end

  def reject_post(name, path, params)
    @report.check(name) do
      raise HostAppGateFailure, "sign-in did not leave a session" unless @browser

      token = block_given? ? yield : nil
      before = HostAppGateData.snapshot
      payload = params.dup
      payload[:authenticity_token] = token unless token.nil?
      assert_unprocessable(@browser.post(path, payload))
      HostAppGateData.assert_unchanged(before)
    end
  end

  def page_token(path, scope)
    page = @browser.get(path)
    assert_ok(page)
    authenticity_token(page, scope)
  end

  def stable_id
    Product.find_by!(name: "Blue Mug").id
  end

  def authenticity_token(response, scope)
    field = document(response).at_css("#{scope} input[name='authenticity_token']")
    value = field && field["value"]
    raise HostAppGateFailure, "no authenticity token in #{scope}" if value.blank?

    value
  end

  def sign_in_params(token)
    { email_address: "admin@example.com", password: HostAppGate::PASSWORD, authenticity_token: token }
  end

  def archive_path
    "#{HostAppGate::PRODUCTS_PATH}/bulk_actions/archive"
  end

  def assert_archived(product, bystander, before)
    product.reload
    raise HostAppGateFailure, "#{product.name} was not archived" unless product.archived? && product.archived_at.present?
    raise HostAppGateFailure, "#{bystander.name} changed" unless bystander.reload.attributes == before
  end
end
