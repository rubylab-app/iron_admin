ActiveRecord::Schema[7.1].define(version: 2024_01_01_000007) do
  create_table :users, force: :cascade do |t|
    t.string :name, null: false
    t.string :email, null: false
    t.string :role
    t.boolean :active, default: true
    t.timestamps

    t.index :email, unique: true
  end

  create_table :licenses, force: :cascade do |t|
    t.references :user, foreign_key: true
    t.string :license_key, null: false
    t.integer :status, default: 0
    t.string :license_type
    t.integer :max_devices
    t.datetime :expires_at
    t.timestamps

    t.index :license_key, unique: true
  end

  create_table :posts, force: :cascade do |t|
    t.string :title, null: false
    t.boolean :published, default: false
    t.string :category_tags
    t.text :body_markdown
    t.timestamps
  end

  create_table :profiles, force: :cascade do |t|
    t.references :user, foreign_key: true, null: false, index: { unique: true }
    t.text :bio
    t.string :website
    t.string :avatar_url
    t.string :color_hex
    t.decimal :hourly_rate, precision: 10, scale: 2
    t.timestamps
  end

  create_table :tags, force: :cascade do |t|
    t.string :name, null: false
    t.timestamps

    t.index :name, unique: true
  end

  create_table :posts_tags, id: false, force: :cascade do |t|
    t.references :post, foreign_key: true, null: false
    t.references :tag, foreign_key: true, null: false

    t.index [:post_id, :tag_id], unique: true
  end

  create_table :documents, force: :cascade do |t|
    t.string :title, null: false
    t.boolean :published, default: false
    t.string :password_hash
    t.timestamps
  end

  create_table :widgets, force: :cascade do |t|
    t.string :name, null: false
    t.string :status               # :radio
    t.string :permissions          # :boolean_group (CSV)
    t.string :image_url            # :external_image
    t.integer :completion          # :progress_bar
    t.text :config_json            # :key_value
    t.text :source_code            # :code
    t.string :secret_token         # :hidden
    t.timestamps
  end

  create_table :notes, force: :cascade do |t|
    t.string :title, null: false
    t.text :body
    t.string :notable_type
    t.integer :notable_id
    t.timestamps
  end

  # ActiveStorage tables
  create_table :active_storage_blobs, force: :cascade do |t|
    t.string :key, null: false
    t.string :filename, null: false
    t.string :content_type
    t.text :metadata
    t.string :service_name, null: false
    t.bigint :byte_size, null: false
    t.string :checksum
    t.datetime :created_at, null: false

    t.index [:key], unique: true
  end

  create_table :active_storage_attachments, force: :cascade do |t|
    t.string :name, null: false
    t.string :record_type, null: false
    t.bigint :record_id, null: false
    t.bigint :blob_id, null: false
    t.datetime :created_at, null: false

    t.index :blob_id
    t.index [:record_type, :record_id, :name, :blob_id], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table :active_storage_variant_records, force: :cascade do |t|
    t.bigint :blob_id, null: false
    t.string :variation_digest, null: false

    t.index [:blob_id, :variation_digest], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  # ActionText tables
  create_table :action_text_rich_texts, force: :cascade do |t|
    t.string :name, null: false
    t.text :body
    t.string :record_type, null: false
    t.bigint :record_id, null: false
    t.timestamps

    t.index [:record_type, :record_id, :name], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  # Composite-primary-key model — exercises Scopeable#find_record's PK handling.
  create_table :memberships, primary_key: [:account_id, :scope_id], force: :cascade do |t|
    t.integer :account_id, null: false
    t.integer :scope_id, null: false
    t.string :role
    t.timestamps
  end

  # Single-column custom primary key — exercises Scopeable#find_record's
  # non-composite path when `primary_key` is something other than `:id`.
  create_table :slugged_resources, primary_key: :slug, id: :string, force: :cascade do |t|
    t.string :title
    t.timestamps
  end

  create_table :iron_admin_audit_entries, force: :cascade do |t|
    t.string :user_identifier
    t.string :action, null: false
    t.string :resource, null: false
    t.integer :record_id
    t.text :record_changes
    t.string :ip_address
    t.timestamps

    t.index :resource
    t.index :action
    t.index :created_at
  end
end
