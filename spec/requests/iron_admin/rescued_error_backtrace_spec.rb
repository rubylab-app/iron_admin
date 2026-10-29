# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Rescued admin errors", type: :request do
  def app_frame(line)
    "#{Rails.root}/app/iron_admin/resources/exploding_note.rb:#{line}:in `explode'"
  end

  def spec_frame
    "#{Rails.root.join("spec/requests/iron_admin/noise.rb")}:1:in `explode'"
  end

  def gem_frame
    gem_path = Gem.loaded_specs.fetch("actionpack").full_gem_path
    "#{gem_path}/lib/action_controller/metal.rb:1:in `dispatch'"
  end

  # Gem and spec frames sit before and between the app frames, so a cleaner
  # that left them in would show them inside the 10-line cut.
  def exploding_backtrace
    frames = [gem_frame]
    (1..12).each do |line|
      frames << spec_frame
      frames << app_frame(line)
      frames << gem_frame
    end
    frames
  end

  def expected_backtrace_log
    lines = (1..10).map { |line| "app/iron_admin/resources/exploding_note.rb:#{line}:in `explode'" }
    "[IronAdmin] StandardError: boom from host\n#{lines.join("\n")}"
  end

  def define_exploding_resource(backtrace)
    resource = Class.new(IronAdmin::Resource) do
      self.model_class_override = Note

      define_singleton_method(:name) { "IronAdmin::Resources::ExplodingNoteResource" }
      define_singleton_method(:resource_name) { "exploding_notes" }

      bulk_action :explode do |_notes|
        error = StandardError.new("boom from host")
        error.set_backtrace(backtrace)
        raise error
      end
    end
    IronAdmin::ResourceRegistry.register(resource)
  end

  it "logs the cleaned app frames, at most 10, and no gem frames" do
    define_exploding_resource(exploding_backtrace)
    note = Note.create!(title: "Boom")
    allow(Rails.logger).to receive(:error)

    post iron_admin.resource_bulk_action_path("exploding_notes", "explode"),
         params: { ids: [note.id] },
         as: :html

    expect(Rails.logger).to have_received(:error).with(expected_backtrace_log)
  end
end
