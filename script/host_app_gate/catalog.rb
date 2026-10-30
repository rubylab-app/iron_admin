# Every check the gate must report. finish compares the run against this list,
# so a check group that stops being called fails the gate.
class HostAppGateCatalog
  CHECKS = %w[
    eager_load
    package_path
    admin_routes
    engine_stylesheet
    packaged_importmap
    engine_translations
    anonymous_redirects
    anonymous_writes
    tampered_session
    revoked_session
    member_index
    member_show
    member_dashboard
    member_index_controls
    member_show_controls
    member_new
    member_create
    member_update
    member_delete
    member_bulk_archive
    admin_index
    admin_index_controls
    admin_search
    admin_status_filter
    admin_category_select
    admin_show_controls
    admin_create
    admin_update
    admin_delete
    admin_bulk_archive
    csrf_sign_in
    csrf_bulk_archive
    csrf_bulk_archive_without_token
    csrf_bulk_archive_tampered_token
    csrf_create_without_token
    csrf_create_tampered_token
    recipe_anonymous
    recipe_tampered_session
    recipe_revoked_session
    recipe_member
    recipe_admin
  ].freeze
end
