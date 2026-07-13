import CpBulkSelectController from "iron_admin/controllers/cp_bulk_select_controller"
import CpChartController from "iron_admin/controllers/cp_chart_controller"
import CpNestedFormController from "iron_admin/controllers/cp_nested_form_controller"
import CpSidebarController from "iron_admin/controllers/cp_sidebar_controller"
import FilterOperatorController from "iron_admin/controllers/filter_operator_controller"

const application = window.Stimulus
application.register("cp-bulk-select", CpBulkSelectController)
application.register("cp-chart", CpChartController)
application.register("cp-nested-form", CpNestedFormController)
application.register("cp-sidebar", CpSidebarController)
application.register("filter-operator", FilterOperatorController)
