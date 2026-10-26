require "rails_helper"
require_relative "../../../../app/components/iron_admin/form/belongs_to_autocomplete_component"

RSpec.describe IronAdmin::Form::BelongsToAutocompleteComponent, type: :component do
  describe "#initialize" do
    it "stores name" do
      component = described_class.new(name: :user_id, resource_name: "users")
      expect(component.name).to eq(:user_id)
    end

    it "stores resource_name" do
      component = described_class.new(name: :user_id, resource_name: "users")
      expect(component.resource_name).to eq("users")
    end

    it "defaults selected_id to nil" do
      component = described_class.new(name: :user_id, resource_name: "users")
      expect(component.selected_id).to be_nil
    end

    it "defaults selected_label to nil" do
      component = described_class.new(name: :user_id, resource_name: "users")
      expect(component.selected_label).to be_nil
    end

    it "defaults placeholder to Search..." do
      component = described_class.new(name: :user_id, resource_name: "users")
      expect(component.placeholder).to eq("Search...")
    end

    it "defaults disabled to false" do
      component = described_class.new(name: :user_id, resource_name: "users")
      expect(component.disabled).to be false
    end

    it "defaults has_error to false" do
      component = described_class.new(name: :user_id, resource_name: "users")
      expect(component.has_error).to be false
    end

    it "accepts all options" do
      component = described_class.new(
        name: :user_id,
        resource_name: "users",
        selected_id: 1,
        selected_label: "Test User",
        placeholder: "Find user...",
        disabled: true,
        has_error: true
      )
      expect(component.selected_id).to eq(1)
      expect(component.selected_label).to eq("Test User")
      expect(component.placeholder).to eq("Find user...")
      expect(component.disabled).to be true
      expect(component.has_error).to be true
    end
  end

  describe "#effectively_disabled?" do
    it "returns true when disabled" do
      component = described_class.new(name: :user_id, resource_name: "users", disabled: true)
      expect(component.effectively_disabled?).to be true
    end

    it "returns false when not disabled and no field" do
      component = described_class.new(name: :user_id, resource_name: "users", disabled: false)
      expect(component.effectively_disabled?).to be false
    end

    it "returns true when field is readonly" do
      field = instance_double(IronAdmin::Field, readonly?: true)
      component = described_class.new(name: :user_id, resource_name: "users", field: field)
      expect(component.effectively_disabled?).to be true
    end

    it "returns false when field is not readonly" do
      field = instance_double(IronAdmin::Field, readonly?: false)
      component = described_class.new(name: :user_id, resource_name: "users", field: field)
      expect(component.effectively_disabled?).to be false
    end
  end

  describe "#input_classes" do
    it "includes w-full" do
      component = described_class.new(name: :user_id, resource_name: "users")
      expect(component.input_classes).to include("w-full")
    end

    it "includes border" do
      component = described_class.new(name: :user_id, resource_name: "users")
      expect(component.input_classes).to include("border")
    end

    it "includes error classes when has_error" do
      component = described_class.new(name: :user_id, resource_name: "users", has_error: true)
      expect(component.input_classes).to include("border-red-400")
    end

    it "includes disabled classes when disabled" do
      component = described_class.new(name: :user_id, resource_name: "users", disabled: true)
      expect(component.input_classes).to include("cursor-not-allowed")
    end
  end

  describe "#dropdown_classes" do
    it "includes absolute positioning" do
      component = described_class.new(name: :user_id, resource_name: "users")
      expect(component.dropdown_classes).to include("absolute")
    end

    it "includes z-index" do
      component = described_class.new(name: :user_id, resource_name: "users")
      expect(component.dropdown_classes).to include("z-50")
    end

    it "includes shadow" do
      component = described_class.new(name: :user_id, resource_name: "users")
      expect(component.dropdown_classes).to include("shadow-lg")
    end
  end

  describe "#component_id" do
    it "returns a unique id" do
      component = described_class.new(name: :user_id, resource_name: "users")
      expect(component.component_id).to match(/^autocomplete-[a-f0-9]+$/)
    end

    it "returns the same id on multiple calls" do
      component = described_class.new(name: :user_id, resource_name: "users")
      id1 = component.component_id
      id2 = component.component_id
      expect(id1).to eq(id2)
    end
  end

  describe "rendering" do
    it "renders hidden input with name" do
      result = render_inline(described_class.new(name: :user_id, resource_name: "users"))
      expect(result.css("input[type='hidden'][name='user_id']")).to be_present
    end

    it "renders text input with placeholder" do
      result = render_inline(described_class.new(name: :user_id, resource_name: "users", placeholder: "Find..."))
      expect(result.css("input[type='text'][placeholder='Find...']")).to be_present
    end

    it "renders selected value in inputs" do
      result = render_inline(described_class.new(
                               name: :user_id,
                               resource_name: "users",
                               selected_id: 5,
                               selected_label: "John Doe"
                             ))
      expect(result.css("input[type='hidden'][value='5']")).to be_present
      expect(result.css("input[type='text'][value='John Doe']")).to be_present
    end

    it "renders dropdown container" do
      result = render_inline(described_class.new(name: :user_id, resource_name: "users"))
      expect(result.css(".hidden.absolute")).to be_present
    end

    it "renders with autocomplete url data attribute" do
      result = render_inline(described_class.new(name: :user_id, resource_name: "users"))
      # The data attribute is kebab-cased in HTML
      expect(result.css("[data-autocomplete-url]")).to be_present
      expect(result.at_css("[data-autocomplete-url]")["data-autocomplete-url"]).to end_with("/autocomplete/users")
    end

    context "with an input_id" do
      subject(:text_input) { result.at_css("input[type='text']") }

      let(:result) { render_inline(described_class.new(name: "record[user_id]", input_id: "record_user_id", resource_name: "users")) }

      it "gives the text input that id, so the field label names it" do
        expect(text_input["id"]).to eq("record_user_id")
      end

      it "keeps the generated id on the hidden input" do
        expect(result.at_css("input[type='hidden']")["id"]).to match(/\Aautocomplete-\h+-hidden\z/)
      end
    end

    it "defaults the text input id to the component id" do
      component = described_class.new(name: :user_id, resource_name: "users")
      result = render_inline(component)
      expect(result.at_css("input[type='text']")["id"]).to eq("#{component.component_id}-input")
    end

    describe "combobox semantics" do
      subject(:text_input) { result.at_css("input[type='text']") }

      let(:result) { render_inline(described_class.new(name: "record[user_id]", input_id: "record_user_id", resource_name: "users")) }
      let(:listbox) { result.at_css("[role=listbox]") }

      it "renders the text input as a combobox" do
        expect(text_input["role"]).to eq("combobox")
      end

      it "announces list autocompletion" do
        expect(text_input["aria-autocomplete"]).to eq("list")
      end

      it "starts collapsed" do
        expect(text_input["aria-expanded"]).to eq("false")
      end

      it "controls the listbox" do
        expect(text_input["aria-controls"]).to eq(listbox["id"])
      end

      it "renders the results panel as a listbox" do
        expect(result.at_css("##{text_input["aria-controls"]}")["role"]).to eq("listbox")
      end

      it "starts with the results panel hidden" do
        expect(listbox["class"]).to include("hidden")
      end

      it "keeps aria-expanded in sync from its script" do
        expect(result.at_css("script").text).to include("setAttribute('aria-expanded', 'true')")
      end

      it "gives each result the option role from its script" do
        expect(result.at_css("script").text).to include("setAttribute('role', 'option')")
      end
    end

    it "disables input when disabled" do
      result = render_inline(described_class.new(name: :user_id, resource_name: "users", disabled: true))
      expect(result.css("input[type='text'][disabled]")).to be_present
    end
  end
end
