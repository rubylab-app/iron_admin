require_relative "html_form"

# What an admin can do with Product: list, search, filter, and write.
class HostAppGateAdminChecks
  include HostAppGateAssertions

  def initialize(report)
    @report = report
    @admin = nil
  end

  def run
    HostAppGateBrowser.with_forgery(enabled: false) do
      @admin = HostAppGateBrowser.sign_in("admin@example.com")
      index
      index_controls
      search
      status_filter
      category_select
      show_controls
      create_product
      update_product
      delete_product
      bulk_archive
    end
  end

  private

  def index
    @report.check("admin_index") do
      response = @admin.get(HostAppGate::PRODUCTS_PATH)
      assert_ok(response)
      ["Blue Mug", "Red Mug", "Green Teapot", "Steel Kettle", "Paper Filters", "White Cup"].each do |name|
        assert_text(response, name)
      end
      headers = document(response).css("th").map { |cell| cell.text.gsub(/\s+/, " ").strip }
      %w[Name Status Category Price].each do |header|
        raise HostAppGateFailure, "index is missing the #{header} column" unless headers.include?(header)
      end
    end
  end

  def index_controls
    @report.check("admin_index_controls") do
      response = @admin.get(HostAppGate::PRODUCTS_PATH)
      assert_ok(response)
      doc = document(response)
      raise HostAppGateFailure, "admin index has no New link" unless new_product_link(doc)
      raise HostAppGateFailure, "admin index has no bulk archive" unless archive_control(doc)
    end
  end

  def search
    @report.check("admin_search") do
      page = @admin.get(HostAppGate::PRODUCTS_PATH)
      assert_ok(page)
      form = HostAppGateHtmlForm.index_search(document(page))
      assert_search_form(form)
      response = @admin.get(form.path, form.payload(form.query_name => "Teapot"))
      assert_ok(response)
      assert_text(response, "Green Teapot")
      refute_text(response, "Blue Mug")
    end
  end

  def status_filter
    @report.check("admin_status_filter") do
      response = @admin.get(HostAppGate::PRODUCTS_PATH, { filters: { status: "active" } })
      assert_ok(response)
      raise HostAppGateFailure, "no status filter" unless document(response).at_css("select[name='filters[status]']")

      assert_text(response, "Blue Mug")
      assert_text(response, "Green Teapot")
      refute_text(response, "Red Mug")
    end
  end

  def category_select
    @report.check("admin_category_select") do
      response = @admin.get("#{HostAppGate::PRODUCTS_PATH}/new")
      assert_ok(response)
      select = document(response).at_css("select[name='record[category]']")
      raise HostAppGateFailure, "new form has no category select" unless select

      values = select.css("option").map { |option| option["value"].to_s }.reject(&:empty?)
      raise HostAppGateFailure, "category options are #{values.inspect}" unless values.sort == %w[garden kitchen office]
    end
  end

  def show_controls
    @report.check("admin_show_controls") do
      response = @admin.get(product_path("Green Teapot"))
      assert_ok(response)
      raise HostAppGateFailure, "admin show has no Edit link" unless edit_link(document(response))
    end
  end

  def create_product
    @report.check("admin_create") do
      page = @admin.get("#{HostAppGate::PRODUCTS_PATH}/new")
      assert_ok(page)
      form = HostAppGateHtmlForm.record_form(document(page))
      assert_create_form(form)
      before = Product.count
      response = @admin.request(form.verb, form.path, form.payload(new_fields))
      assert_redirect(response)
      assert_created(before)
    end
  end

  def update_product
    @report.check("admin_update") do
      product = Product.find_by!(name: "Paper Filters")
      before = preserved_attributes(product)
      form = edit_form(product)
      response = @admin.request(form.verb, form.path, form.payload("record[name]" => "Coffee Filters"))
      assert_redirect(response)
      assert_renamed(product, before)
    end
  end

  def delete_product
    @report.check("admin_delete") do
      product = Product.find_by!(name: "Green Teapot")
      form = delete_form(product)
      response = @admin.request(form.verb, form.path, form.payload)
      assert_redirect(response)
      raise HostAppGateFailure, "Green Teapot still exists" if Product.exists?(product.id)
    end
  end

  def bulk_archive
    @report.check("admin_bulk_archive") do
      target = Product.find_by!(name: "Red Mug")
      bystander = Product.find_by!(name: "Blue Mug")
      before = bystander.attributes
      page = @admin.get(HostAppGate::PRODUCTS_PATH)
      assert_ok(page)
      path, payload = HostAppGateHtmlForm.bulk_archive(document(page), [target.id])
      response = @admin.post(path, payload)
      assert_redirect(response)
      assert_archived(target, bystander, before)
    end
  end

  def new_fields
    {
      "record[name]" => "Desk Lamp",
      "record[status]" => "active",
      "record[category]" => "office",
      "record[price]" => "20",
    }
  end

  def assert_create_form(form)
    raise HostAppGateFailure, "new form method is #{form.verb}" unless form.verb == :post
    raise HostAppGateFailure, "new form posts to #{form.path}" unless form.path == HostAppGate::PRODUCTS_PATH
    raise HostAppGateFailure, "new form sends _method #{form.method_override}" if form.method_override
  end

  def assert_update_form(form, product)
    expected = "#{HostAppGate::PRODUCTS_PATH}/#{product.id}"
    raise HostAppGateFailure, "edit form method is #{form.verb}" unless form.verb == :post
    raise HostAppGateFailure, "edit form posts to #{form.path}" unless form.path == expected
    raise HostAppGateFailure, "edit form _method is #{form.method_override.inspect}" unless form.method_override == "patch"
  end

  def assert_created(before)
    created = Product.find_by(name: "Desk Lamp")
    raise HostAppGateFailure, "Desk Lamp was not created" unless created&.category == "office" && created.active?
    raise HostAppGateFailure, "product count is #{Product.count}, expected #{before + 1}" unless Product.count == before + 1
  end

  def product_path(name)
    "#{HostAppGate::PRODUCTS_PATH}/#{Product.find_by!(name: name).id}"
  end

  def assert_search_form(form)
    raise HostAppGateFailure, "search form posts to #{form.path}" unless form.path == HostAppGate::PRODUCTS_PATH
    raise HostAppGateFailure, "search form method is #{form.verb}" unless form.verb == :get
  end

  def edit_form(product)
    page = @admin.get("#{HostAppGate::PRODUCTS_PATH}/#{product.id}/edit")
    assert_ok(page)
    form = HostAppGateHtmlForm.record_form(document(page))
    assert_update_form(form, product)
    form
  end

  def preserved_attributes(product)
    { status: product.status, category: product.category, price: product.price, archived_at: product.archived_at }
  end

  def assert_renamed(product, before)
    product.reload
    raise HostAppGateFailure, "name is #{product.name}" unless product.name == "Coffee Filters"

    before.each do |name, value|
      current = product.public_send(name)
      next if current == value

      raise HostAppGateFailure, "#{name} changed from #{value.inspect} to #{current.inspect}"
    end
  end

  def delete_form(product)
    page = @admin.get("#{HostAppGate::PRODUCTS_PATH}/#{product.id}")
    assert_ok(page)
    form = HostAppGateHtmlForm.delete_form(document(page))
    expected = "#{HostAppGate::PRODUCTS_PATH}/#{product.id}"
    raise HostAppGateFailure, "delete form posts to #{form.path}" unless form.path == expected
    raise HostAppGateFailure, "delete form _method is #{form.method_override.inspect}" unless form.method_override == "delete"

    form
  end

  def assert_archived(product, bystander, before)
    product.reload
    raise HostAppGateFailure, "#{product.name} was not archived" unless product.archived? && product.archived_at.present?
    raise HostAppGateFailure, "#{bystander.name} changed" unless bystander.reload.attributes == before
  end
end
