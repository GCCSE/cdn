# frozen_string_literal: true

class User < ApplicationRecord
  include PublicIdentifiable
  include PgSearch::Model
  set_public_id_prefix :usr

  def to_param
    public_id
  end

  pg_search_scope :search,
    against: [ :email, :name ],
    using: { tsearch: { prefix: true } }

  scope :admins, -> { where(is_admin: true) }

  validates :quota_policy, inclusion: { in: Quota::ADMIN_ASSIGNABLE.map(&:to_s) }, allow_nil: true

  has_many :uploads, dependent: :destroy
  has_many :api_keys, dependent: :destroy, class_name: "APIKey"

  def self.create_guest!
    create!(
      email: "user-#{SecureRandom.hex(6)}@gccse.tech",
      name: "GCCSE User #{SecureRandom.hex(3).upcase}",
      quota_policy: "verified"
    )
  end

  def total_files
    uploads.count
  end

  def total_storage_bytes
    uploads.joins(:blob).sum("active_storage_blobs.byte_size")
  end

  def total_storage_gb
    (total_storage_bytes / 1.gigabyte.to_f).round(2)
  end

  def total_storage_formatted
    ActiveSupport::NumberHelper.number_to_human_size(total_storage_bytes)
  end
end
