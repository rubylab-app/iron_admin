# frozen_string_literal: true

module IronAdmin
  module Import
    Row = Struct.new(:number, :attributes, :errors, keyword_init: true) unless const_defined?(:Row)
    Error = Struct.new(:row_number, :message, keyword_init: true) unless const_defined?(:Error)

    ImportPreview = Struct.new(:total_rows, :headers, :mapping, :rows, :errors, keyword_init: true)
  end
end
