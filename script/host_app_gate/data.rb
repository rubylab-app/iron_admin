# Product rows before and after a write. Denied writes must match exactly.
class HostAppGateData
  COLUMNS = %i[id name status category price archived_at].freeze

  def self.snapshot
    Product.order(:id).pluck(*COLUMNS)
  end

  def self.assert_unchanged(before)
    after = snapshot
    return if after == before

    raise HostAppGateFailure, "product rows changed"
  end

  def self.attributes_of(name)
    Product.find_by!(name: name).attributes
  end
end
