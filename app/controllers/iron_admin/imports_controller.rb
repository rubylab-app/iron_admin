# frozen_string_literal: true

require "base64"
require "ostruct"

module IronAdmin
  class ImportsController < ApplicationController
    before_action :set_resource_class
    before_action :ensure_import_enabled
    before_action :ensure_create_allowed

    def new
      @formats = @resource_class.import_formats
      @fields = @resource_class.importable_fields(iron_admin_current_user)
    end

    def preview
      return redirect_missing_file unless import_content

      @preview = importer.preview
      @resource_name = @resource_class.resource_name
      @import_format = import_format
      # The preview page's import form posts this copy back to #create, so the
      # import runs on exactly the previewed bytes without a second upload.
      # Base64 keeps line endings and encoding intact through the form.
      @import_data = Base64.strict_encode64(import_content)
      render :preview, formats: :html
    rescue ArgumentError => e
      redirect_to resource_import_path(@resource_class.resource_name), alert: e.message
    rescue StandardError => e
      log_iron_admin_error(e)
      redirect_to resource_import_path(@resource_class.resource_name), alert: I18n.t("iron_admin.errors.unexpected")
    end

    def create
      return redirect_missing_file unless import_content

      result = importer.execute!
      redirect_to resources_path(@resource_class.resource_name),
                  notice: I18n.t(
                    "iron_admin.imports.create.success",
                    created: result.created_count,
                    updated: result.updated_count,
                    failed: result.failed_count
                  )
    rescue ArgumentError => e
      redirect_to resource_import_path(@resource_class.resource_name), alert: e.message
    rescue StandardError => e
      log_iron_admin_error(e)
      redirect_to resource_import_path(@resource_class.resource_name), alert: I18n.t("iron_admin.errors.unexpected")
    end

    private

    def set_resource_class
      @resource_class = ResourceRegistry.find(params[:resource_name])
      render_not_found unless @resource_class
    end

    def ensure_import_enabled
      render_not_found unless @resource_class&.import_enabled?
    end

    def ensure_create_allowed
      return if performed? || @resource_class.nil?

      render_forbidden unless @resource_class.crud_allowed?(:create, iron_admin_current_user)
    end

    # The bytes to import: a fresh upload, or the copy of a previewed upload
    # carried by the preview page's import form.
    def import_content
      return @import_content if defined?(@import_content)

      @import_content = uploaded_file&.read || carried_import_data
    end

    # Only a real multipart upload counts. A plain string would otherwise reach
    # the parsers, which read it as a path on the server.
    def uploaded_file
      file = params[:file]
      file if file.respond_to?(:read) && file.respond_to?(:original_filename)
    end

    def carried_import_data
      data = params[:import_data]
      Base64.strict_decode64(data) if data.is_a?(String) && data.present?
    rescue ArgumentError
      nil
    end

    def importer
      Import::Importer.new(
        @resource_class,
        file: StringIO.new(import_content),
        format: import_format,
        context: import_context
      )
    end

    def import_format
      params[:import_format].presence || params[:format].presence || uploaded_file_extension
    end

    def uploaded_file_extension
      filename = uploaded_file&.original_filename
      return unless filename

      filename.split(".").last
    end

    def import_context
      OpenStruct.new(current_user: iron_admin_current_user, controller: self)
    end

    def redirect_missing_file
      redirect_to resource_import_path(@resource_class.resource_name), alert: I18n.t("iron_admin.imports.errors.missing_file")
    end
  end
end
