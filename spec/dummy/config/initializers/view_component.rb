# frozen_string_literal: true

# Host initializers may touch ViewComponent::Base (`include`, `config`), which
# fires the `:view_component` load hook before the autoloaders are ready. Doing
# it here stops the suite from booting if the engine resolves an autoloaded
# constant inside that hook again.
ViewComponent::Base
