require "nokogiri"
require "uri"

# HTML assertions for the host-app gate. A 500 is never a denial.
module HostAppGateAssertions
  module_function

  def assert_sign_in_redirect(response)
    reject_server_error(response, "a denial")
    raise HostAppGateFailure, "status #{response.status}, expected a redirect to sign-in" unless response.redirect?

    location = URI.parse(response.location).path
    return if location == HostAppGate::SIGN_IN_PATH

    raise HostAppGateFailure, "redirected to #{location}, expected #{HostAppGate::SIGN_IN_PATH}"
  end

  def assert_forbidden(response)
    reject_server_error(response, "a denial")
    return if response.status == 403

    raise HostAppGateFailure, "status #{response.status}, expected 403"
  end

  def assert_ok(response)
    status = response.status
    raise HostAppGateFailure, "status #{status}, expected 200" unless status == 200
  end

  def assert_redirect(response)
    reject_server_error(response, "a redirect")
    return if response.redirect?

    raise HostAppGateFailure, "status #{response.status}, expected a redirect"
  end

  def assert_unprocessable(response)
    reject_server_error(response, "a rejected forgery token")
    return if response.status == 422

    raise HostAppGateFailure, "status #{response.status}, expected 422"
  end

  def new_product_link(doc)
    doc.at_css("a[href='#{HostAppGate::PRODUCTS_PATH}/new']")
  end

  def edit_link(doc)
    doc.css("a[href]").find { |link| link["href"].end_with?("/edit") }
  end

  def archive_control(doc)
    doc.css("[formaction]").find { |node| node["formaction"].include?("bulk_actions/archive") }
  end

  def assert_text(response, text)
    raise HostAppGateFailure, "page is missing #{text.inspect}" unless page_text(response).include?(text)
  end

  def refute_text(response, text)
    raise HostAppGateFailure, "page still shows #{text.inspect}" if page_text(response).include?(text)
  end

  def page_text(response)
    Nokogiri::HTML(response.body).text
  end

  def document(response)
    Nokogiri::HTML(response.body)
  end

  def reject_server_error(response, expected)
    return if response.status < 500

    raise HostAppGateFailure, "status #{response.status} is a server error, not #{expected}"
  end
end
