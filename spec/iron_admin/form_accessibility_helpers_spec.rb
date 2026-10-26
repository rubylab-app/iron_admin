# frozen_string_literal: true

require "rails_helper"

RSpec.describe FormAccessibilityHelpers do
  describe "#form_accessibility_problems" do
    subject(:problems) { form_accessibility_problems(html) }

    context "when a label[for] names an input" do
      let(:html) { '<label for="record_name">Name</label><input id="record_name" type="text">' }

      it { is_expected.to be_empty }
    end

    context "when a label wraps its control" do
      let(:html) { '<label><input type="checkbox" name="ids[]"> Read</label>' }

      it { is_expected.to be_empty }
    end

    context "when a control has an aria-label" do
      let(:html) { '<select name="op" aria-label="Title operator"><option>Contains</option></select>' }

      it { is_expected.to be_empty }
    end

    context "when a control has an aria-labelledby" do
      let(:html) { '<span id="tags_label">Tags</span><input type="text" aria-labelledby="tags_label">' }

      it { is_expected.to be_empty }
    end

    context "when the controls are hidden inputs or buttons" do
      let(:html) { '<input type="hidden" name="a"><input type="submit" value="Save">' }

      it { is_expected.to be_empty }
    end

    context "when a label[for] has no matching id" do
      let(:html) { '<label for="record_user">User</label><select id="record_user_id"><option>x</option></select>' }

      it { is_expected.to include(a_string_including('label "User" for="record_user": no element has that id')) }
    end

    context "when a label[for] points at a hidden input" do
      let(:html) { '<label for="tags">Tags</label><input type="hidden" id="tags">' }

      it { is_expected.to include(a_string_including("<input> is not a labelable control")) }
    end

    context "when two elements share the label's id" do
      let(:html) { '<label for="q">Search</label><input id="q" type="text"><input id="q" type="text">' }

      it { is_expected.to include(a_string_including("2 elements have that id")) }
    end

    context "when a label has no for and wraps no control" do
      let(:html) { "<label>Body</label><textarea></textarea>" }

      it { is_expected.to include('label "Body" has no for and wraps no control') }
    end

    context "when a select is named only by its options" do
      let(:html) { '<select name="filters[status]"><option value="">All</option></select>' }

      it { is_expected.to include('select[name="filters[status]"] has no accessible name') }
    end

    context "when an input is named only by its placeholder" do
      let(:html) { '<input type="text" name="q" placeholder="Search...">' }

      it { is_expected.to include(a_string_including('input[type="text"][name="q"]')) }
    end

    context "when the wrapping label points at another control" do
      let(:html) { '<label for="other">Remove <input type="checkbox" id="purge"></label><input id="other">' }

      it { is_expected.to include(a_string_including('[id="purge"] has no accessible name')) }
    end

    context "when aria-labelledby points at a missing id" do
      let(:html) { '<input type="text" aria-labelledby="missing">' }

      it { is_expected.to include(a_string_including("has no accessible name")) }
    end
  end
end
