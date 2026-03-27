# frozen_string_literal: true

class QuotaService
  WARNING_THRESHOLD_PERCENTAGE = 80

  def initialize(user)
    @user = user
  end

  def current_policy
    if @user.quota_policy.present?
      Quota.policy(@user.quota_policy.to_sym)
    else
      Quota.policy(:verified)
    end
  rescue KeyError
    Quota.policy(:verified)
  end

  # Returns hash with storage info, policy, and flags
  def current_usage
    policy = current_policy
    used = @user.total_storage_bytes
    max = policy.max_total_storage
    percentage = percentage_used

    {
      storage_used: used,
      storage_limit: max,
      policy: policy.slug.to_s,
      percentage_used: percentage,
      at_warning: at_warning?,
      over_quota: over_quota?
    }
  end

  # Validates if upload is allowed based on file size and total storage
  def can_upload?(file_size)
    policy = current_policy

    # Check file size against per-file limit
    return false if file_size > policy.max_file_size

    # Check total storage after upload
    total_after = @user.total_storage_bytes + file_size
    return false if total_after > policy.max_total_storage

    true
  end

  # Boolean if storage exceeded
  def over_quota?
    @user.total_storage_bytes >= current_policy.max_total_storage
  end

  # Boolean if >= 80% used
  def at_warning?
    percentage_used >= WARNING_THRESHOLD_PERCENTAGE
  end

  # Calculate usage percentage
  def percentage_used
    max = current_policy.max_total_storage
    return 0 if max.zero?

    ((@user.total_storage_bytes.to_f / max) * 100).round(2)
  end

  def check_and_upgrade_verification!
    true
  end
end
