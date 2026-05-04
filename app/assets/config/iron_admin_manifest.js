// Sprockets manifest for IronAdmin engine assets.
// Engine initializer adds this manifest to the host's precompile list,
// recursively pulling these assets into Sprockets' precompile set.

// Stimulus / importmap entry point + controllers.
//= link_tree ../../javascript/iron_admin .js

// Chart.js (vendored) — loaded by the dashboard layout via
// `javascript_include_tag "chart.min"`. Without this link, hosts on
// sprockets-rails 500 on `/admin` with
// `Asset 'chart.min.js' was not declared to be precompiled`.
//= link chart.min.js
