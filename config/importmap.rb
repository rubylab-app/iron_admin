# frozen_string_literal: true

# Trix editor and ActionText JS for rich_text field support.
# These pins are only effective when the host app has ActionText installed.
pin "trix"
pin "@rails/actiontext", to: "actiontext.esm.js"

# IronAdmin Stimulus controllers
pin "iron_admin", to: "iron_admin/index.js"
pin "iron_admin/controllers/cp_bulk_select_controller", to: "iron_admin/controllers/cp_bulk_select_controller.js"
pin "iron_admin/controllers/cp_chart_controller", to: "iron_admin/controllers/cp_chart_controller.js"
pin "iron_admin/controllers/cp_nested_form_controller", to: "iron_admin/controllers/cp_nested_form_controller.js"
pin "iron_admin/controllers/filter_operator_controller", to: "iron_admin/controllers/filter_operator_controller.js"
