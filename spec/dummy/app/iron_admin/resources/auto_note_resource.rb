# Test fixture: a resource on Note that intentionally omits the
# `types: [...]` option on its polymorphic belongs_to, so the form
# rendering exercises FieldInferrer's auto-inference path (#79).
module IronAdmin
  module Resources
    class AutoNoteResource < IronAdmin::Resource
      self.model_class_override = ::Note

      index_fields :id, :title, :notable, :created_at
      form_fields :title, :body, :notable
    end
  end
end
