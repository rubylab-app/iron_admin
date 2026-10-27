require "rails_helper"

RSpec.describe IronAdmin::Configuration::Components do
  subject(:components) { described_class.new }

  let(:navbar_component) do
    Class.new(ViewComponent::Base) do
      attr_reader :current_user

      def initialize(current_user: nil)
        super()
        @current_user = current_user
      end
    end
  end

  describe "initialization" do
    it "initializes fields as empty hash" do
      expect(components.fields).to eq({})
    end

    it "leaves every slot without an override" do
      expect(described_class::SLOTS.keys.map { |slot| components.public_send(slot) }).to all(be_nil)
    end
  end

  describe "attr_accessors" do
    it "allows setting table" do
      components.table = "CustomTableComponent"

      expect(components.table).to eq("CustomTableComponent")
    end

    it "allows setting form" do
      components.form = "CustomFormComponent"

      expect(components.form).to eq("CustomFormComponent")
    end

    it "allows setting filter_bar" do
      components.filter_bar = "CustomFilterComponent"

      expect(components.filter_bar).to eq("CustomFilterComponent")
    end

    it "allows setting search" do
      components.search = "CustomSearchComponent"

      expect(components.search).to eq("CustomSearchComponent")
    end

    it "allows setting navbar" do
      components.navbar = "CustomNavbarComponent"

      expect(components.navbar).to eq("CustomNavbarComponent")
    end

    it "allows setting sidebar" do
      components.sidebar = "CustomSidebarComponent"

      expect(components.sidebar).to eq("CustomSidebarComponent")
    end

    it "allows setting shell" do
      components.shell = "CustomShellComponent"

      expect(components.shell).to eq("CustomShellComponent")
    end

    it "allows setting flash" do
      components.flash = "CustomFlashComponent"

      expect(components.flash).to eq("CustomFlashComponent")
    end
  end

  describe "flash slot" do
    it "passes the request's flash and the current user" do
      expect(described_class::SLOTS[:flash]).to eq(%i[flash current_user])
    end

    it "renders IronAdmin::Layout::FlashComponent without an override" do
      expect(components.resolve(:flash)).to eq(IronAdmin::Layout::FlashComponent)
    end

    it "is global only" do
      expect(described_class::RESOURCE_SLOTS).not_to include(:flash)
    end

    context "with a component that requires a keyword the slot does not pass" do
      let(:toast_component) do
        component = Class.new(ViewComponent::Base) do
          def initialize(messages:)
            super()
            @messages = messages
          end
        end
        stub_const("ToastComponent", component)
      end

      it "raises ArgumentError naming the missing keyword" do
        expect { components.flash = toast_component }
          .to raise_error(ArgumentError, /ToastComponent cannot render :flash: its initialize requires :messages/)
      end
    end
  end

  describe "slot writers" do
    context "with a ViewComponent class" do
      it "stores the class" do
        components.navbar = navbar_component

        expect(components.navbar).to eq(navbar_component)
      end
    end

    context "with nil" do
      it "removes the override" do
        components.navbar = navbar_component
        components.navbar = nil

        expect(components.navbar).to be_nil
      end
    end

    context "with a class that is not a ViewComponent" do
      it "raises an ArgumentError naming the slot" do
        expect { components.navbar = Class.new }
          .to raise_error(ArgumentError, /:navbar must be a ViewComponent::Base subclass/)
      end
    end

    context "with ViewComponent::Base itself" do
      it "raises an ArgumentError" do
        expect { components.table = ViewComponent::Base }
          .to raise_error(ArgumentError, /must be a ViewComponent::Base subclass/)
      end
    end

    context "with a value that is neither a class nor a class name" do
      it "raises an ArgumentError" do
        expect { components.sidebar = 42 }
          .to raise_error(ArgumentError, /ViewComponent::Base subclass or its class name/)
      end
    end

    context "with a component that requires a keyword the slot does not pass" do
      let(:account_navbar) do
        Class.new(ViewComponent::Base) do
          def initialize(account:, current_user: nil)
            super()
            @account = account
            @current_user = current_user
          end
        end
      end

      it "raises an ArgumentError listing what the slot passes" do
        expect { components.navbar = account_navbar }
          .to raise_error(ArgumentError, /requires :account.*passes :current_user, :title/)
      end
    end

    context "with a component that requires a positional argument" do
      let(:positional_table) do
        Class.new(ViewComponent::Base) do
          def initialize(records)
            super()
            @records = records
          end
        end
      end

      it "raises an ArgumentError" do
        expect { components.table = positional_table }
          .to raise_error(ArgumentError, /positional argument/)
      end
    end
  end

  describe "#resolve" do
    context "with a layout slot and no override" do
      it "returns the built-in component" do
        expect(components.resolve(:navbar)).to eq(IronAdmin::Layout::NavbarComponent)
      end
    end

    context "with a page slot and no override" do
      it "returns nil so the built-in markup renders" do
        expect(components.resolve(:table)).to be_nil
      end
    end

    context "with a global override" do
      it "returns the override" do
        components.navbar = navbar_component

        expect(components.resolve(:navbar)).to eq(navbar_component)
      end
    end

    context "with a class name override" do
      it "returns the named class" do
        stub_const("ComponentsSpecNavbar", navbar_component)
        components.navbar = "ComponentsSpecNavbar"

        expect(components.resolve(:navbar)).to eq(navbar_component)
      end
    end

    context "with a class name that is not a ViewComponent" do
      it "raises an ArgumentError" do
        components.navbar = "String"

        expect { components.resolve(:navbar) }.to raise_error(ArgumentError, /must be a ViewComponent::Base subclass/)
      end
    end

    context "with a class name that is not defined" do
      it "raises a NameError" do
        components.navbar = "ComponentsSpecMissingNavbar"

        expect { components.resolve(:navbar) }.to raise_error(NameError, /ComponentsSpecMissingNavbar/)
      end
    end

    context "with an unknown slot" do
      it "raises an ArgumentError" do
        expect { components.resolve(:footer) }.to raise_error(ArgumentError, /Unknown component slot :footer/)
      end
    end

    context "with a resource that overrides the slot" do
      let(:global_table) { Class.new(ViewComponent::Base) }
      let(:resource_table) { Class.new(ViewComponent::Base) }
      let(:resource_class) do
        table = resource_table
        Class.new(IronAdmin::Resource) { component :table, table }
      end

      it "prefers the resource's override over the global one" do
        components.table = global_table

        expect(components.resolve(:table, resource_class: resource_class)).to eq(resource_table)
      end
    end

    context "with a resource that does not override the slot" do
      let(:global_table) { Class.new(ViewComponent::Base) }

      it "returns the global override" do
        components.table = global_table

        expect(components.resolve(:table, resource_class: Class.new(IronAdmin::Resource))).to eq(global_table)
      end
    end
  end

  describe "#build" do
    context "with a component that declares some of the slot's keywords" do
      it "passes only the keywords the component accepts" do
        components.navbar = navbar_component
        user = Object.new

        expect(components.build(:navbar, current_user: user, title: "Admin").current_user).to eq(user)
      end
    end

    context "with a component that accepts any keywords" do
      let(:splat_navbar) do
        Class.new(ViewComponent::Base) do
          attr_reader :options

          def initialize(**options)
            super()
            @options = options
          end
        end
      end

      it "passes every keyword" do
        components.navbar = splat_navbar

        expect(components.build(:navbar, current_user: nil, title: "Admin").options)
          .to eq(current_user: nil, title: "Admin")
      end
    end

    context "with a page slot and no override" do
      it "returns nil" do
        expect(components.build(:table, records: [])).to be_nil
      end
    end
  end

  describe "#fields" do
    it "is read-only" do
      expect(components).not_to respond_to(:fields=)
    end

    it "returns a hash" do
      expect(components.fields).to be_a(Hash)
    end
  end

  describe "#field_types" do
    it "returns the types that have a component" do
      components.fields[:color_picker] = "ColorPickerComponent"
      components.fields["rich_text"] = "RichTextComponent"

      expect(components.field_types).to contain_exactly(:color_picker, :rich_text)
    end

    it "skips types whose component is nil" do
      components.fields[:color_picker] = nil

      expect(components.field_types).to be_empty
    end
  end

  describe "#build_field" do
    let(:field) { IronAdmin::Field.new(:accent_color, type: :color_picker) }
    let(:field_component) do
      Class.new(ViewComponent::Base) do
        attr_reader :form, :field, :record

        def initialize(form:, field:, record:)
          super()
          @form = form
          @field = field
          @record = record
        end
      end
    end

    context "with a component for the field's type" do
      it "builds it with the form, field and record" do
        components.fields[:color_picker] = field_component
        form = Object.new
        record = Object.new

        built = components.build_field(field, form: form, record: record)

        expect([built.form, built.field, built.record]).to eq([form, field, record])
      end
    end

    context "without a component for the field's type" do
      it "returns nil" do
        expect(components.build_field(field, form: Object.new, record: Object.new)).to be_nil
      end
    end

    context "with a class that is not a ViewComponent" do
      it "raises an ArgumentError naming the field type" do
        components.fields[:color_picker] = Class.new

        expect { components.build_field(field, form: Object.new, record: Object.new) }
          .to raise_error(ArgumentError, /fields\[:color_picker\] must be a ViewComponent::Base subclass/)
      end
    end
  end
end
