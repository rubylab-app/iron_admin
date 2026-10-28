# frozen_string_literal: true

module IronAdmin
  # Text of the action form pages.
  module ActionFormHelper
    # Names a member action's record by model, id and the label display_record_label picks.
    #
    # @param resource_class [Class] The resource class
    # @param record [Object] The record the action runs on
    # @return [String] Such as "Applies to Article #16 (Slow news)."
    def action_form_record_text(resource_class, record)
      names = { model: resource_class.model.model_name.human, id: record.id }
      label = ApplicationHelper::DISPLAY_METHODS.lazy.filter_map { |method| record.try(method).presence }.first
      return I18n.t("iron_admin.resources.action_form.record", **names) if label.nil?

      I18n.t("iron_admin.resources.action_form.record_with_label", label: label, **names)
    end
  end
end
