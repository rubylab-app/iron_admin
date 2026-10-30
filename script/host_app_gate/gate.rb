# Shared constants for the host-app gate. The seed password must match
# script/host_app_gate/app_files/seeds.rb.
class HostAppGate
  PASSWORD = "password123456".freeze
  ROOT_PATH = "/admin".freeze
  PRODUCTS_PATH = "/admin/products".freeze
  SIGN_IN_PATH = "/session/new".freeze
  PACKAGE_ENV = "IRON_ADMIN_PACKAGE_ROOT".freeze
  RESULT_ENV = "HOST_APP_GATE_RESULT".freeze
  # One Tailwind class that is written only under that engine @source glob.
  # Tailwind emits it only when that glob is scanned. views/**/*.erb and
  # components/**/*.erb match no files in this gem, so they have no class.
  SOURCE_CLASSES = {
    "app/views/**/*.haml" => "field-sizing-content",
    "app/components/**/*.rb" => "sm:items-start",
    "app/components/**/*.haml" => "focus:not-sr-only",
    "app/helpers/**/*.rb" => "whitespace-pre-wrap",
    "app/javascript/**/*.js" => "opacity-50",
    "lib/iron_admin/**/*.rb" => "placeholder:text-zinc-500",
  }.freeze
end
