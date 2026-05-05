require "rails_helper"
require_relative "../../dummy/app/iron_admin/resources/auto_note_resource"

RSpec.describe "IronAdmin polymorphic auto-inferred form rendering", type: :request do
  before do
    IronAdmin.reset_configuration!
    IronAdmin::ResourceRegistry.reset!
    IronAdmin::ResourceRegistry.register(IronAdmin::Resources::AutoNoteResource)
  end

  describe "GET /:resource_name/new — without explicit `types:`" do
    it "renders <option> entries for every model that declares the inverse `has_many :as`" do
      get iron_admin.new_resource_path("notes"), as: :html

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('name="record[notable_type]"')
      expect(response.body).to include('value="User"')
      expect(response.body).to include('value="License"')
    end
  end
end
