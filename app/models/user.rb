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

  validates :github_uid, uniqueness: true, allow_nil: true
  validates :quota_policy, inclusion: { in: Quota::ADMIN_ASSIGNABLE.map(&:to_s) }, allow_nil: true

  has_many :uploads, dependent: :destroy
  has_many :api_keys, dependent: :destroy, class_name: "APIKey"

  def self.find_or_create_from_github(auth)
    github_uid = auth&.uid
    raise "Missing GitHub user ID from authentication" if github_uid.blank?

    user = find_by(github_uid: github_uid)

    email = auth.info.email.presence || auth.extra&.raw_info&.email.presence
    nickname = auth.info.nickname.presence || "github-user"
    attrs = {
      github_uid: github_uid,
      email: email.presence || "#{nickname}@users.noreply.github.com",
      name: auth.info.name.presence || nickname,
      quota_policy: user&.quota_policy || "verified"
    }

    if user
      user.update!(attrs)
      user
    else
      create!(attrs)
    end
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
