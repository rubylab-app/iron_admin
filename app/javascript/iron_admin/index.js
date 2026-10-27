import CpAlertController from "iron_admin/controllers/cp_alert_controller"
import CpBulkSelectController from "iron_admin/controllers/cp_bulk_select_controller"
import CpChartController from "iron_admin/controllers/cp_chart_controller"
import CpColorFieldController from "iron_admin/controllers/cp_color_field_controller"
import CpDisclosureController from "iron_admin/controllers/cp_disclosure_controller"
import CpModalController from "iron_admin/controllers/cp_modal_controller"
import CpNestedFormController from "iron_admin/controllers/cp_nested_form_controller"
import CpSidebarController from "iron_admin/controllers/cp_sidebar_controller"
import FilterOperatorController from "iron_admin/controllers/filter_operator_controller"

const application = window.Stimulus
application.register("cp-alert", CpAlertController)
application.register("cp-bulk-select", CpBulkSelectController)
application.register("cp-chart", CpChartController)
application.register("cp-color-field", CpColorFieldController)
application.register("cp-disclosure", CpDisclosureController)
application.register("cp-modal", CpModalController)
application.register("cp-nested-form", CpNestedFormController)
application.register("cp-sidebar", CpSidebarController)
application.register("filter-operator", FilterOperatorController)
