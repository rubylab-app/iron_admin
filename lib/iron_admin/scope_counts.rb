# frozen_string_literal: true

module IronAdmin
  # Counts the records each scope tab of an index would list.
  #
  # The caller builds the relation for one scope (tenant scope, current
  # filters, that scope, current search; no selected scope and no page).
  # This object asks the adapter's {Adapters::Base#exact_count} for each
  # scope. A +nil+ count is unknown and is left out of the hash; zero is
  # kept. A count that raises is logged and left out too, so one scope
  # cannot take down the index. On PostgreSQL that rescue does not protect
  # the request: a failing count inside an open transaction, including a
  # transactional test, aborts the transaction, and a later query on the
  # page raises +PG::InFailedSqlTransaction+. With the feature off, no
  # relation is built and the adapter is not asked.
  class ScopeCounts
    # @param resource [IronAdmin::Resource]
    # @param adapter [IronAdmin::Adapters::Base]
    # @param relation_for [#call] builds the relation for a scope body
    def initialize(resource:, adapter:, relation_for:)
      @resource = resource
      @adapter = adapter
      @relation_for = relation_for
    end

    # @return [Hash{String => Integer}] counts keyed by scope name
    def to_h
      return {} unless @resource.scope_counts_enabled?

      @resource.all_scopes.each_with_object({}) do |definition, counts|
        next if definition[:count] == false

        value = count_scope(definition)
        counts[definition[:name].to_s] = value unless value.nil?
      end
    end

    # Tab label. A missing count draws the name alone; zero draws zero.
    #
    # @param scope [Hash] a scope definition, with +:name+
    # @param counts [Hash, nil] counts keyed by scope name, String or Symbol
    # @return [String]
    def self.label(scope, counts)
      lookup = (counts || {}).to_h.transform_keys(&:to_s)
      name = scope[:name].to_s.humanize
      count = lookup[scope[:name].to_s]
      count.nil? ? name : "#{name} (#{count})"
    end

    private

    # A scope whose body or count fails draws no number. The other tabs still count.
    # A body that returns nil or false is the ActiveRecord idiom for "add
    # nothing"; it is not a relation, and counting it would count every record.
    def count_scope(definition)
      relation = @relation_for.call(definition[:scope])
      return if relation.nil? || relation == false

      @adapter.exact_count(relation)
    rescue StandardError, NotImplementedError => e
      log_count_error(e)
      nil
    end

    # Same shape as ApplicationController#log_iron_admin_error.
    def log_count_error(error)
      message = "[IronAdmin] #{error.class}: #{error.message}"
      backtrace = Rails.backtrace_cleaner.clean(Array(error.backtrace)).first(10)
      message = "#{message}\n#{backtrace.join("\n")}" if backtrace.any?
      Rails.logger.error(message)
    end
  end
end
